import Foundation
import Vision
import AVFoundation

final class PoseDetectionManager: ObservableObject {
  struct Joint {
    let location: CGPoint
    let confidence: Float
  }

  struct FramePose {
    let identity: BallDetectionManager.FrameIdentity
    let joints: [VNHumanBodyPoseObservation.JointName: Joint]
    var baselineY: CGFloat? {
      if let nose = joints[.nose], nose.confidence > 0.3 { return nose.location.y }
      if let neck = joints[.neck], neck.confidence > 0.3 { return neck.location.y }
      return nil
    }
  }

  typealias Transaction = (CVPixelBuffer, CGImagePropertyOrientation) throws
    -> [VNHumanBodyPoseObservation.JointName: Joint]

  @Published var detectedPose: [VNHumanBodyPoseObservation.JointName: Joint] = [:]
  @Published var forearmAngle: Double = 0
  @Published var upperArmAngle: Double = 0
  private let requestLock = NSLock()
  private let transaction: Transaction

  init(transaction: @escaping Transaction) {
    self.transaction = transaction
  }

  convenience init() {
    let request = VNDetectHumanBodyPoseRequest()
    request.revision = VNDetectHumanBodyPoseRequestRevision1
    self.init(transaction: { pixels, orientation in
      let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: orientation, options: [:])
      try handler.perform([request])
      guard let observation = request.results?.first else { return [:] }
      let names: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .neck, .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow, .leftWrist, .rightWrist
      ]
      var joints: [VNHumanBodyPoseObservation.JointName: Joint] = [:]
      for name in names {
        if let point = try? observation.recognizedPoint(name) {
          joints[name] = Joint(location: point.location, confidence: point.confidence)
        }
      }
      return joints
    })
  }

  func extractPose(in pixels: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                   identity: BallDetectionManager.FrameIdentity) -> FramePose {
    // One shared request requires serialization across perform AND extraction.
    requestLock.lock()
    defer { requestLock.unlock() }
    do {
      let joints = try transaction(pixels, orientation).filter {
        $0.value.confidence > 0.3 && $0.value.confidence.isFinite
          && $0.value.location.x.isFinite && $0.value.location.y.isFinite
      }
      return FramePose(identity: identity, joints: joints)
    } catch {
      print("Pose detection error: \(error)")
      return FramePose(identity: identity, joints: [:])
    }
  }

  func publish(_ pose: FramePose) {
    detectedPose = pose.joints
    guard let shoulder = detectedPose[.rightShoulder],
          let elbow = detectedPose[.rightElbow], let wrist = detectedPose[.rightWrist] else {
      forearmAngle = 0
      upperArmAngle = 0
      return
    }
    upperArmAngle = angle(from: shoulder.location, to: elbow.location)
    forearmAngle = angle(from: elbow.location, to: wrist.location)
  }

  private func angle(from start: CGPoint, to end: CGPoint) -> Double {
    let degrees = atan2(end.y - start.y, end.x - start.x) * 180 / .pi
    return degrees < 0 ? degrees + 360 : degrees
  }

  func getJointPosition(for name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
    detectedPose[name]?.location
  }

  func getJointConfidence(for name: VNHumanBodyPoseObservation.JointName) -> Float? {
    detectedPose[name]?.confidence
  }
}

extension PoseDetectionManager: ServeTossApexHeightGateProviding {
  var serveTossApexGateBaselineY: CGFloat? {
    if let nose = detectedPose[.nose], nose.confidence > 0.3 { return nose.location.y }
    if let neck = detectedPose[.neck], neck.confidence > 0.3 { return neck.location.y }
    return nil
  }
}
