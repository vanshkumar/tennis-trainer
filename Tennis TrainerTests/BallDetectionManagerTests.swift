import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class BallDetectionManagerTests: XCTestCase {
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
    var effects = 0
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _ in
      calls += 1
      return .init(samples: nil, position: CGPoint(x: 0.5, y: 0.5))
    }, worker: worker.enqueue, publication: publication.enqueue))
    manager.onFrameProcessed = { effects += 1 }
    let buffer = try pixels()
    let source = UUID()
    XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)))
    for i in 1...1000 { XCTAssertFalse(manager.process(input: input(buffer, Int64(i), source: source))) }
    XCTAssertEqual(worker.jobs.count, 1)
    XCTAssertEqual(calls, 0)
    worker.run()
    for i in 1001...2000 { XCTAssertFalse(manager.process(input: input(buffer, Int64(i), source: source))) }
    XCTAssertEqual(calls, 1)
    XCTAssertEqual(publication.jobs.count, 1)
    XCTAssertEqual(effects, 0)
    publication.run()
    XCTAssertEqual(effects, 1)
    XCTAssertTrue(manager.process(input: input(buffer, 2001, source: source)))
  }

  func testClearsValues_WhenResetWhileIdle() throws {
    let publication = Scheduler()
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _ in
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
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _ in
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
    BallDetectionManager(dependencies: .init(analyze: { input, _ in
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
  }
}
