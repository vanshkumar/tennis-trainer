import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class BallDetectionManagerTests: XCTestCase {
  func testPreparedPixelsRemainOwned_WhenSourceIsMutated() throws {
    var source: CVPixelBuffer?
    XCTAssertEqual(CVPixelBufferCreate(nil, 768, 432, kCVPixelFormatType_32BGRA,
      nil, &source), kCVReturnSuccess)
    let pixels = try XCTUnwrap(source)
    CVPixelBufferLockBaseAddress(pixels, [])
    memset(CVPixelBufferGetBaseAddress(pixels), 42, CVPixelBufferGetDataSize(pixels))
    CVPixelBufferUnlockBaseAddress(pixels, [])
    let detector = GridTrackNetDetector()
    detector.pushFrame(pixels, timestamp: 1, orientation: .up)
    let retained = try XCTUnwrap(Mirror(reflecting: detector).children.first {
      $0.label == "frames"
    }?.value as? [CVPixelBuffer]).first!
    CVPixelBufferLockBaseAddress(pixels, [])
    memset(CVPixelBufferGetBaseAddress(pixels), 99, CVPixelBufferGetDataSize(pixels))
    CVPixelBufferUnlockBaseAddress(pixels, [])
    CVPixelBufferLockBaseAddress(retained, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(retained, .readOnly) }
    XCTAssertEqual(CVPixelBufferGetBaseAddress(retained)!.load(as: UInt8.self), 42)
  }

  private final class Scheduler {
    var jobs: [() -> Void] = []
    func enqueue(_ job: @escaping () -> Void) { jobs.append(job) }
    func run() { jobs.removeFirst()() }
  }

  private func input(_ pixels: CVPixelBuffer, _ time: Int64, source: UUID) -> BallDetectionManager.Input {
    .init(pixelBuffer: pixels, sourceTime: CMTime(value: time, timescale: 1000),
          orientation: .up, sourceID: source)
  }

  func testBoundedWork_WhenWorkerAndPublicationAreHeld() throws {
    let worker = Scheduler()
    let publication = Scheduler()
    var calls = 0
    var poses = 0
    var effects = 0
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
      calls += 1
      return .init(samples: nil, position: CGPoint(x: 0.5, y: 0.5))
    }, extractPose: { _, identity in
      poses += 1
      return .init(identity: identity, joints: [:])
    }, worker: worker.enqueue, publication: publication.enqueue))
    manager.onFrameProcessed = { effects += 1 }
    let buffer = try pixels()
    let source = UUID()
    XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)))
    for i in 1...1000 { XCTAssertFalse(manager.process(input: input(buffer, Int64(i), source: source))) }
    XCTAssertEqual(worker.jobs.count, 1)
    XCTAssertEqual(calls, 0)
    XCTAssertEqual(poses, 0)
    worker.run()
    for i in 1001...2000 { XCTAssertFalse(manager.process(input: input(buffer, Int64(i), source: source))) }
    XCTAssertEqual(calls, 1)
    XCTAssertEqual(poses, 1)
    XCTAssertEqual(publication.jobs.count, 1)
    XCTAssertEqual(effects, 0)
    publication.run()
    XCTAssertEqual(effects, 1)
    XCTAssertEqual(manager.diagnostics.admitted, 1)
    XCTAssertEqual(manager.diagnostics.dropped, 2000)
    XCTAssertEqual(manager.diagnostics.completed, 1)
    XCTAssertEqual(manager.diagnostics.released, 1)
    XCTAssertEqual(manager.diagnostics.pendingInputs, 0)
    XCTAssertEqual(manager.diagnostics.leaseHighWater, 1)
    XCTAssertEqual(manager.diagnostics.publicationHighWater, 1)
    XCTAssertTrue(manager.process(input: input(buffer, 2001, source: source)))
  }

  func testClearsValues_WhenResetWhileIdle() throws {
    let publication = Scheduler()
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
      .init(samples: nil, position: CGPoint(x: 0.5, y: 0.5))
    }, worker: { $0() }, publication: publication.enqueue))
    XCTAssertTrue(manager.process(input: input(try pixels(), 0, source: UUID())))
    publication.run()
    XCTAssertNotNil(manager.ballPosition)
    for _ in 0..<1000 { manager.resetTrackingState() }
    XCTAssertEqual(publication.jobs.count, 1)
    if !publication.jobs.isEmpty { publication.run() }
    XCTAssertNil(manager.ballPosition)
  }

  func testNoCue_WhenTrackCallbackResetsGeneration() throws {
    let manager = tracer { _ in }
    let buffer = try pixels()
    let source = UUID()
    var cues = 0
    manager.onApex = { cues += 1 }
    for i in 0..<16 {
      manager.process(input: input(buffer, 10000 + Int64(i) * 33, source: source))
    }
    manager.onBallTrack = { _ in manager.resetTrackingState() }
    manager.process(input: input(buffer, 10528, source: source))
    XCTAssertEqual(cues, 0)
  }

  func testOccupiedLease_WhenRepeatedResetDuringWorkerAndPublication() throws {
    let worker = Scheduler()
    let publication = Scheduler()
    var effects = 0
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
      .init(samples: nil, position: CGPoint(x: 0.5, y: 0.5))
    }, worker: worker.enqueue, publication: publication.enqueue))
    manager.onFrameProcessed = { effects += 1 }
    let buffer = try pixels()
    let source = UUID()
    manager.process(input: input(buffer, 0, source: source))
    for _ in 0..<1000 { manager.resetTrackingState() }
    XCTAssertFalse(manager.process(input: input(buffer, 1, source: source)))
    XCTAssertEqual(worker.jobs.count, 1)
    worker.run()
    for _ in 0..<1000 { manager.resetTrackingState() }
    XCTAssertFalse(manager.process(input: input(buffer, 2, source: source)))
    XCTAssertEqual(publication.jobs.count, 1)
    publication.run()
    XCTAssertEqual(effects, 0)
    XCTAssertNil(manager.ballPosition)
    XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)))
    worker.run()
    publication.run()
    XCTAssertEqual(effects, 1)
  }
  private final class Output: VideoPlayerManager.FrameOutputReading {
    let pixels: CVPixelBuffer
    var time: CMTime = .zero
    var isNew = true
    var copies = 0
    init(_ pixels: CVPixelBuffer) { self.pixels = pixels }
    func hasNewPixelBuffer(forItemTime time: CMTime) -> Bool { isNew }
    func copyFrame(forItemTime time: CMTime) -> (CVPixelBuffer, CMTime)? {
      copies += 1
      return (pixels, self.time)
    }
  }

  private func pixels() throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    XCTAssertEqual(CVPixelBufferCreate(nil, 16, 16, kCVPixelFormatType_32BGRA,
                                       nil, &buffer), kCVReturnSuccess)
    return try XCTUnwrap(buffer)
  }

  private func sample(_ pixels: CVPixelBuffer, time: CMTime) throws -> CMSampleBuffer {
    var format: CMVideoFormatDescription?
    XCTAssertEqual(CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil,
      imageBuffer: pixels, formatDescriptionOut: &format), noErr)
    var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time,
                                   decodeTimeStamp: .invalid)
    var sample: CMSampleBuffer?
    XCTAssertEqual(CMSampleBufferCreateReadyWithImageBuffer(allocator: nil,
      imageBuffer: pixels, formatDescription: try XCTUnwrap(format),
      sampleTiming: &timing, sampleBufferOut: &sample), noErr)
    return try XCTUnwrap(sample)
  }

  private func tracer(_ received: @escaping (BallDetectionManager.Input) -> Void) -> BallDetectionManager {
    BallDetectionManager(dependencies: .init(analyze: { input, _, _ in
      received(input)
      let t = CMTimeGetSeconds(input.sourceTime)
      let y = 0.5 + 0.4 * sin(.pi * (t - 10) / 0.99)
      return .init(samples: [.init(tIndex: 4, timestamp: t,
        position: CGPoint(x: 0.5, y: y), confidence: 0.9)], position: nil)
    }, worker: { $0() }, publication: { $0() }))
  }

  func testAutomaticCue_WhenCameraSampleHasSourcePTS() throws {
    let camera = CameraManager()
    var received: [CMTime] = []
    var orientations: [CGImagePropertyOrientation] = []
    let manager = tracer { received.append($0.sourceTime); orientations.append($0.orientation) }
    camera.setupBallDetection(with: PoseDetectionManager(), factory: { _ in manager })
    var cues = 0
    var processed = 0
    camera.onApex = { cues += 1 }
    camera.onFrameProcessed = { processed += 1 }
    let buffer = try pixels()
    let times = (0..<30).map { CMTime(value: 10000 + Int64($0) * 33, timescale: 1000) }
    for time in times { camera.submitSampleBuffer(try sample(buffer, time: time)) }
    XCTAssertEqual(received, times)
    XCTAssertEqual(orientations, Array(repeating: .right, count: 30))
    XCTAssertEqual(cues, 1)
    XCTAssertEqual(processed, 30)
  }

  func testAutomaticCue_WhenPlaybackReturnsDifferentDisplayTime() throws {
    let player = VideoPlayerManager()
    var received: [CMTime] = []
    let manager = tracer { received.append($0.sourceTime) }
    player.setupBallDetection(with: PoseDetectionManager(), factory: { _ in manager })
    var cues = 0
    player.onApex = { cues += 1 }
    let output = Output(try pixels())
    let times = (0..<30).map { CMTime(value: 10000 + Int64($0) * 33, timescale: 1000) }
    for time in times {
      output.time = time
      player.processCurrentFrame(output: output, requestedTime: CMTime(value: 900, timescale: 1),
                                 orientation: .left)
    }
    output.isNew = false
    player.processCurrentFrame(output: output, requestedTime: .zero, orientation: .left)
    XCTAssertEqual(received, times)
    XCTAssertEqual(output.copies, 30)
    XCTAssertEqual(cues, 1)
  }

  func testNoRealServices_WhenDependenciesAreInjected() throws {
    XCTAssertTrue(AppRuntime.isRunningTests)
    var analyses = 0
    var factories = 0
    var productionFactories = 0
    let fake = BallDetectionManager.Dependencies(analyze: { _, _, _ in
      .init(samples: nil, position: nil)
    }, worker: { $0() }, publication: { $0() })
    _ = BallDetectionManager(poseDetectionManager: nil, dependencies: fake, productionFactory: { _ in
      productionFactories += 1
      return fake
    })
    let manager = tracer { _ in analyses += 1 }
    let camera = CameraManager()
    camera.setupBallDetection(with: PoseDetectionManager(), factory: { _ in
      factories += 1
      return manager
    })
    camera.submitSampleBuffer(try sample(pixels(), time: CMTime(value: 10, timescale: 1)))
    XCTAssertEqual(factories, 1)
    XCTAssertTrue(camera.ballDetectionManager === manager)
    XCTAssertFalse(camera.isRecording)
    XCTAssertEqual(analyses, 1)
    XCTAssertEqual(productionFactories, 0)
  }

  func testRejectsInvalidEqualAndRegressingTimes_WhenGenerationUnchanged() throws {
    let manager = tracer { _ in }
    let buffer = try pixels()
    let source = UUID()
    XCTAssertTrue(manager.process(input: input(buffer, 1000, source: source)))
    for time in [CMTime.invalid, .indefinite, .positiveInfinity, .negativeInfinity,
                 CMTime(value: 2, timescale: 2), CMTime(value: 999, timescale: 1000)] {
      XCTAssertFalse(manager.process(input: .init(pixelBuffer: buffer, sourceTime: time,
        orientation: .up, sourceID: source)))
    }
    XCTAssertFalse(manager.process(input: input(buffer, 1001, source: UUID())))
    manager.resetTrackingState(sourceID: source)
    XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)))
  }

  func testSequenceFailsClosed_WhenCounterExhaustedUntilReset() throws {
    var sequences: [UInt64] = []
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, identity, _ in
      sequences.append(identity.sequence)
      return .init(samples: nil, position: nil)
    }, worker: { $0() }, publication: { $0() }), initialSequence: UInt64.max - 1)
    let buffer = try pixels()
    let source = UUID()
    XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)))
    XCTAssertFalse(manager.process(input: input(buffer, 1, source: source)))
    manager.resetTrackingState()
    XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)))
    XCTAssertEqual(sequences, [UInt64.max, 1])
  }

  func testReleasesCapacity_WhenWarmupMissingModelPreparationOrPredictionFails() throws {
    enum Failure: Error { case prediction }
    for terminal in ["warmup", "missing-model", "preparation-failed", "prediction-threw", "result-rejected"] {
      var calls = 0
      var processed = 0
      let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
        calls += 1
        if terminal == "prediction-threw" { throw Failure.prediction }
        // These backend terminal conditions all return no usable sample batch.
        return .init(samples: nil, position: nil)
      }, worker: { $0() }, publication: { $0() }))
      manager.onFrameProcessed = { processed += 1 }
      let buffer = try pixels()
      let source = UUID()
      XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)), terminal)
      XCTAssertTrue(manager.process(input: input(buffer, 1, source: source)), terminal)
      XCTAssertEqual(calls, 2, terminal)
      XCTAssertEqual(processed, 2, terminal)
      XCTAssertEqual(manager.diagnostics.released, 2, terminal)
      XCTAssertEqual(manager.diagnostics.currentLeases, 0, terminal)
    }
  }

  func testPublishesPoseAndProcessedTogether_WhenWarmupCompletes() throws {
    let worker = Scheduler()
    let publication = Scheduler()
    var events: [String] = []
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, pose in
      XCTAssertEqual(pose.baselineY, 0.8)
      events.append("analysis")
      return .init(samples: nil, position: nil)
    }, extractPose: { _, identity in
      events.append("extract")
      return .init(identity: identity, joints: [.nose: .init(location: CGPoint(x: 0.5, y: 0.8), confidence: 0.9)])
    }, publishPose: { _ in events.append("publish-pose") },
    worker: worker.enqueue, publication: publication.enqueue))
    manager.onFrameProcessed = { events.append("processed") }
    manager.process(input: input(try pixels(), 0, source: UUID()))
    XCTAssertEqual(events, [])
    worker.run()
    XCTAssertEqual(events, ["extract", "analysis"])
    publication.run()
    XCTAssertEqual(events, ["extract", "analysis", "publish-pose", "processed"])
  }

  func testMissingPose_WhenExtractorReturnsAnotherIdentity() throws {
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, pose in
      XCTAssertNil(pose.baselineY)
      XCTAssertTrue(pose.joints.isEmpty)
      return .init(samples: nil, position: nil)
    }, extractPose: { _, identity in
      .init(identity: .init(sourceID: UUID(), generation: identity.generation,
        sequence: identity.sequence, sourceTime: identity.sourceTime),
        joints: [.nose: .init(location: CGPoint(x: 0.5, y: 0.9), confidence: 0.9)])
    }, worker: { $0() }, publication: { $0() }))
    XCTAssertTrue(manager.process(input: input(try pixels(), 0, source: UUID())))
  }

  func testTeardown_WhenWorkerOrPublicationHeld() throws {
    for holdPublication in [false, true] {
      let worker = Scheduler()
      let publication = Scheduler()
      var effects = 0
      var manager: BallDetectionManager? = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
        .init(samples: nil, position: nil)
      }, worker: worker.enqueue, publication: publication.enqueue))
      weak var weakManager = manager
      manager?.onFrameProcessed = { effects += 1 }
      manager?.process(input: input(try pixels(), 0, source: UUID()))
      if holdPublication { worker.run() }
      manager = nil
      XCTAssertNil(weakManager)
      if holdPublication { publication.run() } else { worker.run() }
      XCTAssertEqual(effects, 0)
      XCTAssertTrue(worker.jobs.isEmpty)
      XCTAssertTrue(publication.jobs.isEmpty)
    }
  }

  func testOldCompletionCannotReleaseNewLease_WhenDeliveredTwice() throws {
    let publication = Scheduler()
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
      .init(samples: nil, position: nil)
    }, worker: { $0() }, publication: publication.enqueue))
    let buffer = try pixels()
    let source = UUID()
    manager.process(input: input(buffer, 0, source: source))
    let old = publication.jobs[0]
    publication.run()
    manager.process(input: input(buffer, 1, source: source))
    old()
    XCTAssertEqual(manager.diagnostics.currentLeases, 1)
    XCTAssertEqual(manager.diagnostics.released, 1)
    XCTAssertFalse(manager.process(input: input(buffer, 2, source: source)))
    publication.run()
    XCTAssertEqual(manager.diagnostics.released, 2)
  }

  func testCombinedBounds_WhenTwoManagersSharePose() throws {
    let buffer = try pixels()
    let poseLock = NSLock()
    var active = 0
    var maximum = 0
    var poseCalls = 0
    let pose = PoseDetectionManager(transaction: { _, _ in
      poseLock.lock()
      active += 1
      maximum = max(maximum, active)
      poseCalls += 1
      poseLock.unlock()
      defer { poseLock.lock(); active -= 1; poseLock.unlock() }
      return [:]
    })
    let workers = [Scheduler(), Scheduler()]
    let publications = [Scheduler(), Scheduler()]
    let managers = (0..<2).map { i in
      BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
        .init(samples: nil, position: nil)
      }, extractPose: { input, identity in
        pose.extractPose(in: input.pixelBuffer, orientation: input.orientation, identity: identity)
      }, worker: workers[i].enqueue, publication: publications[i].enqueue))
    }
    let sources = [UUID(), UUID()]
    for i in 0..<2 {
      XCTAssertTrue(managers[i].process(input: input(buffer, 0, source: sources[i])))
      for time in 1...1000 {
        XCTAssertFalse(managers[i].process(input: input(buffer, Int64(time), source: sources[i])))
      }
    }
    XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.currentLeases }, 2)
    XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.pendingInputs }, 0)
    DispatchQueue.concurrentPerform(iterations: 2) { workers[$0].run() }
    XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.publications }, 2)
    XCTAssertEqual(poseCalls, 2)
    XCTAssertEqual(maximum, 1)
    publications.forEach { $0.run() }
    XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.currentLeases }, 0)
  }
}
