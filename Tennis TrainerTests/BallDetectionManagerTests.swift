import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class BallDetectionManagerTests: XCTestCase {
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
