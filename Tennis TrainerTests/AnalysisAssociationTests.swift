import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class AnalysisAssociationTests: XCTestCase {
  private func run(peak: CGFloat = 0.71, candidate: CGFloat?, later: CGFloat?,
                   mismatch: String? = nil, confidence: Float = 0.9,
                   useNeck: Bool = false, extractionThrows: Bool = false) throws -> Int {
    var records: [AnalysisFrame.Metadata] = []
    var cues = 0
    enum Failure: Error { case pose }
    let poseManager = PoseDetectionManager(transaction: { _, _ in throw Failure.pose })
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, identity, pose in
      let metadata = AnalysisFixture.metadata(identity: identity, pose: pose)
      records.append(metadata)
      if identity.sequence == 2, mismatch != nil || extractionThrows || candidate == nil {
        XCTAssertNil(metadata.pose.baselineY)
        XCTAssertTrue(metadata.pose.joints.isEmpty)
      }
      guard records.count == 5 else { return .init(samples: nil, position: nil) }
      return .init(samples: records.enumerated().map { index, metadata in
        .init(tIndex: index, metadata: metadata, position: CGPoint(x: 0.5,
          y: index == 1 ? peak : 0.5), confidence: 0.9)
      }, position: nil)
    }, extractPose: { input, identity in
      if extractionThrows {
        return poseManager.extractPose(in: input.pixelBuffer, orientation: input.orientation, identity: identity)
      }
      let baseline = identity.sequence == 2 ? candidate : later
      guard let baseline else { return .init(identity: identity, joints: [:]) }
      let isCandidate = identity.sequence == 2
      let wrong = BallDetectionManager.FrameIdentity(
        sourceID: isCandidate && mismatch == "source" ? UUID() : identity.sourceID,
        generation: isCandidate && mismatch == "generation" ? UUID() : identity.generation,
        sequence: isCandidate && mismatch == "frame" ? identity.sequence + 1 : identity.sequence,
        sourceTime: identity.sourceTime)
      return .init(identity: wrong, joints: [useNeck ? .neck : .nose:
        .init(location: CGPoint(x: 0.5, y: baseline), confidence: confidence)])
    }, worker: { $0() }, publication: { $0() }))
    manager.onApex = { cues += 1 }
    let source = UUID()
    let pixels = try AnalysisFixture.pixels(width: 16, height: 16)
    for index in 1...5 {
      XCTAssertTrue(manager.process(input: .init(pixelBuffer: pixels,
        sourceTime: CMTime(value: Int64(10000 + index * 33), timescale: 1000),
        orientation: .up, sourceID: source)))
      if index < 5 { XCTAssertEqual(cues, 0) }
    }
    return cues
  }

  func testCueUsesCandidatePose_WhenLaterNoseIsHigher() throws {
    XCTAssertEqual(try run(candidate: 0.6, later: 0.95), 1)
  }

  func testNoCueUsesCandidatePose_WhenLaterNoseIsLower() throws {
    XCTAssertEqual(try run(candidate: 0.95, later: 0.6), 0)
  }

  func testCueUsesFallback_WhenPoseIdentityMismatchesAboveThreshold() throws {
    for mismatch in ["source", "generation", "frame"] {
      XCTAssertEqual(try run(candidate: 0.95, later: 0.95, mismatch: mismatch), 1, mismatch)
    }
  }

  func testNoCue_WhenPoseIdentityMismatchesAtOrBelowFallback() throws {
    for mismatch in ["source", "generation", "frame"] {
      for peak in [CGFloat(0.69), 0.70] {
        XCTAssertEqual(try run(peak: peak, candidate: 0.1, later: 0.1, mismatch: mismatch), 0, mismatch)
      }
    }
  }

  func testExplicitMissingPose_WhenAbsentFailedOrConfidenceAtBoundary() throws {
    XCTAssertEqual(try run(candidate: nil, later: 0.95), 1)
    XCTAssertEqual(try run(candidate: 0.95, later: 0.95, extractionThrows: true), 1)
    XCTAssertEqual(try run(candidate: 0.95, later: 0.95, confidence: 0.3), 1)
    XCTAssertEqual(try run(peak: 0.65, candidate: 0.55, later: 0.95, useNeck: true), 1)
  }
}
