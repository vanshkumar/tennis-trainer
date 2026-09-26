import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class PracticeLifecycleTests: XCTestCase {
  func testPauseInvalidatesHeldPlaybackPublication() throws {
    let pipeline = LifecyclePipeline()
    let player = VideoPlayerManager()
    player.setupBallDetection(with: pipeline.pose, factory: { _ in pipeline.manager })
    var frames = 0
    player.onFrameProcessed = { frames += 1 }
    let output = try LifecycleOutput()
    player.processCurrentFrame(output: output, requestedTime: .zero, orientation: .up)
    pipeline.worker.drain()
    player.pause()
    pipeline.publication.drain()
    XCTAssertEqual(frames, 0, "Pause must invalidate held frame effects")
    XCTAssertTrue(pipeline.pose.detectedPose.isEmpty, "Pause must invalidate held pose effects")
  }

  func testStopInvalidatesHeldPublication_BeforePhysicalTeardown() throws {
    try assertCameraStop(holdPublication: true)
  }

  func testStopInvalidatesHeldWorker_BeforePhysicalTeardown() throws {
    try assertCameraStop(holdPublication: false)
  }

  private func assertCameraStop(holdPublication: Bool) throws {
    let fixture = CaptureFixture()
    fixture.start()
    try fixture.feed(1...4)
    fixture.camera.receiveSampleBuffer(try LifecycleFixture.sample(5))
    if holdPublication { fixture.pipeline.worker.drain() }
    let released = fixture.pipeline.manager.diagnostics.released
    fixture.camera.stopCapture()
    XCTAssertFalse(fixture.camera.captureRequested)
    XCTAssertFalse(fixture.camera.isRecording)
    XCTAssertFalse(fixture.session.jobs.isEmpty, "Physical teardown remains queued")
    XCTAssertEqual(fixture.pipeline.manager.diagnostics.currentLeases, 1)
    fixture.pipeline.flush()
    XCTAssertNil(fixture.pipeline.manager.ballPosition)
    XCTAssertTrue(fixture.pipeline.pose.detectedPose.isEmpty)
    XCTAssertEqual(fixture.frames, 4)
    XCTAssertEqual(fixture.tracks, 0)
    XCTAssertEqual(fixture.cues, 0)
    XCTAssertEqual(fixture.pipeline.manager.diagnostics.released, released + 1)
    XCTAssertEqual(fixture.pipeline.manager.diagnostics.currentLeases, 0)
    fixture.start()
    try fixture.feed(1...4)
    let predictions = fixture.pipeline.windows.count
    XCTAssertEqual(fixture.pipeline.manager.diagnostics.preparedRingCount, 4)
    XCTAssertEqual(fixture.cues, 0)
    try fixture.feed(5...9)
    XCTAssertEqual(fixture.pipeline.windows.count, predictions + 5)
    XCTAssertEqual(fixture.cues, 1)
    XCTAssertEqual(fixture.pipeline.manager.diagnostics.leaseHighWater, 1)
    XCTAssertEqual(fixture.pipeline.manager.diagnostics.pendingInputs, 0)
  }

  func testAcquiredCaptureCallbackCannotEnterRestartedGeneration() throws {
    let fixture = CaptureFixture()
    fixture.start()
    var crossed = false
    fixture.beforeAdmission = {
      guard !crossed else { return }
      crossed = true
      fixture.camera.stopCapture()
      fixture.start()
    }
    let admitted = fixture.pipeline.manager.diagnostics.admitted
    fixture.camera.receiveSampleBuffer(try LifecycleFixture.sample(99))
    fixture.pipeline.flush()
    XCTAssertTrue(crossed)
    XCTAssertEqual(fixture.pipeline.manager.diagnostics.admitted, admitted)
    XCTAssertEqual(fixture.frames, 0)
    try fixture.feed(1...9)
    XCTAssertEqual(fixture.cues, 1)
  }

  func testQueuedCaptureCallbackIsDrainedBeforeRestartOpensIngress() throws {
    let fixture = CaptureFixture()
    fixture.start()
    let sample = try LifecycleFixture.sample(99)
    fixture.video.enqueue { fixture.camera.receiveSampleBuffer(sample) }
    fixture.camera.stopCapture()
    fixture.camera.startCapture()
    fixture.pipeline.flush()
    fixture.session.drain()
    XCTAssertFalse(fixture.camera.isRecording)
    fixture.video.run() // Old buffer precedes the restart drain sentinel.
    XCTAssertEqual(fixture.pipeline.manager.diagnostics.admitted, 0)
    fixture.video.drain()
    fixture.session.drain()
    XCTAssertTrue(fixture.camera.isRecording)
    try fixture.feed(1...9)
    XCTAssertEqual(fixture.cues, 1)
    XCTAssertEqual(fixture.pipeline.windows.first?.first?.identity.sequence, 1)
    XCTAssertEqual(fixture.events.suffix(4), ["stop", "detach", "attach", "start"])
  }

  func testFreshCaptureTossCanCueInsideRetiredSessionsCooldown() throws {
    let fixture = CaptureFixture()
    fixture.start()
    try fixture.feed(1...9)
    XCTAssertEqual(fixture.cues, 1)
    fixture.camera.stopCapture()
    fixture.start()
    try fixture.feed(1...4)
    XCTAssertEqual(fixture.cues, 1)
    try fixture.feed(5...9)
    XCTAssertEqual(fixture.cues, 2)
  }

  func testStopDuringPendingStartRejectsDelayedDrainAndStart() throws {
    let fixture = CaptureFixture()
    fixture.camera.startCapture()
    XCTAssertTrue(fixture.camera.captureRequested)
    fixture.session.drain()
    fixture.camera.stopCapture()
    fixture.video.drain()
    fixture.session.drain()
    fixture.pipeline.flush()
    XCTAssertFalse(fixture.camera.isRecording)
    XCTAssertFalse(fixture.events.contains("start"))
    fixture.start()
    try fixture.feed(1...9)
    XCTAssertEqual(fixture.cues, 1)
  }

  func testFailedPhysicalStartDoesNotOpenCaptureIngress() throws {
    let fixture = CaptureFixture()
    fixture.startSucceeds = false
    fixture.start()
    fixture.camera.receiveSampleBuffer(try LifecycleFixture.sample(1))
    fixture.pipeline.flush()
    XCTAssertEqual(fixture.pipeline.manager.diagnostics.admitted, 0)
    XCTAssertFalse(fixture.camera.isRecording)
    XCTAssertTrue(fixture.camera.captureRequested, "Stop stays available")
  }
}

private final class CaptureFixture {
  let session = LifecycleScheduler()
  let video = LifecycleScheduler()
  let pipeline = LifecyclePipeline()
  var events: [String] = []
  var beforeAdmission: (() -> Void)?
  var startSucceeds = true
  var frames = 0
  var cues = 0
  var tracks = 0
  lazy var camera: CameraManager = {
    let camera = CameraManager(dependencies: .init(session: session.enqueue, drain: video.enqueue,
      state: { $0() }, stop: { [unowned self] in events.append("stop") },
      attach: { [unowned self] in events.append($0 ? "attach" : "detach") },
      start: { [unowned self] in events.append("start"); return startSucceeds },
      beforeAdmission: { [unowned self] in beforeAdmission?() }))
    camera.setupBallDetection(with: pipeline.pose, factory: { [unowned self] _ in pipeline.manager })
    camera.onFrameProcessed = { [unowned self] in frames += 1 }
    camera.onApex = { [unowned self] in cues += 1 }
    pipeline.manager.onBallTrack = { [unowned self] _ in tracks += 1 }
    return camera
  }()
  func start() {
    camera.startCapture()
    pipeline.flush()
    session.drain()
    video.drain()
    session.drain()
  }
  func feed(_ range: ClosedRange<Int>) throws {
    for index in range {
      camera.receiveSampleBuffer(try LifecycleFixture.sample(index))
      pipeline.flush()
    }
  }
}

private final class LifecyclePipeline {
  let worker = LifecycleScheduler()
  let publication = LifecycleScheduler()
  let pose = PoseDetectionManager(transaction: { _, _ in [:] })
  var windows: [[AnalysisFrame.Metadata]] = []
  lazy var grid = GridTrackNetDetector(predictor: { [unowned self] window in
    windows.append(window.frames.map(\.metadata))
    return try DecoderFixture.tossOutputs(window)
  })
  lazy var manager = BallDetectionManager(dependencies: .init(analyze: { [unowned self] input, identity, pose in
    guard grid.pushFrame(input: input, identity: identity, pose: pose) else { return .init(samples: nil, position: nil) }
    return .init(samples: grid.detectAllSamplesIfReady(), position: nil)
  }, extractPose: { _, identity in
    .init(identity: identity, joints: [.nose: .init(location: CGPoint(x: 0.5,
      y: identity.sequence == 3 ? 0.6 : 0.95), confidence: 0.9)])
  }, publishPose: { [unowned self] in pose.publish($0) }, reset: { [unowned self] in grid.clear() },
  bufferDiagnostics: { [unowned self] in grid.diagnostics }, worker: worker.enqueue, publication: publication.enqueue))
  func flush() { worker.drain(); publication.drain() }
}

private final class LifecycleScheduler {
  var jobs: [() -> Void] = []
  func enqueue(_ job: @escaping () -> Void) { jobs.append(job) }
  func run() { if !jobs.isEmpty { jobs.removeFirst()() } }
  func drain() { while !jobs.isEmpty { run() } }
}

private final class LifecycleOutput: VideoPlayerManager.FrameOutputReading {
  let pixels: CVPixelBuffer
  var time = CMTime(value: 10033, timescale: 1000)
  var beforeReturn: (() -> Void)?
  init() throws { pixels = try AnalysisFixture.pixels() }
  func hasNewPixelBuffer(forItemTime: CMTime) -> Bool { true }
  func copyFrame(forItemTime: CMTime) -> (CVPixelBuffer, CMTime)? {
    let acquired = time
    beforeReturn?()
    return (pixels, acquired)
  }
}

private enum LifecycleFixture {
  static func sample(_ index: Int) throws -> CMSampleBuffer {
    let pixels = try AnalysisFixture.pixels()
    var format: CMVideoFormatDescription?
    XCTAssertEqual(CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixels,
      formatDescriptionOut: &format), noErr)
    var timing = CMSampleTimingInfo(duration: .invalid,
      presentationTimeStamp: CMTime(value: Int64(10000 + index * 33), timescale: 1000), decodeTimeStamp: .invalid)
    var sample: CMSampleBuffer?
    XCTAssertEqual(CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixels,
      formatDescription: try XCTUnwrap(format), sampleTiming: &timing, sampleBufferOut: &sample), noErr)
    return try XCTUnwrap(sample)
  }
}
