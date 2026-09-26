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
  private let preparation: AnalysisFrame.Preparation
  private var frames: [AnalysisFrame] = []
  private let sync = NSLock()
  private let predictionLock = NSLock()

  init(preparation: AnalysisFrame.Preparation = .init(), predictor: @escaping Predictor) {
    self.preparation = preparation
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
    guard let frame = AnalysisFrame.prepare(input: input, identity: identity, pose: pose,
      preparation: preparation) else { return false }
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
    GridTrackNetDecoder.decode(outputs: out, window: window)
  }
}
