import Combine
import CoreGraphics
import CoreMedia
import QuartzCore
import Vision

/// Experimental C3 marker. Measures projected movement, never ball contact.
/// Owned by the main executor, independently for live camera and video.
final class BackhandCueManager: ObservableObject {
  enum Reference { case ready, checkpoint }
  enum Status: String {
    case needsSetup = "Needs setup"
    case waiting = "Return to ready"
    case ready = "Ready"
    case backswing = "Backswing"
    case swinging = "Swinging"
    case reached = "Checkpoint reached"
    case lost = "Tracking lost"
  }

  struct Sample {
    let points: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let hand: CGPoint
    let elbowAngle: Double
    let armLength: CGFloat

    init?(_ observation: PoseDetectionManager.FrameObservation) {
      let size = observation.orientedSize
      guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return nil }
      let names: [VNHumanBodyPoseObservation.JointName] = [
        .leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist
      ]
      var points: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
      for name in names {
        guard let joint = observation.pose.joints[name], joint.confidence.isFinite,
              joint.confidence >= 0.5, joint.location.x.isFinite, joint.location.y.isFinite,
              (0...1).contains(joint.location.x), (0...1).contains(joint.location.y) else { return nil }
        // Equal-scale image units; distances are fractions of oriented image height.
        points[name] = CGPoint(x: joint.location.x * size.width / size.height, y: joint.location.y)
      }
      let shoulder = points[.leftShoulder]!, elbow = points[.leftElbow]!, wrist = points[.leftWrist]!
      let upper = Self.distance(shoulder, elbow), lower = Self.distance(elbow, wrist)
      guard upper > 0.015, lower > 0.015 else { return nil }
      let cosine = ((shoulder.x - elbow.x) * (wrist.x - elbow.x)
        + (shoulder.y - elbow.y) * (wrist.y - elbow.y)) / (upper * lower)
      elbowAngle = acos(Double(min(1, max(-1, cosine)))) * 180 / .pi
      armLength = upper + lower
      // Both hands should be together on the handle in this two-handed drill.
      guard Self.distance(wrist, points[.rightWrist]!) < armLength * 0.45 else { return nil }
      let center = CGPoint(x: (shoulder.x + points[.rightShoulder]!.x) / 2,
                           y: (shoulder.y + points[.rightShoulder]!.y) / 2)
      self.points = points.mapValues { CGPoint(x: $0.x - center.x, y: $0.y - center.y) }
      hand = CGPoint(x: (wrist.x + points[.rightWrist]!.x) / 2 - center.x,
                     y: (wrist.y + points[.rightWrist]!.y) / 2 - center.y)
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
  }

  struct Calibration {
    let ready: Sample
    let checkpoint: Sample
    let direction: CGPoint
    let distance: CGFloat
    let sourceID: UUID
    let aspectRatio: CGFloat

    func progress(_ sample: Sample) -> CGFloat {
      (sample.hand.x - ready.hand.x) * direction.x + (sample.hand.y - ready.hand.y) * direction.y
    }

    func sideways(_ sample: Sample) -> CGFloat {
      abs((sample.hand.x - ready.hand.x) * direction.y - (sample.hand.y - ready.hand.y) * direction.x)
    }
  }

  @Published private(set) var status: Status = .needsSetup
  @Published private(set) var currentSample: Sample?
  @Published private(set) var readyReference: Sample?
  @Published private(set) var calibration: Calibration?
  @Published private(set) var cueCount = 0
  @Published var soundEnabled = true
  var isCalibrating = false
  @Published private(set) var message: String?
  var onCue: (() -> Void)?

  private var latestObservation: PoseDetectionManager.FrameObservation?
  private var referenceSource: UUID?
  private var referenceAspect: CGFloat?
  private var lastIdentity: BallDetectionManager.FrameIdentity?
  private var previousProgress: CGFloat?
  private var readyFrames = 0
  private var checkpointFrames = 0
  private var phaseStart: Double?
  private var lastForwardTime: Double?
  private var minimumProgress: CGFloat = 0

  func setMessage(_ text: String) { message = text }

  func captureLiveReference(_ reference: Reference) {
    guard let observation = latestObservation,
          CACurrentMediaTime() - observation.ingressTime < 0.35 else {
      message = "No recent pose. Start the camera and keep both arms visible."
      return
    }
    capture(reference, from: observation)
  }

  func capture(_ reference: Reference, from observation: PoseDetectionManager.FrameObservation) {
    guard let sample = Sample(observation) else {
      message = "Keep both shoulders, elbows and hands visible, with hands together. Try another view or frame."
      return
    }
    let source = observation.pose.identity.sourceID
    let aspect = observation.orientedSize.width / observation.orientedSize.height
    switch reference {
    case .ready:
      calibration = nil
      readyReference = sample
      referenceSource = source
      referenceAspect = aspect
      cueCount = 0
      message = "Ready saved. Now capture your comfortable through-swing checkpoint. A bent top arm is fine."
    case .checkpoint:
      guard let ready = readyReference, referenceSource == source,
            let referenceAspect, abs(referenceAspect - aspect) < 0.01 else {
        message = "Capture ready first, using the same camera setup or video."
        return
      }
      let distance = Sample.distance(ready.hand, sample.hand)
      guard distance >= ready.armLength * 0.2 else {
        message = "These positions look too similar. Use a side-oblique view and a checkpoint farther through your swing."
        return
      }
      calibration = Calibration(ready: ready, checkpoint: sample,
        direction: CGPoint(x: (sample.hand.x - ready.hand.x) / distance,
                           y: (sample.hand.y - ready.hand.y) / distance),
        distance: distance, sourceID: source, aspectRatio: aspect)
      message = "Setup saved. Return to ready, take the hands back, then swing through."
    }
    resetAttempt()
    currentSample = sample
  }

  func clearCalibration() {
    calibration = nil
    readyReference = nil
    referenceSource = nil
    referenceAspect = nil
    cueCount = 0
    message = nil
    resetAttempt()
  }

  func resetAttempt() {
    latestObservation = nil
    lastIdentity = nil
    currentSample = nil
    previousProgress = nil
    phaseStart = nil
    lastForwardTime = nil
    readyFrames = 0
    checkpointFrames = 0
    minimumProgress = 0
    status = calibration == nil ? .needsSetup : .waiting
  }

  func consume(_ observation: PoseDetectionManager.FrameObservation,
               now: CFTimeInterval = CACurrentMediaTime()) {
    let identity = observation.pose.identity
    let time = CMTimeGetSeconds(identity.sourceTime)
    guard identity.sourceTime.isValid, identity.sourceTime.isNumeric, time.isFinite else { return }
    if let referenceSource, referenceSource != identity.sourceID { clearCalibration() }
    if let aspect = referenceAspect,
       abs(aspect - observation.orientedSize.width / observation.orientedSize.height) >= 0.01 {
      clearCalibration()
      message = "Image framing changed. Calibrate this view again."
    }
    if let last = lastIdentity {
      if last.sourceID != identity.sourceID || last.generation != identity.generation {
        resetAttempt()
      } else {
        guard CMTimeCompare(identity.sourceTime, last.sourceTime) > 0 else { return }
        if time - CMTimeGetSeconds(last.sourceTime) > 0.25 { resetAttempt() }
      }
    }
    lastIdentity = identity
    guard now - observation.ingressTime <= 0.25, let sample = Sample(observation) else {
      resetAttempt()
      lastIdentity = identity
      status = .lost
      return
    }
    latestObservation = observation
    currentSample = sample
    guard let calibration, !isCalibrating else { status = .needsSetup; return }
    let scale = calibration.ready.armLength // Fixed scale, not a turning shoulder width.
    let progress = calibration.progress(sample)
    let delta = previousProgress.map { progress - $0 } ?? 0
    previousProgress = progress
    if delta > scale * 0.01 { lastForwardTime = time }
    let atReady = Sample.distance(sample.hand, calibration.ready.hand) < scale * 0.22
    readyFrames = atReady ? readyFrames + 1 : 0

    if let phaseStart, time - phaseStart > 4 {
      status = .waiting
      self.phaseStart = nil
      checkpointFrames = 0
    }
    switch status {
    case .needsSetup, .waiting, .lost, .reached:
      if readyFrames >= 2 {
        status = .ready
        minimumProgress = progress
        phaseStart = nil
        checkpointFrames = 0
      }
    case .ready:
      if progress < -scale * 0.12 {
        status = .backswing
        minimumProgress = progress
        phaseStart = time
      }
    case .backswing:
      minimumProgress = min(minimumProgress, progress)
      if progress - minimumProgress > scale * 0.12, delta > 0 {
        status = .swinging
      }
    case .swinging:
      // Tolerances surround the player's reference; they are not ideal joint angles.
      let inCorridor = calibration.sideways(sample) < max(scale * 0.25, calibration.distance * 0.3)
      let atCheckpoint = progress >= calibration.distance - scale * 0.12
        && progress <= calibration.distance + scale * 0.4
        && abs(sample.elbowAngle - calibration.checkpoint.elbowAngle) <= 12
        && inCorridor && delta >= -scale * 0.03
        && (lastForwardTime.map { time - $0 <= 0.12 } ?? false)
      checkpointFrames = atCheckpoint ? checkpointFrames + 1 : 0
      if checkpointFrames >= 2 {
        status = .reached
        cueCount += 1
        phaseStart = nil
        if soundEnabled { onCue?() }
      } else if readyFrames >= 3, delta < 0 {
        status = .ready
        phaseStart = nil
      }
    }
  }
}
