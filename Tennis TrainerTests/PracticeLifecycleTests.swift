import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class PracticeLifecycleTests: XCTestCase {
  func testInterruptionInvalidatesHeldWorkAndRecoveryRequiresFreshTossWindow() throws {
    for holdPublication in [false, true] {
      let fixture = CaptureFixture()
      fixture.start()
      try fixture.feed(1...4)
      fixture.camera.receiveSampleBuffer(try LifecycleFixture.sample(5))
      if holdPublication { fixture.pipeline.worker.drain() }
      fixture.interrupted = true
      fixture.sessionEvent?(.interrupted)
      fixture.pipeline.flush()
      XCTAssertEqual(fixture.camera.captureState, .interrupted)
      XCTAssertEqual(fixture.frames, 4)
      XCTAssertEqual(fixture.cues, 0)
      XCTAssertTrue(fixture.pipeline.pose.detectedPose.isEmpty)
      fixture.interrupted = false
      fixture.sessionEvent?(.interruptionEnded)
      XCTAssertEqual(fixture.camera.captureState, .recovering)
      fixture.session.drain(); fixture.video.drain(); fixture.session.drain()
      fixture.pipeline.flush()
      try fixture.feed(1...4)
      XCTAssertEqual(fixture.pipeline.manager.diagnostics.preparedRingCount, 4)
      XCTAssertEqual(fixture.cues, 0)
      try fixture.feed(5...9)
      XCTAssertEqual(fixture.cues, 1)
      XCTAssertTrue(fixture.camera.isRecording)
    }
  }

  func testPauseInvalidatesHeldPlaybackPublication() throws {
    try assertPlaybackExit(holdPublication: true, contextExit: false)
  }

  func testPauseInvalidatesHeldPlaybackWorker() throws {
    try assertPlaybackExit(holdPublication: false, contextExit: false)
  }

  func testPlaybackContextExitInvalidatesBothHeldStages() throws {
    for held in [false, true] { try assertPlaybackExit(holdPublication: held, contextExit: true) }
  }

  private func assertPlaybackExit(holdPublication: Bool, contextExit: Bool) throws {
    let fixture = try PlaybackFixture()
    fixture.play()
    try fixture.feed(1...4)
    fixture.offer(5)
    if holdPublication { fixture.pipeline.worker.drain() }
    let generation = fixture.pipeline.manager.admissionGeneration
    let released = fixture.pipeline.manager.diagnostics.released
    fixture.onPause = {
      XCTAssertNotEqual(fixture.pipeline.manager.admissionGeneration, generation,
        "Invalidation must precede physical pause")
    }
    if contextExit { fixture.player.setContextActive(false) } else { fixture.player.pause() }
    fixture.onPause = nil
    fixture.pipeline.flush()
    XCTAssertFalse(fixture.player.isPlaying)
    XCTAssertNil(fixture.pipeline.manager.ballPosition)
    XCTAssertTrue(fixture.pipeline.pose.detectedPose.isEmpty)
    XCTAssertEqual(fixture.frames, 4)
    XCTAssertEqual(fixture.tracks, 0)
    XCTAssertEqual(fixture.cues, 0)
    XCTAssertEqual(fixture.pipeline.manager.diagnostics.released, released + 1)
    fixture.player.setContextActive(true)
    XCTAssertFalse(fixture.player.isPlaying, "Context return cannot override Pause")
    fixture.play()
    try fixture.feed(1...4)
    XCTAssertEqual(fixture.pipeline.manager.diagnostics.preparedRingCount, 4)
    XCTAssertEqual(fixture.cues, 0)
    try fixture.feed(5...9)
    XCTAssertEqual(fixture.cues, 1)
    XCTAssertEqual(fixture.pipeline.windows.last?.last?.sourceTime, CMTime(value: 10297, timescale: 1000))
  }

  func testAcquiredPlaybackFrameCannotCrossPauseAndResume() throws {
    let fixture = try PlaybackFixture()
    fixture.play()
    fixture.output.beforeReturn = {
      fixture.player.pause()
      fixture.play()
    }
    fixture.offer(99)
    fixture.pipeline.flush()
    fixture.output.beforeReturn = nil
    XCTAssertEqual(fixture.frames, 0)
    XCTAssertEqual(fixture.pipeline.manager.diagnostics.admitted, 0)
    try fixture.feed(1...9)
    XCTAssertEqual(fixture.cues, 1)
    XCTAssertEqual(fixture.pipeline.windows.first?.first?.sourceTime, CMTime(value: 10033, timescale: 1000))
  }

  func testCameraContextExitInvalidatesBothHeldStagesAndReturnsStopped() throws {
    for held in [false, true] {
      let fixture = CaptureFixture()
      fixture.start()
      try fixture.feed(1...4)
      fixture.camera.receiveSampleBuffer(try LifecycleFixture.sample(5))
      if held { fixture.pipeline.worker.drain() }
      fixture.camera.setContextActive(false)
      fixture.pipeline.flush()
      XCTAssertEqual(fixture.frames, 4)
      XCTAssertEqual(fixture.tracks, 0)
      XCTAssertEqual(fixture.cues, 0)
      XCTAssertNil(fixture.pipeline.manager.ballPosition)
      XCTAssertTrue(fixture.pipeline.pose.detectedPose.isEmpty)
      fixture.camera.setContextActive(true)
      XCTAssertFalse(fixture.camera.captureRequested)
      fixture.start()
      try fixture.feed(1...9)
      XCTAssertEqual(fixture.cues, 1)
    }
  }

  func testSceneSuspensionClosesBothAdaptersAndReturnDoesNotResume() throws {
    for held in [false, true] {
      let camera = CaptureFixture()
      let playback = try PlaybackFixture()
      camera.start(); playback.play()
      try camera.feed(1...4); try playback.feed(1...4)
      camera.camera.receiveSampleBuffer(try LifecycleFixture.sample(5)); playback.offer(5)
      if held { camera.pipeline.worker.drain(); playback.pipeline.worker.drain() }
      camera.camera.setContextActive(false); playback.player.setContextActive(false)
      camera.pipeline.flush(); playback.pipeline.flush()
      XCTAssertEqual(camera.cues + playback.cues, 0)
      XCTAssertEqual(camera.frames + playback.frames, 8)
      XCTAssertEqual(camera.tracks + playback.tracks, 0)
      XCTAssertTrue(camera.pipeline.pose.detectedPose.isEmpty)
      XCTAssertTrue(playback.pipeline.pose.detectedPose.isEmpty)
      camera.camera.setContextActive(true); playback.player.setContextActive(true)
      XCTAssertFalse(camera.camera.captureRequested)
      XCTAssertFalse(playback.player.isPlaying)
      camera.start(); playback.play()
      try camera.feed(1...9); try playback.feed(1...9)
      XCTAssertEqual(camera.cues + playback.cues, 2)
    }
  }

  func testCurrentModePoseSurvivesRetiredModesDelayedClear_InBothDirections() throws {
    for cameraWasOld in [false, true] {
      let camera = CaptureFixture()
      let playback = try PlaybackFixture()
      camera.start(); playback.play()
      let old = cameraWasOld ? camera.pipeline : playback.pipeline
      let current = cameraWasOld ? playback.pipeline : camera.pipeline
      if cameraWasOld {
        camera.camera.receiveSampleBuffer(try LifecycleFixture.sample(1))
        old.worker.drain()
        camera.camera.setContextActive(false)
        try playback.feed(1...9)
      } else {
        playback.offer(1)
        old.worker.drain()
        playback.player.setContextActive(false)
        try camera.feed(1...9)
      }
      let point = current.pose.detectedPose[.nose]?.location
      let ball = current.manager.ballPosition
      XCTAssertNotNil(point)
      XCTAssertNotNil(ball)
      old.publication.drain()
      XCTAssertTrue(old.pose.detectedPose.isEmpty)
      XCTAssertEqual(current.pose.detectedPose[.nose]?.location, point)
      XCTAssertEqual(current.manager.ballPosition, ball)
      if cameraWasOld { playback.player.pause() } else { camera.camera.stopCapture() }
      current.flush()
      XCTAssertTrue(current.pose.detectedPose.isEmpty)
      XCTAssertNil(current.manager.ballPosition)
    }
  }

  func testReentrantStopAndPauseDuringTrackPublicationSuppressCueAndFrame() throws {
    let camera = CaptureFixture()
    camera.start()
    try camera.feed(1...4)
    camera.pipeline.manager.onBallTrack = { _ in camera.camera.stopCapture() }
    try camera.feed(5...5)
    XCTAssertEqual(camera.frames, 4)
    XCTAssertEqual(camera.cues, 0)
    XCTAssertNil(camera.pipeline.manager.ballPosition)
    camera.pipeline.manager.onBallTrack = nil
    camera.start()
    try camera.feed(1...9)
    XCTAssertEqual(camera.cues, 1)

    let playback = try PlaybackFixture()
    playback.play()
    try playback.feed(1...4)
    playback.pipeline.manager.onBallTrack = { _ in playback.player.pause() }
    try playback.feed(5...5)
    XCTAssertEqual(playback.frames, 4)
    XCTAssertEqual(playback.cues, 0)
    XCTAssertNil(playback.pipeline.manager.ballPosition)
    playback.pipeline.manager.onBallTrack = nil
    playback.play()
    try playback.feed(1...9)
    XCTAssertEqual(playback.cues, 1)
  }

  func testRepeatedPlayOwnsOneLoopAndFreshCueAfterPause() throws {
    let fixture = try PlaybackFixture()
    fixture.play()
    for _ in 0..<100 { fixture.player.play() }
    XCTAssertEqual(fixture.starts, 1)
    try fixture.feed(1...9)
    XCTAssertEqual(fixture.cues, 1)
    for _ in 0..<100 { fixture.player.pause() }
    XCTAssertEqual(fixture.stops, 1)
    fixture.pipeline.flush()
    fixture.player.setContextActive(false)
    fixture.player.play()
    XCTAssertFalse(fixture.player.isPlaying)
    fixture.player.setContextActive(true)
    fixture.play()
    try fixture.feed(1...4)
    XCTAssertEqual(fixture.cues, 1)
    try fixture.feed(5...9)
    XCTAssertEqual(fixture.cues, 2)
    XCTAssertEqual(fixture.starts, 2)
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
    XCTAssertFalse(fixture.camera.captureRequested, "Failed startup retires intent for explicit Retry")
    XCTAssertTrue(fixture.camera.captureState.canRetry)
  }
}

private final class PlaybackFixture {
  let pipeline = LifecyclePipeline()
  let output: LifecycleOutput
  var frames = 0
  var cues = 0
  var tracks = 0
  var starts = 0
  var stops = 0
  var onPause: (() -> Void)?
  lazy var player: VideoPlayerManager = {
    let player = VideoPlayerManager(dependencies: .init(play: { true },
      pause: { [weak self] in self?.onPause?() },
      startLoop: { [weak self] in self?.starts += 1 }, stopLoop: { [weak self] in self?.stops += 1 }))
    player.setupBallDetection(with: pipeline.pose, factory: { [unowned self] _ in pipeline.manager })
    player.onFrameProcessed = { [weak self] in self?.frames += 1 }
    player.onApex = { [weak self] in self?.cues += 1 }
    pipeline.manager.onBallTrack = { [weak self] _ in self?.tracks += 1 }
    return player
  }()
  init() throws { output = try LifecycleOutput() }
  func play() { player.play(); pipeline.flush() }
  func offer(_ index: Int) {
    output.time = CMTime(value: Int64(10000 + index * 33), timescale: 1000)
    player.processPlaybackFrame(output: output, requestedTime: CMTime(value: 900, timescale: 1), orientation: .left)
  }
  func feed(_ range: ClosedRange<Int>) throws {
    for index in range { offer(index); pipeline.flush() }
  }
}

private final class CaptureFixture {
  let session = LifecycleScheduler()
  let video = LifecycleScheduler()
  let pipeline = LifecyclePipeline()
  var events: [String] = []
  var beforeAdmission: (() -> Void)?
  var startSucceeds = true
  var running = false
  var interrupted = false
  var sessionEvent: ((CameraManager.SessionEvent) -> Void)?
  var frames = 0
  var cues = 0
  var tracks = 0
  lazy var camera: CameraManager = {
    let camera = CameraManager(dependencies: .init(session: session.enqueue, drain: video.enqueue,
      state: { $0() }, stop: { [unowned self] in events.append("stop"); running = false },
      attach: { [unowned self] in events.append($0 ? "attach" : "detach") },
      start: { [unowned self] in events.append("start"); running = startSucceeds; return running },
      beforeAdmission: { [unowned self] in beforeAdmission?() },
      snapshot: { [unowned self] in .init(running: running, interrupted: interrupted) },
      observe: { [unowned self] callback in sessionEvent = callback; return {} }))
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
