import XCTest
import Vision
@testable import Tennis_Trainer

final class PoseDetectionManagerTests: XCTestCase {
  private func pixels() throws -> CVPixelBuffer {
    var result: CVPixelBuffer?
    XCTAssertEqual(CVPixelBufferCreate(nil, 16, 16, kCVPixelFormatType_32BGRA, nil, &result), 0)
    return try XCTUnwrap(result)
  }

  private func identity(_ sequence: UInt64 = 1) -> BallDetectionManager.FrameIdentity {
    .init(sourceID: UUID(), generation: UUID(), sequence: sequence,
          sourceTime: CMTime(value: Int64(sequence), timescale: 30))
  }

  func testSameImageAndIdentity_WhenPoseExtracted() throws {
    let buffer = try pixels()
    let id = identity()
    var calls = 0
    let manager = PoseDetectionManager(transaction: { received, orientation in
      XCTAssertTrue(received === buffer)
      XCTAssertEqual(orientation, .left)
      calls += 1
      return [.nose: .init(location: CGPoint(x: 0.3, y: 0.8), confidence: 0.9)]
    })
    let pose = manager.extractPose(in: buffer, orientation: .left, identity: id)
    XCTAssertEqual(pose.identity, id)
    XCTAssertEqual(pose.baselineY, 0.8)
    XCTAssertEqual(calls, 1)
    XCTAssertTrue(manager.detectedPose.isEmpty)
    manager.publish(pose)
    XCTAssertEqual(manager.getJointPosition(for: .nose)?.y, 0.8)
  }

  func testMissingPose_WhenAbsentErrorOrLowConfidenceFollowsValidPose() throws {
    enum Failure: Error { case request }
    let buffer = try pixels()
    for mode in 0..<3 {
      var calls = 0
      let manager = PoseDetectionManager(transaction: { _, _ in
        calls += 1
        if calls == 1 { return [.nose: .init(location: CGPoint(x: 0.5, y: 0.8), confidence: 0.9)] }
        if mode == 1 { throw Failure.request }
        if mode == 2 { return [.nose: .init(location: CGPoint(x: 0.5, y: 0.8), confidence: 0.3)] }
        return [:]
      })
      manager.publish(manager.extractPose(in: buffer, orientation: .up, identity: identity()))
      XCTAssertNotNil(manager.serveTossApexGateBaselineY)
      let missing = manager.extractPose(in: buffer, orientation: .up, identity: identity(2))
      XCTAssertNil(missing.baselineY)
      XCTAssertTrue(missing.joints.isEmpty)
      manager.publish(missing)
      XCTAssertTrue(manager.detectedPose.isEmpty)
      XCTAssertEqual(manager.forearmAngle, 0)
      XCTAssertEqual(manager.upperArmAngle, 0)
    }
  }

  func testNoseThenNeck_WhenConfidenceStrictlyExceedsThreshold() throws {
    let buffer = try pixels()
    let manager = PoseDetectionManager(transaction: { _, _ in
      [.nose: .init(location: CGPoint(x: 0.5, y: 0.9), confidence: 0.3),
       .neck: .init(location: CGPoint(x: 0.5, y: 0.6), confidence: 0.31)]
    })
    XCTAssertEqual(manager.extractPose(in: buffer, orientation: .up, identity: identity()).baselineY, 0.6)
  }

  func testSharedRequestSerialized_WhenConcurrentCallersExtractPose() throws {
    let buffer = try pixels()
    let observations = NSLock()
    var active = 0
    var maximum = 0
    var calls = 0
    let pose = PoseDetectionManager(transaction: { _, _ in
      observations.lock()
      active += 1
      maximum = max(maximum, active)
      calls += 1
      observations.unlock()
      defer { observations.lock(); active -= 1; observations.unlock() }
      return [.nose: .init(location: CGPoint(x: 0.5, y: 0.8), confidence: 0.9)]
    })
    DispatchQueue.concurrentPerform(iterations: 100) { i in
      _ = pose.extractPose(in: buffer, orientation: .up, identity: self.identity(UInt64(i)))
    }
    XCTAssertEqual(maximum, 1)
    XCTAssertEqual(calls, 100)
  }
}
