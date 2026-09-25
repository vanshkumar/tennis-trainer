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
    let ingressTime = CACurrentMediaTime()
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
    var analyze: (Input, FrameIdentity, PoseDetectionManager.FramePose) throws -> Analysis
    var extractPose: (Input, FrameIdentity) -> PoseDetectionManager.FramePose = { _, identity in
      .init(identity: identity, joints: [:])
    }
    var publishPose: (PoseDetectionManager.FramePose) -> Void = { _ in }
    var reset: () -> Void = {}
    var bufferDiagnostics: () -> GridTrackNetDetector.Diagnostics = { .init(ringCount: 0, uniquePreparedBufferCount: 0) }
    var worker: (@escaping () -> Void) -> Void
    var publication: (@escaping () -> Void) -> Void
  }

  struct Lease {
    let id = UUID()
    let identity: FrameIdentity
  }

  struct Diagnostics {
    fileprivate(set) var admitted: UInt64 = 0
    fileprivate(set) var dropped: UInt64 = 0
    fileprivate(set) var completed: UInt64 = 0
    fileprivate(set) var released: UInt64 = 0
    fileprivate(set) var currentLeases = 0
    fileprivate(set) var publications = 0
    fileprivate(set) var leaseHighWater = 0
    fileprivate(set) var publicationHighWater = 0
    let pendingInputs = 0
    fileprivate(set) var preparedRingCount = 0
    fileprivate(set) var uniquePreparedBufferCount = 0
  }

  // The small scheduler state outlives an owner if a held scheduler retains a job.
  // Jobs capture it, never the manager, so teardown still releases the owned lease.
  private final class State {
    let lock = NSRecursiveLock()
    var sourceID: UUID?
    var generation = UUID()
    var sequence: UInt64 = 0
    var lastTime: CMTime?
    var lease: Lease?
    var needsReset = false
    var diagnostics = Diagnostics()

    func isCurrent(_ identity: FrameIdentity) -> Bool {
      sourceID == identity.sourceID && generation == identity.generation
    }

    func reserve(_ value: Lease) {
      lease = value
      diagnostics.currentLeases = 1
      diagnostics.leaseHighWater = 1
    }

    func markPublication() {
      lock.lock()
      diagnostics.publications = 1
      diagnostics.publicationHighWater = 1
      lock.unlock()
    }

    func release(_ owned: Lease) {
      lock.lock()
      defer { lock.unlock() }
      guard lease?.id == owned.id else { return }
      lease = nil
      diagnostics.currentLeases = 0
      diagnostics.publications = 0
      Self.increment(&diagnostics.released)
    }

    func takeReset() -> Bool {
      lock.lock()
      defer { lock.unlock() }
      let reset = needsReset
      needsReset = false
      return reset
    }

    static func increment(_ value: inout UInt64) {
      if value < UInt64.max { value += 1 }
    }
  }

  @Published var ballPosition: CGPoint?
  var onBallTrack: (([GridTrackNetDetector.Sample]) -> Void)?
  var onApex: (() -> Void)?
  var onFrameProcessed: (() -> Void)?
  private let dependencies: Dependencies
  private let overlayTIndex: Int
  private let apexDetector = ServeTossApexDetector()
  private let state = State()
  private let compatibilitySourceID = UUID()

  var diagnostics: Diagnostics {
    state.lock.lock()
    defer { state.lock.unlock() }
    var value = state.diagnostics
    let buffers = dependencies.bufferDiagnostics()
    value.preparedRingCount = buffers.ringCount
    value.uniquePreparedBufferCount = buffers.uniquePreparedBufferCount
    return value
  }

  init(dependencies: Dependencies, overlayTIndex: Int = 4, initialSequence: UInt64 = 0) {
    self.dependencies = dependencies
    self.overlayTIndex = overlayTIndex
    state.sequence = initialSequence
  }

  var cueDiagnostics: ServeTossApexDetector.CueDiagnostics {
    state.lock.lock()
    defer { state.lock.unlock() }
    return apexDetector.diagnostics
  }

  convenience init(poseDetectionManager: PoseDetectionManager?, overlayTIndex: Int = 2,
                   dependencies: Dependencies? = nil,
                   productionFactory: ((PoseDetectionManager?) -> Dependencies)? = nil) {
    self.init(dependencies: dependencies ?? (productionFactory ?? Self.productionDependencies)(poseDetectionManager),
              overlayTIndex: overlayTIndex)
  }

  private static func productionDependencies(pose: PoseDetectionManager?) -> Dependencies {
    // Only the production initializer evaluates these real backend constructors.
    let grid = GridTrackNetDetector()
    let color = ColorKalmanBallDetector()
    let queue = DispatchQueue(label: "ml.ball.analysis", qos: .userInitiated)
    return Dependencies(analyze: { input, identity, framePose in
      switch AppConfig.ballDetectionMethod {
      case .gridTrackNet:
        color.reset()
        guard grid.pushFrame(input: input, identity: identity, pose: framePose) else {
          return Analysis(samples: nil, position: nil)
        }
        return Analysis(samples: grid.detectAllSamplesIfReady(), position: nil)
      case .colorKalman:
        guard let pixels = PixelBufferScaler.shared.copyApplyingOrientation(
          input.pixelBuffer, orientation: input.orientation
        ) else { return Analysis(samples: nil, position: nil) }
        return Analysis(samples: nil, position: color.process(pixelBuffer: pixels,
          shoulderX: framePose.joints[.rightShoulder]?.location.x))
      }
    }, extractPose: { input, identity in
      pose?.extractPose(in: input.pixelBuffer, orientation: input.orientation, identity: identity)
        ?? .init(identity: identity, joints: [:])
    }, publishPose: { pose?.publish($0) }, reset: { grid.clear(); color.reset() },
    bufferDiagnostics: { grid.diagnostics },
    worker: { queue.async(execute: $0) }, publication: { DispatchQueue.main.async(execute: $0) })
  }

  @discardableResult
  func process(input: Input) -> Bool {
    state.lock.lock()
    guard state.lease == nil, input.sourceTime.isValid, input.sourceTime.isNumeric,
          CMTimeGetSeconds(input.sourceTime).isFinite,
          state.sourceID == nil || state.sourceID == input.sourceID,
          state.lastTime.map({ CMTimeCompare(input.sourceTime, $0) > 0 }) ?? true,
          state.sequence < UInt64.max else {
      State.increment(&state.diagnostics.dropped)
      state.lock.unlock()
      return false
    }
    state.sourceID = input.sourceID
    state.sequence += 1
    state.lastTime = input.sourceTime
    let owned = Lease(identity: FrameIdentity(sourceID: input.sourceID,
      generation: state.generation, sequence: state.sequence, sourceTime: input.sourceTime))
    state.reserve(owned)
    State.increment(&state.diagnostics.admitted)
    state.lock.unlock()

    let state = self.state
    let dependencies = self.dependencies
    dependencies.worker { [weak self, state, dependencies] in
      guard self != nil else { state.release(owned); return }
      if state.takeReset() { dependencies.reset() }
      state.lock.lock()
      let current = state.isCurrent(owned.identity)
      state.lock.unlock()
      var pose = PoseDetectionManager.FramePose(identity: owned.identity, joints: [:])
      var result: Analysis?
      if current {
        let extracted = dependencies.extractPose(input, owned.identity)
        // A mismatched pose is missing, never a substitute for this frame.
        pose = AnalysisFrame.Metadata.associatedPose(extracted, identity: owned.identity)
        result = try? dependencies.analyze(input, owned.identity, pose)
      }
      if state.takeReset() { dependencies.reset() }
      state.markPublication()
      // Capture value results only: this closure does not retain Input/pixels/tensors.
      let completedPose = pose
      let completedResult = result
      dependencies.publication { [weak self, state] in
        defer { state.release(owned) }
        guard let self else { return }
        self.publish(completedResult, pose: completedPose, lease: owned)
      }
    }
    return true
  }

  private func publish(_ result: Analysis?, pose: PoseDetectionManager.FramePose, lease: Lease) {
    // Serializes reset against the short effect batch, never against Vision/model work.
    // Recursive locking permits a UI/callback subscriber to invalidate synchronously.
    state.lock.lock()
    defer { state.lock.unlock() }
    guard state.lease?.id == lease.id else { return }
    State.increment(&state.diagnostics.completed)
    guard state.isCurrent(lease.identity) else { clearPublishedValues(); return }
    apexDetector.reset(sourceID: lease.identity.sourceID, generation: lease.identity.generation)
    dependencies.publishPose(pose)
    guard state.isCurrent(lease.identity) else { clearPublishedValues(); return }
    ballPosition = result?.samples?.first { $0.tIndex == overlayTIndex }?.position ?? result?.position
    guard state.isCurrent(lease.identity) else { clearPublishedValues(); return }
    if let samples = result?.samples {
      onBallTrack?(samples)
      guard state.isCurrent(lease.identity) else { clearPublishedValues(); return }
      if apexDetector.consume(samples: samples) {
        onApex?()
      }
    }
    guard state.isCurrent(lease.identity) else { clearPublishedValues(); return }
    onFrameProcessed?()
  }

  private func clearPublishedValues() {
    apexDetector.reset(sourceID: state.sourceID ?? compatibilitySourceID, generation: state.generation)
    ballPosition = nil
    dependencies.publishPose(.init(identity: FrameIdentity(sourceID: state.sourceID ?? compatibilitySourceID,
      generation: state.generation, sequence: 0, sourceTime: .invalid), joints: [:]))
  }

  func resetTrackingState(sourceID: UUID? = nil) {
    state.lock.lock()
    state.generation = UUID()
    if let sourceID { state.sourceID = sourceID }
    state.sequence = 0
    state.lastTime = nil
    state.needsReset = true
    // Busy resets occupy no additional slot; their job discards its final effects.
    guard state.lease == nil else { state.lock.unlock(); return }
    let owned = Lease(identity: FrameIdentity(sourceID: state.sourceID ?? compatibilitySourceID,
      generation: state.generation, sequence: 0, sourceTime: .invalid))
    state.reserve(owned)
    state.markPublication()
    state.lock.unlock()
    let state = self.state
    dependencies.publication { [weak self, state] in
      defer { state.release(owned) }
      guard let self else { return }
      state.lock.lock()
      self.clearPublishedValues()
      state.lock.unlock()
    }
    // Model storage is cleared only by the next worker, coalescing idle resets.
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
