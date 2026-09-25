import Foundation
import CoreML
import CoreVideo
import CoreGraphics
import CoreMedia

final class GridTrackNetDetector {
  struct RawOutputs {
    let conf: MLMultiArray
    let xOff: MLMultiArray
    let yOff: MLMultiArray
  }

  struct Sample {
    let tIndex: Int
    let metadata: AnalysisFrame.Metadata
    let position: CGPoint?
    let confidence: Float
    var timestamp: CFTimeInterval { CMTimeGetSeconds(metadata.sourceTime) }
  }

  struct Diagnostics {
    let ringCount: Int
    let uniquePreparedBufferCount: Int
  }

  typealias Predictor = (AnalysisFrame.Window) throws -> RawOutputs
  private let predictor: Predictor
  private var frames: [AnalysisFrame] = []
  private let sync = NSLock()
  private let predictionLock = NSLock()

  init(predictor: @escaping Predictor) {
    self.predictor = predictor
  }

  convenience init() {
    let model: GridTrackNet5?
    do {
      let configuration = MLModelConfiguration()
      configuration.computeUnits = .all
      model = try GridTrackNet5(configuration: configuration)
    } catch {
      print("GridTrackNetDetector: failed to load model: \(error)")
      model = nil
    }
    self.init { window in
      guard let model else { throw PredictionError.missingModel }
      var inputs: [String: MLFeatureValue] = [:]
      for (index, frame) in window.frames.enumerated() {
        inputs["f\(index + 1)"] = MLFeatureValue(pixelBuffer: frame.pixels)
      }
      let provider = try MLDictionaryFeatureProvider(dictionary: inputs)
      let result = try model.model.prediction(from: provider)
      guard let conf = result.featureValue(for: "conf")?.multiArrayValue,
            let x = result.featureValue(for: "x_off")?.multiArrayValue,
            let y = result.featureValue(for: "y_off")?.multiArrayValue else {
        throw PredictionError.missingOutput
      }
      return RawOutputs(conf: conf, xOff: x, yOff: y)
    }
  }

  private enum PredictionError: Error { case missingModel, missingOutput }

  var diagnostics: Diagnostics {
    sync.lock()
    defer { sync.unlock() }
    return Diagnostics(ringCount: frames.count,
      uniquePreparedBufferCount: Set(frames.map { ObjectIdentifier($0.pixels) }).count)
  }

  func clear() {
    sync.lock()
    frames.removeAll(keepingCapacity: true)
    sync.unlock()
  }

  @discardableResult
  func pushFrame(input: BallDetectionManager.Input, identity: BallDetectionManager.FrameIdentity,
                 pose: PoseDetectionManager.FramePose) -> Bool {
    guard let frame = AnalysisFrame.prepare(input: input, identity: identity, pose: pose) else { return false }
    sync.lock()
    defer { sync.unlock() }
    if let previous = frames.last?.metadata.identity {
      guard previous.sourceID == identity.sourceID, previous.generation == identity.generation,
            previous.sequence < identity.sequence,
            CMTimeCompare(previous.sourceTime, identity.sourceTime) < 0 else { return false }
    }
    if frames.count == 5 { frames.removeFirst() }
    frames.append(frame)
    return true
  }

  func snapshot() -> AnalysisFrame.Window? {
    sync.lock()
    defer { sync.unlock() }
    return AnalysisFrame.Window(frames)
  }

  var isReady: Bool { snapshot() != nil }

  func detectNormalizedPositionIfReady() -> CGPoint? {
    detectAllSamplesIfReady()?.first { $0.tIndex == 4 }?.position
  }

  func detectAllSamplesIfReady() -> [Sample]? {
    guard let window = snapshot() else { return nil }
    return predict(window: window)
  }

  func predict(window: AnalysisFrame.Window) -> [Sample]? {
    predictionLock.lock()
    defer { predictionLock.unlock() }
    do {
      return decode(try predictor(window), window: window)
    } catch {
      print("GridTrackNetDetector: prediction error: \(error)")
      return nil
    }
  }

  // The result is decoded against the exact snapshot given to the predictor.
  func decode(_ out: RawOutputs, window: AnalysisFrame.Window) -> [Sample]? {
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
        pos = window.frames[t].metadata.mapping.sourceNormalizedPoint(modelX: xPx, modelYFromTop: yPx)
      }

      samples.append(Sample(tIndex: t, metadata: window.frames[t].metadata, position: pos, confidence: Float(best)))
    }
    return samples
  }
}
