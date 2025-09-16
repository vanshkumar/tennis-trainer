import Foundation
import CoreML
import CoreVideo
import CoreGraphics
import QuartzCore

final class GridTrackNetDetector {
    // MARK: - Types
    struct RawOutputs {
        let conf: MLMultiArray
        let xOff: MLMultiArray
        let yOff: MLMultiArray
    }

    struct Sample {
        let tIndex: Int          // 0 (oldest) ... 4 (newest)
        let timestamp: CFTimeInterval
        let position: CGPoint?   // normalized Vision space; nil if below threshold
        let confidence: Float    // best grid confidence at t
    }

    // MARK: - Model
    private var model: GridTrackNet5?
    /// Target frame within the 5-frame window [0..4].
    /// 2 = middle frame: uses two past and two future frames (lower jitter, ~2-frame latency).
    /// 4 = freshest output (lower latency, less future context).
    private let targetFrameIndex: Int = 4

    // MARK: - Frame Buffer (oldest → newest)
    private var frames: [CVPixelBuffer] = []
    private var times: [CFTimeInterval] = []
    private let sync = DispatchQueue(label: "ml.gridtracknet.detector")
    private var inferCount: Int = 0
    // Mapping: height=27 (rows), width=48 (cols) — per thesis.
    
    

    init() {
        do {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = .all
            self.model = try GridTrackNet5(configuration: cfg)
            
        } catch {
            print("GridTrackNetDetector: failed to load model: \(error)")
            self.model = nil
        }
    }

    // MARK: - Buffer Management
    func clear() {
        sync.sync {
            frames.removeAll(keepingCapacity: true)
            times.removeAll(keepingCapacity: true)
        }
    }

    func pushFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CFTimeInterval = CACurrentMediaTime()) {
        sync.sync {
            let w = CVPixelBufferGetWidth(pixelBuffer)
            let h = CVPixelBufferGetHeight(pixelBuffer)
            let targetW = 768
            let targetH = 432
            let bufferToAppend: CVPixelBuffer
            if w == targetW && h == targetH {
                bufferToAppend = pixelBuffer
            } else {
                if let resized = PixelBufferScaler.shared.resizeAspectFill(pixelBuffer, width: targetW, height: targetH) {
                    bufferToAppend = resized
                } else {
                    print("GridTrackNetDetector: failed to resize frame (\(w)x\(h)) → (\(targetW)x\(targetH)); skipping.")
                    return
                }
            }

            if frames.count == 5 { frames.removeFirst() }
            frames.append(bufferToAppend)
            if times.count == 5 { times.removeFirst() }
            times.append(timestamp)
        }
    }

    var isReady: Bool {
        sync.sync { frames.count == 5 && model != nil }
    }

    // MARK: - Inference (raw tensors only)
    func predictIfReady() -> RawOutputs? {
        return sync.sync { () -> RawOutputs? in
            guard frames.count == 5, let model = model else { return nil }
            do {
                let provider = try MLDictionaryFeatureProvider(dictionary: [
                    "f1": MLFeatureValue(pixelBuffer: frames[0]),
                    "f2": MLFeatureValue(pixelBuffer: frames[1]),
                    "f3": MLFeatureValue(pixelBuffer: frames[2]),
                    "f4": MLFeatureValue(pixelBuffer: frames[3]),
                    "f5": MLFeatureValue(pixelBuffer: frames[4]),
                ])
                let out = try model.model.prediction(from: provider)
                inferCount += 1

                guard let conf = out.featureValue(for: "conf")?.multiArrayValue,
                      let xOff = out.featureValue(for: "x_off")?.multiArrayValue,
                      let yOff = out.featureValue(for: "y_off")?.multiArrayValue else {
                    print("GridTrackNetDetector: missing one or more outputs")
                    return nil
                }

                return RawOutputs(conf: conf, xOff: xOff, yOff: yOff)
            } catch {
                print("GridTrackNetDetector: prediction error: \(error)")
                return nil
            }
        }
    }

    // MARK: - Inference (mapped to normalized Vision space)
    // Returns a normalized point (x:[0,1], y:[0,1], origin bottom-left) for the middle frame (t=2).
    func detectNormalizedPositionIfReady() -> CGPoint? {
        guard let out = predictIfReady() else { return nil }

        let conf = out.conf
        let xOff = out.xOff
        let yOff = out.yOff

        // Support either [5, H, W] or [1, 5, H, W]. Prefer assigning dims by sizes.
        let shape = conf.shape.map { Int(truncating: $0) }
        let strides = conf.strides.map { Int(truncating: $0) }
        let xShape = xOff.shape.map { Int(truncating: $0) }
        let xStrides = xOff.strides.map { Int(truncating: $0) }
        let yShape = yOff.shape.map { Int(truncating: $0) }
        let yStrides = yOff.strides.map { Int(truncating: $0) }

        // Identify dims
        var bDim: Int? = nil
        var tDim: Int? = nil
        for i in 0..<shape.count {
            let s = shape[i]
            if s == 1 && shape.count == 4 && bDim == nil { bDim = i; continue }
            if s == 5 && tDim == nil { tDim = i; continue }
        }
        var rowDim: Int? = nil
        var colDim: Int? = nil
        for i in 0..<shape.count where i != bDim && i != tDim {
            let s = shape[i]
            if s == 27 { rowDim = i }
            else if s == 48 { colDim = i }
        }

        // Fallback heuristics if sizes not uniquely identified
        if rowDim == nil || colDim == nil {
            let candidates = (0..<shape.count).filter { $0 != bDim && $0 != tDim }
            if candidates.count == 2 {
                let a = candidates[0], b = candidates[1]
                if shape[a] <= shape[b] { rowDim = a; colDim = b }
                else { rowDim = b; colDim = a }
            }
        }

        guard let tDim = tDim, var rowDim = rowDim, var colDim = colDim else {
            print("GridTrackNetDetector: unexpected conf shape: \(shape)")
            return nil
        }

        let gridH = shape[rowDim]
        let gridW = shape[colDim]
        // Access pointers as Float16 (bits) and convert on read.
        // Model was converted with FLOAT16 precision.
        let confBits = conf.dataPointer.bindMemory(to: UInt16.self, capacity: conf.count)
        let xBits = xOff.dataPointer.bindMemory(to: UInt16.self, capacity: xOff.count)
        let yBits = yOff.dataPointer.bindMemory(to: UInt16.self, capacity: yOff.count)
        @inline(__always) func f16(_ bits: UInt16) -> Float32 {
            return Float32(Float16(bitPattern: bits))
        }

        func idx(_ t: Int, _ r: Int, _ c: Int) -> Int {
            var indices = Array(repeating: 0, count: shape.count)
            if let b = bDim { indices[b] = 0 }
            indices[tDim] = t
            indices[rowDim] = r
            indices[colDim] = c
            var off = 0
            for i in 0..<shape.count { off += indices[i] * strides[i] }
            return off
        }
        func idxWithStrides(_ customStrides: [Int], _ t: Int, _ r: Int, _ c: Int) -> Int {
            var indices = Array(repeating: 0, count: shape.count)
            if let b = bDim { indices[b] = 0 }
            indices[tDim] = t
            indices[rowDim] = r
            indices[colDim] = c
            var off = 0
            for i in 0..<shape.count { off += indices[i] * customStrides[i] }
            return off
        }

        // Use configured target frame within the 5-frame clip
        let t = targetFrameIndex
        var best: Float32 = -Float.greatestFiniteMagnitude
        var minConf: Float32 = Float.greatestFiniteMagnitude
        var maxConf: Float32 = -Float.greatestFiniteMagnitude
        var br = 0, bc = 0
        for r in 0..<gridH {
            for c in 0..<gridW {
                let v = f16(confBits[idx(t, r, c)])
                if v < minConf { minConf = v }
                if v > maxConf { maxConf = v }
                if v > best { best = v; br = r; bc = c }
            }
        }

        // Threshold 0.5 (as per thesis and notes)
        let threshold: Float32 = 0.5
        
        guard best >= threshold else { return nil }

        // Map to pixel space (768x432) then normalize. Use per-axis step sizes
        // derived from the chosen grid dimensions (supports swapped mapping).
        let stepX: Float32 = 768.0 / Float32(gridW)
        let stepY: Float32 = 432.0 / Float32(gridH)
        let xPx = (Float32(bc) + f16(xBits[idxWithStrides(xStrides, t, br, bc)])) * stepX
        let yPx = (Float32(br) + f16(yBits[idxWithStrides(yStrides, t, br, bc)])) * stepY

        var xNorm = CGFloat(xPx / 768.0)
        let yNormTop = CGFloat(yPx / 432.0)
        // Convert to Vision-style bottom-left origin
        var yNorm = 1.0 - yNormTop

        

        // Clamp to [0,1]
        xNorm = min(max(xNorm, 0.0), 1.0)
        yNorm = min(max(yNorm, 0.0), 1.0)

        
        return CGPoint(x: xNorm, y: yNorm)
    }

    // Decode positions for all 5 frame indices from a single inference.
    // Returns five samples ordered by tIndex 0..4 with timestamps mapped from the input buffer times.
    func detectAllSamplesIfReady() -> [Sample]? {
        guard let out = predictIfReady() else { return nil }

        let conf = out.conf
        let xOff = out.xOff
        let yOff = out.yOff

        let shape = conf.shape.map { Int(truncating: $0) }
        let strides = conf.strides.map { Int(truncating: $0) }
        let xStrides = xOff.strides.map { Int(truncating: $0) }
        let yStrides = yOff.strides.map { Int(truncating: $0) }

        // Identify dims similar to single-frame path
        var bDim: Int? = nil
        var tDim: Int? = nil
        for i in 0..<shape.count {
            let s = shape[i]
            if s == 1 && shape.count == 4 && bDim == nil { bDim = i; continue }
            if s == 5 && tDim == nil { tDim = i; continue }
        }
        var rowDim: Int? = nil
        var colDim: Int? = nil
        for i in 0..<shape.count where i != bDim && i != tDim {
            let s = shape[i]
            if s == 27 { rowDim = i } else if s == 48 { colDim = i }
        }
        if rowDim == nil || colDim == nil {
            let candidates = (0..<shape.count).filter { $0 != bDim && $0 != tDim }
            if candidates.count == 2 {
                let a = candidates[0], b = candidates[1]
                if shape[a] <= shape[b] { rowDim = a; colDim = b } else { rowDim = b; colDim = a }
            }
        }
        guard let tDim = tDim, let rowDim = rowDim, let colDim = colDim else {
            print("GridTrackNetDetector: unexpected conf shape (all): \(shape)")
            return nil
        }

        let gridH = shape[rowDim]
        let gridW = shape[colDim]
        let confBits = conf.dataPointer.bindMemory(to: UInt16.self, capacity: conf.count)
        let xBits = xOff.dataPointer.bindMemory(to: UInt16.self, capacity: xOff.count)
        let yBits = yOff.dataPointer.bindMemory(to: UInt16.self, capacity: yOff.count)
        @inline(__always) func f16(_ bits: UInt16) -> Float32 { Float32(Float16(bitPattern: bits)) }

        func idx(_ t: Int, _ r: Int, _ c: Int) -> Int {
            var indices = Array(repeating: 0, count: shape.count)
            if let b = bDim { indices[b] = 0 }
            indices[tDim] = t
            indices[rowDim] = r
            indices[colDim] = c
            var off = 0
            for i in 0..<shape.count { off += indices[i] * strides[i] }
            return off
        }
        func idxWithStrides(_ custom: [Int], _ t: Int, _ r: Int, _ c: Int) -> Int {
            var indices = Array(repeating: 0, count: shape.count)
            if let b = bDim { indices[b] = 0 }
            indices[tDim] = t
            indices[rowDim] = r
            indices[colDim] = c
            var off = 0
            for i in 0..<shape.count { off += indices[i] * custom[i] }
            return off
        }

        let stepX: Float32 = 768.0 / Float32(gridW)
        let stepY: Float32 = 432.0 / Float32(gridH)
        let threshold: Float32 = 0.5

        // Snapshot timestamps under lock
        let ts: [CFTimeInterval] = sync.sync { times }

        var samples: [Sample] = []
        for t in 0..<5 {
            var best: Float32 = -Float.greatestFiniteMagnitude
            var br = 0, bc = 0
            for r in 0..<gridH {
                for c in 0..<gridW {
                    let v = f16(confBits[idx(t, r, c)])
                    if v > best { best = v; br = r; bc = c }
                }
            }

            var pos: CGPoint? = nil
            if best >= threshold {
                let xPx = (Float32(bc) + f16(xBits[idxWithStrides(xStrides, t, br, bc)])) * stepX
                let yPx = (Float32(br) + f16(yBits[idxWithStrides(yStrides, t, br, bc)])) * stepY
                let xNorm = CGFloat(xPx / 768.0)
                let yNorm = CGFloat(1.0 - (yPx / 432.0))
                var xn = min(max(xNorm, 0.0), 1.0)
                var yn = min(max(yNorm, 0.0), 1.0)
                pos = CGPoint(x: xn, y: yn)
            }

            let time = (t < ts.count) ? ts[t] : CACurrentMediaTime()
            samples.append(Sample(tIndex: t, timestamp: time, position: pos, confidence: Float(best)))
        }
        return samples
    }
}

// No private diagnostics helpers remain.
