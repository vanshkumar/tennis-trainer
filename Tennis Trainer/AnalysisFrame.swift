import Foundation
import CoreMedia
import CoreVideo
import CoreGraphics
import ImageIO
import QuartzCore

/// Prepared pixels are allocated once, then only read by the ring and its snapshots.
struct AnalysisFrame {
  struct Mapping: Equatable {
    let sourceWidth: Float
    let sourceHeight: Float
    let scale: Float
    let offsetX: Float
    let offsetY: Float

    var isValid: Bool {
      [sourceWidth, sourceHeight, scale, offsetX, offsetY].allSatisfy(\.isFinite)
        && sourceWidth > 0 && sourceHeight > 0 && scale > 0
    }

    func sourceNormalizedPoint(modelX: Float, modelYFromTop: Float) -> CGPoint? {
      guard isValid, modelX.isFinite, modelYFromTop.isFinite else { return nil }
      let x = (modelX - offsetX) / scale
      let y = (modelYFromTop - offsetY) / scale
      guard x >= 0, x <= sourceWidth, y >= 0, y <= sourceHeight else { return nil }
      return CGPoint(x: CGFloat(x / sourceWidth), y: CGFloat(1 - y / sourceHeight))
    }
  }

  struct Metadata {
    let identity: BallDetectionManager.FrameIdentity
    let sourceTime: CMTime
    let ingressTime: CFTimeInterval
    let rawSize: CGSize
    let orientedSize: CGSize
    let orientation: CGImagePropertyOrientation
    let mapping: Mapping
    let pose: PoseDetectionManager.FramePose

    init(identity: BallDetectionManager.FrameIdentity, sourceTime: CMTime,
         ingressTime: CFTimeInterval, rawSize: CGSize, orientedSize: CGSize,
         orientation: CGImagePropertyOrientation, mapping: Mapping,
         pose: PoseDetectionManager.FramePose) {
      self.identity = identity
      self.sourceTime = sourceTime
      self.ingressTime = ingressTime
      self.rawSize = rawSize
      self.orientedSize = orientedSize
      self.orientation = orientation
      self.mapping = mapping
      // Invalid pose is absence, not invalid frame metadata. Never borrow a later pose.
      self.pose = Self.associatedPose(pose, identity: identity)
    }

    static func associatedPose(_ pose: PoseDetectionManager.FramePose,
                               identity: BallDetectionManager.FrameIdentity) -> PoseDetectionManager.FramePose {
      guard pose.identity == identity else { return .init(identity: identity, joints: [:]) }
      return .init(identity: identity, joints: pose.joints.filter {
        let joint = $0.value
        return joint.confidence.isFinite && joint.confidence > 0.3
          && joint.location.x.isFinite && joint.location.y.isFinite
          && (0...1).contains(joint.location.x) && (0...1).contains(joint.location.y)
      })
    }

    var isValid: Bool {
      let rotates = [.left, .leftMirrored, .right, .rightMirrored].contains(orientation)
      let expected = rotates ? CGSize(width: rawSize.height, height: rawSize.width) : rawSize
      return sourceTime.isValid && sourceTime.isNumeric && CMTimeGetSeconds(sourceTime).isFinite
        && identity.sourceTime.isValid && identity.sourceTime.isNumeric
        && CMTimeCompare(sourceTime, identity.sourceTime) == 0 && identity.sequence > 0
        && ingressTime.isFinite && mapping.isValid
        && [rawSize.width, rawSize.height, orientedSize.width, orientedSize.height].allSatisfy {
          $0.isFinite && $0 > 0
        }
        && orientedSize == expected
        && Float(orientedSize.width) == mapping.sourceWidth
        && Float(orientedSize.height) == mapping.sourceHeight
    }
  }

  struct Window {
    let frames: [AnalysisFrame]

    init?(_ frames: [AnalysisFrame]) {
      guard frames.count == 5, frames.allSatisfy({
        $0.metadata.isValid && CVPixelBufferGetWidth($0.pixels) == 768
          && CVPixelBufferGetHeight($0.pixels) == 432
      }) else { return nil }
      for (a, b) in zip(frames, frames.dropFirst()) {
        let first = a.metadata.identity
        let second = b.metadata.identity
        guard first.sourceID == second.sourceID, first.generation == second.generation,
              first.sequence < second.sequence,
              CMTimeCompare(a.metadata.sourceTime, b.metadata.sourceTime) < 0 else { return nil }
      }
      self.frames = frames
    }
  }

  let pixels: CVPixelBuffer
  let metadata: Metadata

  static func prepare(input: BallDetectionManager.Input, identity: BallDetectionManager.FrameIdentity,
                      pose: PoseDetectionManager.FramePose,
                      ingressTime: CFTimeInterval? = nil) -> AnalysisFrame? {
    guard input.sourceID == identity.sourceID,
          let oriented = PixelBufferScaler.shared.copyApplyingOrientation(input.pixelBuffer,
            orientation: input.orientation) else { return nil }
    let rawSize = CGSize(width: CVPixelBufferGetWidth(input.pixelBuffer),
                         height: CVPixelBufferGetHeight(input.pixelBuffer))
    let w = CGFloat(CVPixelBufferGetWidth(oriented))
    let h = CGFloat(CVPixelBufferGetHeight(oriented))
    let portrait = h > w
    let scale = portrait ? min(768 / w, 432 / h) : max(768 / w, 432 / h)
    let mapping = Mapping(sourceWidth: Float(w), sourceHeight: Float(h), scale: Float(scale),
      offsetX: Float((768 - w * scale) / 2), offsetY: Float((432 - h * scale) / 2))
    let metadata = Metadata(identity: identity, sourceTime: input.sourceTime,
      ingressTime: ingressTime ?? input.ingressTime,
      rawSize: rawSize, orientedSize: CGSize(width: w, height: h), orientation: input.orientation,
      mapping: mapping, pose: pose)
    guard metadata.isValid else { return nil }
    // The scaler allocates even at unit scale: .up/exact-size input must not alias capture memory.
    let prepared = portrait
      ? PixelBufferScaler.shared.resizeAspectFit(oriented, width: 768, height: 432)
      : PixelBufferScaler.shared.resizeAspectFill(oriented, width: 768, height: 432)
    guard let prepared else { return nil }
    return AnalysisFrame(pixels: prepared, metadata: metadata)
  }
}
