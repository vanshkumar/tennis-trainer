import XCTest
import Vision
@testable import Tennis_Trainer

final class BackhandCueManagerTests: XCTestCase {
  private let source = UUID()
  private let generation = UUID()

  private func frame(_ x: CGFloat, angle: Double = 145, sequence: Int = 1,
                     size: CGSize = CGSize(width: 600, height: 1000),
                     missingWrist: Bool = false) -> PoseDetectionManager.FrameObservation {
    let hand = CGPoint(x: x, y: -0.2)
    let shoulders = [CGPoint(x: -0.05, y: 0), CGPoint(x: 0.05, y: 0)]
    let wrists = [CGPoint(x: hand.x - 0.01, y: hand.y), CGPoint(x: hand.x + 0.01, y: hand.y)]
    let names: [[VNHumanBodyPoseObservation.JointName]] = [
      [.leftShoulder, .leftElbow, .leftWrist], [.rightShoulder, .rightElbow, .rightWrist]
    ]
    var joints: [VNHumanBodyPoseObservation.JointName: PoseDetectionManager.Joint] = [:]
    for index in 0..<2 {
      let shoulder = shoulders[index], wrist = wrists[index]
      let dx = wrist.x - shoulder.x, dy = wrist.y - shoulder.y
      let height = 0.5 / tan(angle * .pi / 360)
      let elbow = CGPoint(x: (shoulder.x + wrist.x) / 2 + dy * height,
                          y: (shoulder.y + wrist.y) / 2 - dx * height)
      for (name, point) in zip(names[index], [shoulder, elbow, wrist]) {
        joints[name] = .init(location: CGPoint(x: (point.x + 0.3) / (size.width / size.height),
                                               y: point.y + 0.65), confidence: 0.95)
      }
    }
    if missingWrist { joints.removeValue(forKey: .leftWrist) }
    let identity = BallDetectionManager.FrameIdentity(sourceID: source, generation: generation,
      sequence: UInt64(sequence), sourceTime: CMTime(value: Int64(sequence), timescale: 30))
    return .init(pose: .init(identity: identity, joints: joints), orientedSize: size, ingressTime: 100)
  }

  private func calibrated() -> BackhandCueManager {
    let manager = BackhandCueManager()
    manager.capture(.ready, from: frame(0, angle: 100))
    manager.capture(.checkpoint, from: frame(0.23))
    XCTAssertNotNil(manager.calibration)
    return manager
  }

  private func swing(_ manager: BackhandCueManager, start: Int = 1, angle: Double = 145) {
    for (index, x) in [0.0, 0, -0.1, -0.12, -0.04, 0.08, 0.20, 0.23, 0.25].enumerated() {
      manager.consume(frame(x, angle: angle, sequence: start + index), now: 100)
    }
  }

  func testOneCueAndRearm_WhenHandsTravelThroughCalibratedCheckpoint() {
    let manager = calibrated()
    var sounds = 0
    manager.onCue = { sounds += 1 }
    swing(manager)
    XCTAssertEqual(manager.status, .reached)
    XCTAssertEqual(manager.cueCount, 1)
    for sequence in 10...15 { manager.consume(frame(0.23, sequence: sequence), now: 100) }
    XCTAssertEqual(sounds, 1)
    swing(manager, start: 16)
    XCTAssertEqual(sounds, 2)
    XCTAssertEqual(manager.cueCount, 2)
  }

  func testNoCue_WhenExtensionHeldWithoutBackswingOrForwardTravel() {
    let manager = calibrated()
    for sequence in 1...10 { manager.consume(frame(0.23, sequence: sequence), now: 100) }
    XCTAssertEqual(manager.cueCount, 0)
    for sequence in 11...20 { manager.consume(frame(0, sequence: sequence), now: 100) }
    XCTAssertEqual(manager.cueCount, 0)
  }

  func testNoCue_WhenTopArmDoesNotMatchReference() {
    let manager = calibrated()
    swing(manager, angle: 100)
    XCTAssertEqual(manager.cueCount, 0)
    // Straightening only after the hands have stopped must not earn a late marker.
    for sequence in 10...17 { manager.consume(frame(0.25, angle: 100, sequence: sequence), now: 100) }
    for sequence in 18...23 { manager.consume(frame(0.25, sequence: sequence), now: 100) }
    XCTAssertEqual(manager.cueCount, 0)
  }

  func testAttemptRetired_WhenTrackingMissingGapOrExplicitReset() {
    for interruption in ["missing", "gap", "reset", "late"] {
      let manager = calibrated()
      for (index, x) in [0.0, 0, -0.1, -0.12, -0.04, 0.08].enumerated() {
        manager.consume(frame(x, sequence: index + 1), now: 100)
      }
      switch interruption {
      case "missing": manager.consume(frame(0.20, sequence: 7, missingWrist: true), now: 100)
      case "gap": manager.consume(frame(0.20, sequence: 40), now: 100)
      case "late": manager.consume(frame(0.20, sequence: 7), now: 100.5)
      default: manager.resetAttempt()
      }
      for sequence in 41...44 { manager.consume(frame(0.23, sequence: sequence), now: 100) }
      XCTAssertEqual(manager.cueCount, 0, interruption)
      XCTAssertNotNil(manager.calibration, interruption)
    }
  }

  func testCorrectedGeometry_WhenImageAspectRatioChanges() throws {
    let portrait = try XCTUnwrap(BackhandCueManager.Sample(frame(0.23)))
    let landscape = try XCTUnwrap(BackhandCueManager.Sample(frame(0.23,
      size: CGSize(width: 1000, height: 600))))
    XCTAssertEqual(portrait.elbowAngle, 145, accuracy: 0.001)
    XCTAssertEqual(portrait.elbowAngle, landscape.elbowAngle, accuracy: 0.001)
    XCTAssertEqual(portrait.hand.x, landscape.hand.x, accuracy: 0.001)
  }

  func testCalibrationRejected_WhenCheckpointsTooSimilar() {
    let manager = BackhandCueManager()
    manager.capture(.ready, from: frame(0))
    manager.capture(.checkpoint, from: frame(0.01))
    XCTAssertNil(manager.calibration)
    XCTAssertNotNil(manager.message)
  }

  func testCountsWithoutSound_AndSuppressesDuringCalibration() {
    let manager = calibrated()
    var sounds = 0
    manager.onCue = { sounds += 1 }
    manager.soundEnabled = false
    swing(manager)
    XCTAssertEqual(manager.cueCount, 1)
    XCTAssertEqual(sounds, 0)
    manager.isCalibrating = true
    swing(manager, start: 10)
    XCTAssertEqual(manager.cueCount, 1)
  }

  func testNewSourceClearsCalibration_AndRepeatedFrameCannotConfirmCrossing() {
    let manager = calibrated()
    for (index, x) in [0.0, 0, -0.1, -0.12, -0.04, 0.08, 0.20].enumerated() {
      manager.consume(frame(x, sequence: index + 1), now: 100)
    }
    manager.consume(frame(0.20, sequence: 7), now: 100)
    XCTAssertEqual(manager.cueCount, 0)
    let original = frame(0, sequence: 8)
    let changed = PoseDetectionManager.FramePose(identity: .init(sourceID: UUID(), generation: generation,
      sequence: 8, sourceTime: original.pose.identity.sourceTime), joints: original.pose.joints)
    manager.consume(.init(pose: changed, orientedSize: original.orientedSize, ingressTime: 100), now: 100)
    XCTAssertNil(manager.calibration)
    XCTAssertNil(manager.readyReference)
  }
}
