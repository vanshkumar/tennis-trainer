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

    // MARK: - Model
    private var model: GridTrackNet5?
    /// Target frame within the 5-frame window [0..4].
    /// 2 = middle frame: uses two past and two future frames (lower jitter, ~2-frame latency).
    /// 4 = freshest output (lower latency, less future context). Using 4 temporarily to test alignment.
    private let targetFrameIndex: Int = 4

    // MARK: - Frame Buffer (oldest → newest)
    private var frames: [CVPixelBuffer] = []
    private let sync = DispatchQueue(label: "ml.gridtracknet.detector")
    private var inferCount: Int = 0
    private var didLogDimsOnce = false
    private var didLogTypesOnce = false
    private var didLogMinMaxOnce = false
    private var lastAppendTime: CFTimeInterval?
    private var appendCount: Int = 0
    // Mapping: height=27 (rows), width=48 (cols) — per thesis.
    private let useSwappedRowCol = false
    // Temporary: test horizontal mirror of X for display alignment
    private let flipXForDisplay = true
    private var didLogFlipOnce = false
    // Movement diagnostics
    private var prevBestRow: Int? = nil
    private var prevBestCol: Int? = nil
    private var prevNormPoint: CGPoint? = nil

    init() {
        do {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = .all
            self.model = try GridTrackNet5(configuration: cfg)
            // Log input constraint once for visibility
            if let desc = self.model?.model.modelDescription.inputDescriptionsByName["f1"],
               let ic = desc.imageConstraint {
                print("GridTrackNet input constraint: \(ic.pixelsWide)x\(ic.pixelsHigh)")
            }
        } catch {
            print("GridTrackNetDetector: failed to load model: \(error)")
            self.model = nil
        }
    }

    // MARK: - Buffer Management
    func clear() {
        sync.sync { frames.removeAll(keepingCapacity: true) }
    }

    func pushFrame(_ pixelBuffer: CVPixelBuffer) {
        sync.sync {
            let w = CVPixelBufferGetWidth(pixelBuffer)
            let h = CVPixelBufferGetHeight(pixelBuffer)
            let targetW = 768
            let targetH = 432
            let bufferToAppend: CVPixelBuffer
            var resizedFrom: (Int, Int)? = nil
            if w == targetW && h == targetH {
                bufferToAppend = pixelBuffer
            } else {
                if let resized = PixelBufferScaler.shared.resizeAspectFill(pixelBuffer, width: targetW, height: targetH) {
                    bufferToAppend = resized
                    resizedFrom = (w, h)
                } else {
                    print("GridTrackNetDetector: failed to resize frame (\(w)x\(h)) → (\(targetW)x\(targetH)); skipping.")
                    return
                }
            }

            if frames.count == 5 { frames.removeFirst() }
            frames.append(bufferToAppend)

            // Diagnostics: inter-frame dt and luminance of the buffer we feed the model
            let now = CACurrentMediaTime()
            let dtMs = lastAppendTime != nil ? (now - lastAppendTime!) * 1000.0 : -1
            lastAppendTime = now
            appendCount += 1
            if appendCount % 30 == 0 {
                let avgY = averageLuminance(bufferToAppend)
                let outW = CVPixelBufferGetWidth(bufferToAppend)
                let outH = CVPixelBufferGetHeight(bufferToAppend)
                var msg = String(format: "GridTrackNet: feed %dx%d avgY=%.1f dt=%.1f ms", outW, outH, avgY, dtMs)
                if let rf = resizedFrom { msg += " (resized from \(rf.0)x\(rf.1))" }
                print(msg)
            }
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
                let t0 = CACurrentMediaTime()
                let provider = try MLDictionaryFeatureProvider(dictionary: [
                    "f1": MLFeatureValue(pixelBuffer: frames[0]),
                    "f2": MLFeatureValue(pixelBuffer: frames[1]),
                    "f3": MLFeatureValue(pixelBuffer: frames[2]),
                    "f4": MLFeatureValue(pixelBuffer: frames[3]),
                    "f5": MLFeatureValue(pixelBuffer: frames[4]),
                ])

                let out = try model.model.prediction(from: provider)
                let dt = (CACurrentMediaTime() - t0) * 1000.0
                inferCount += 1
                if inferCount % 30 == 0 {
                    print(String(format: "GridTrackNet: prediction time %.1f ms", dt))
                }

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

        if useSwappedRowCol { swap(&rowDim, &colDim) }
        let gridH = shape[rowDim]
        let gridW = shape[colDim]
        if !didLogDimsOnce {
            print("GridTrackNet: conf shape=\(shape), strides=\(strides), dims t=\(tDim), r=\(rowDim), c=\(colDim)")
            print("GridTrackNet: x_off shape=\(xShape), strides=\(xStrides)")
            print("GridTrackNet: y_off shape=\(yShape), strides=\(yStrides)")
            didLogDimsOnce = true
        }

        // Log underlying data types once for diagnostics
        if !didLogTypesOnce {
            print("GridTrackNet: dataTypes conf=\(conf.dataType.rawValue) x=\(xOff.dataType.rawValue) y=\(yOff.dataType.rawValue)")
            didLogTypesOnce = true
        }
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

        if !didLogMinMaxOnce || inferCount % 30 == 0 {
            print(String(format: "GridTrackNet: conf[t=%d] min=%.3f max=%.3f", t, minConf, maxConf))
            didLogMinMaxOnce = true
        }

        // Threshold 0.5 (as per thesis and notes)
        let threshold: Float32 = 0.5
        if inferCount % 30 == 0 {
            print(String(format: "GridTrackNet: best conf = %.3f (thr=%.2f) at r=%d c=%d", best, threshold, br, bc))
            // Log offsets at the chosen cell (using each tensor's own strides)
            let xi = idxWithStrides(xStrides, t, br, bc)
            let yi = idxWithStrides(yStrides, t, br, bc)
            let xo = f16(xBits[xi])
            let yo = f16(yBits[yi])
            print(String(format: "GridTrackNet: offsets@best x=%.3f y=%.3f (t=%d r=%d c=%d)", xo, yo, t, br, bc))
        }
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

        // Optional: horizontal mirror
        if flipXForDisplay {
            xNorm = 1.0 - xNorm
            if !didLogFlipOnce {
                print("GridTrackNet: applying horizontal X flip for display alignment")
                didLogFlipOnce = true
            }
        }

        // Clamp to [0,1]
        xNorm = min(max(xNorm, 0.0), 1.0)
        yNorm = min(max(yNorm, 0.0), 1.0)

        if inferCount % 30 == 0 {
            // Movement diagnostics
            var cellMove = ""
            if let pr = prevBestRow, let pc = prevBestCol {
                let dr = br - pr
                let dc = bc - pc
                let mag = sqrt(Float(dr*dr + dc*dc))
                cellMove = String(format: " cellΔ r=%d c=%d |Δ|=%.1f", dr, dc, mag)
            }
            var normMove = ""
            if let p = prevNormPoint {
                let dx = Double(xNorm - p.x)
                let dy = Double(yNorm - p.y)
                let dmag = sqrt(dx*dx + dy*dy)
                normMove = String(format: " normΔ x=%.3f y=%.3f |Δ|=%.3f", dx, dy, dmag)
            }
            print(String(format: "GridTrackNet: norm pos (x=%.3f,y=%.3f)%@%@", xNorm, yNorm, cellMove, normMove))
        }
        prevBestRow = br
        prevBestCol = bc
        prevNormPoint = CGPoint(x: xNorm, y: yNorm)
        return CGPoint(x: xNorm, y: yNorm)
    }
}

// MARK: - Diagnostics helpers
private extension GridTrackNetDetector {
    func averageLuminance(_ pixelBuffer: CVPixelBuffer, sampleStride: Int = 8) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return -1 }
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        let bpr = CVPixelBufferGetBytesPerRow(pixelBuffer)

        var sum: Double = 0
        var count: Int = 0
        for y in stride(from: 0, to: h, by: sampleStride) {
            let row = base.advanced(by: y * bpr)
            for x in stride(from: 0, to: w, by: sampleStride) {
                let p = row.advanced(by: x * 4)
                let b = Double(p.load(fromByteOffset: 0, as: UInt8.self))
                let g = Double(p.load(fromByteOffset: 1, as: UInt8.self))
                let r = Double(p.load(fromByteOffset: 2, as: UInt8.self))
                // Rec.709 luma
                sum += 0.2126 * r + 0.7152 * g + 0.0722 * b
                count += 1
            }
        }
        return count > 0 ? sum / Double(count) : -1
    }
}
