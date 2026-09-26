import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class PracticeLifecycleTests: XCTestCase {
  func testStopInvalidatesHeldPublication_BeforePhysicalTeardown() throws {
    let publication = LifecycleScheduler()
    let pose = PoseDetectionManager()
    let camera = CameraManager()
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
      .init(samples: nil, position: CGPoint(x: 0.5, y: 0.8))
    }, publishPose: pose.publish, worker: { $0() }, publication: publication.enqueue))
    camera.setupBallDetection(with: pose, factory: { _ in manager })
    var frames = 0
    camera.onFrameProcessed = { frames += 1 }
    camera.startCapture()
    camera.submitSampleBuffer(try LifecycleFixture.sample(1))
    camera.stopCapture()
    publication.drain()
    XCTAssertNil(manager.ballPosition, "Stop must invalidate already admitted publication")
    XCTAssertEqual(frames, 0, "Stop must suppress old frame effects")
    XCTAssertEqual(manager.diagnostics.released, 1)
  }
}

private final class LifecycleScheduler {
  var jobs: [() -> Void] = []
  func enqueue(_ job: @escaping () -> Void) { jobs.append(job) }
  func run() { if !jobs.isEmpty { jobs.removeFirst()() } }
  func drain() { while !jobs.isEmpty { run() } }
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
