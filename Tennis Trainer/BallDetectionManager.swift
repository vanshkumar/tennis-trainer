import Foundation
import CoreVideo
import CoreGraphics
import CoreMedia
import QuartzCore
import ImageIO

final class BallDetectionManager: ObservableObject {
  struct Input {
    let pixelBuffer: CVPixelBuffer
    let sourceTime: CMTime
    let orientation: CGImagePropertyOrientation
    let sourceID: UUID
  }

  struct FrameIdentity: Equatable {
    let sourceID: UUID
    let generation: UUID
    let sequence: UInt64
    let sourceTime: CMTime
  }

  struct Analysis {
    let samples: [GridTrackNetDetector.Sample]?
    let position: CGPoint?
  }

  struct Dependencies {
    var analyze: (Input, FrameIdentity) throws -> Analysis
    var reset: () -> Void = {}
    var worker: (@escaping () -> Void) -> Void
    var publication: (@escaping () -> Void) -> Void
  }

  struct Lease {
    let id = UUID()
    let identity: FrameIdentity
  }

  @Published var ballPosition: CGPoint?
  var onBallTrack: (([GridTrackNetDetector.Sample]) -> Void)?
  var onApex: (() -> Void)?
  var onFrameProcessed: (() -> Void)?

  private let dependencies: Dependencies
  private let overlayTIndex: Int
  private weak var poseDetectionManager: PoseDetectionManager?
  private let apexDetector = ServeTossApexDetector()
  private let lock = NSLock()
  private var sourceID: UUID?
  private var generation = UUID()
  private var sequence: UInt64 = 0
  private var lastTime: CMTime?
  private var lease: Lease?
  private var needsReset = false
  private let compatibilitySourceID = UUID()

  init(dependencies: Dependencies, overlayTIndex: Int = 4) {
    self.dependencies = dependencies
    self.overlayTIndex = overlayTIndex
  }

  convenience init(poseDetectionManager: PoseDetectionManager?, overlayTIndex: Int = 2) {
    self.init(dependencies: Self.productionDependencies(pose: poseDetectionManager),
              overlayTIndex: overlayTIndex)
    self.poseDetectionManager = poseDetectionManager
  }

  private static func productionDependencies(pose: PoseDetectionManager?) -> Dependencies {
    // This factory is evaluated only by the production initializer.
    let grid = GridTrackNetDetector()
    let color = ColorKalmanBallDetector()
    let queue = DispatchQueue(label: "ml.ball.analysis", qos: .userInitiated)
    return Dependencies(analyze: { input, _ in
      pose?.detectPose(in: input.pixelBuffer, orientation: input.orientation)
      switch AppConfig.ballDetectionMethod {
      case .gridTrackNet:
        color.reset()
        grid.pushFrame(input.pixelBuffer, timestamp: CMTimeGetSeconds(input.sourceTime),
                       orientation: input.orientation)
        return Analysis(samples: grid.detectAllSamplesIfReady(), position: nil)
      case .colorKalman:
        guard let pixels = PixelBufferScaler.shared.copyApplyingOrientation(
          input.pixelBuffer, orientation: input.orientation
        ) else { return Analysis(samples: nil, position: nil) }
        return Analysis(samples: nil,
          position: color.process(pixelBuffer: pixels, poseDetectionManager: pose))
      }
    }, reset: { grid.clear(); color.reset() },
    worker: { queue.async(execute: $0) }, publication: { DispatchQueue.main.async(execute: $0) })
  }

  @discardableResult
  func process(input: Input) -> Bool {
    lock.lock()
    guard lease == nil, input.sourceTime.isValid, input.sourceTime.isNumeric,
          CMTimeGetSeconds(input.sourceTime).isFinite,
          sourceID == nil || sourceID == input.sourceID,
          lastTime.map({ CMTimeCompare(input.sourceTime, $0) > 0 }) ?? true,
          sequence < UInt64.max else {
      lock.unlock()
      return false
    }
    sourceID = input.sourceID
    sequence += 1
    lastTime = input.sourceTime
    let admitted = Lease(identity: FrameIdentity(sourceID: input.sourceID,
      generation: generation, sequence: sequence, sourceTime: input.sourceTime))
    lease = admitted
    let reset = needsReset
    needsReset = false
    lock.unlock()

    dependencies.worker { [weak self] in
      guard let self else { return }
      if reset { self.dependencies.reset() }
      let result = try? self.dependencies.analyze(input, admitted.identity)
      self.dependencies.publication { [weak self] in
        guard let self else { return }
        defer { self.release(admitted) }
        guard self.isCurrent(admitted.identity) else {
          self.ballPosition = nil
          self.apexDetector.reset()
          return
        }
        self.ballPosition = result?.samples?.first { $0.tIndex == self.overlayTIndex }?.position
          ?? result?.position
        if let samples = result?.samples {
          self.onBallTrack?(samples)
          if self.apexDetector.consume(samples: samples, heightGateProvider: self.poseDetectionManager) {
            self.onApex?()
          }
        }
        self.onFrameProcessed?()
      }
    }
    return true
  }

  private func isCurrent(_ identity: FrameIdentity) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return sourceID == identity.sourceID && generation == identity.generation
  }

  private func release(_ completed: Lease) {
    lock.lock()
    defer { lock.unlock() }
    if lease?.id == completed.id { lease = nil }
  }

  func resetTrackingState(sourceID: UUID? = nil) {
    lock.lock()
    generation = UUID()
    if let sourceID { self.sourceID = sourceID }
    sequence = 0
    lastTime = nil
    needsReset = true
    lock.unlock()
  }

  func process(pixelBuffer: CVPixelBuffer) {
    process(pixelBuffer: pixelBuffer, timestamp: CACurrentMediaTime())
  }

  func process(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
    process(pixelBuffer: pixelBuffer, timestamp: CACurrentMediaTime(), orientation: orientation)
  }

  func process(pixelBuffer: CVPixelBuffer, timestamp: CFTimeInterval,
               orientation: CGImagePropertyOrientation = .up) {
    process(input: Input(pixelBuffer: pixelBuffer,
      sourceTime: CMTime(seconds: timestamp, preferredTimescale: 1_000_000_000),
      orientation: orientation, sourceID: compatibilitySourceID))
  }
}
