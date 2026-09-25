import XCTest
import CoreGraphics
import Vision
@testable import Tennis_Trainer

final class ServeTossApexDetectorTests: XCTestCase {
    private func associatedSample(_ index: UInt64, y: CGFloat, baseline: CGFloat?,
                                  mismatch: String? = nil, confidence: Float = 0.9,
                                  neck: CGFloat? = nil) -> GridTrackNetDetector.Sample {
        let id = AnalysisFixture.identity(index)
        let poseID = BallDetectionManager.FrameIdentity(
            sourceID: mismatch == "source" ? UUID() : id.sourceID,
            generation: mismatch == "generation" ? UUID() : id.generation,
            sequence: mismatch == "frame" ? id.sequence + 1 : id.sequence, sourceTime: id.sourceTime)
        var joints: [VNHumanBodyPoseObservation.JointName: PoseDetectionManager.Joint] = [:]
        if let baseline { joints[.nose] = .init(location: CGPoint(x: 0.5, y: baseline), confidence: confidence) }
        if let neck { joints[.neck] = .init(location: CGPoint(x: 0.5, y: neck), confidence: 0.9) }
        return .init(tIndex: 0, metadata: AnalysisFixture.metadata(identity: id,
            pose: .init(identity: poseID, joints: joints)), position: CGPoint(x: 0.5, y: y), confidence: 0.9)
    }

    func testCueUsesCandidatePose_WhenLaterNoseIsHigher() {
        let samples = [associatedSample(1, y: 0.5, baseline: 0.6),
                       associatedSample(2, y: 0.71, baseline: 0.6),
                       associatedSample(3, y: 0.5, baseline: 0.95)]
        XCTAssertTrue(ServeTossApexDetector().consume(samples: samples))
    }

    func testNoCueUsesCandidatePose_WhenLaterNoseIsLower() {
        let samples = [associatedSample(1, y: 0.5, baseline: 0.95),
                       associatedSample(2, y: 0.71, baseline: 0.95),
                       associatedSample(3, y: 0.5, baseline: 0.6)]
        XCTAssertFalse(ServeTossApexDetector().consume(samples: samples))
    }

    func testCueUsesFallback_WhenPoseIdentityMismatchesAboveThreshold() {
        for mismatch in ["source", "generation", "frame"] {
            let candidate = associatedSample(2, y: 0.71, baseline: 0.95, mismatch: mismatch)
            XCTAssertTrue(candidate.metadata.pose.joints.isEmpty)
            XCTAssertTrue(candidate.metadata.isValid)
            XCTAssertTrue(ServeTossApexDetector().consume(samples: [
                associatedSample(1, y: 0.5, baseline: 0.95), candidate,
                associatedSample(3, y: 0.5, baseline: 0.95)]))
        }
    }

    func testNosePrecedesNeck_AndInvalidNoseUsesNeckOrFallback() {
        let cases: [(CGFloat?, Float, CGFloat?, CGFloat, Bool)] = [
            (0.95, 0.9, 0.1, 0.71, false),
            (nil, 0.9, 0.55, 0.65, true),
            (0.95, 0.3, 0.55, 0.65, true),
            (0.95, 0.3, nil, 0.71, true),
            (.nan, 0.9, nil, 0.71, true),
            (0.95, .infinity, nil, 0.71, true),
            (nil, 0.9, nil, 0.70, false),
            (0.6, 0.9, nil, 0.65, false)
        ]
        for (nose, confidence, neck, peak, expected) in cases {
            let samples = [associatedSample(1, y: 0.5, baseline: 0.1),
                associatedSample(2, y: peak, baseline: nose, confidence: confidence, neck: neck),
                associatedSample(3, y: 0.5, baseline: 0.1)]
            XCTAssertEqual(ServeTossApexDetector().consume(samples: samples), expected)
        }
    }

    func testMissingCandidateNeverInheritsPose_AndDelayedPoseCannotReviseCandidate() {
        let detector = ServeTossApexDetector()
        XCTAssertFalse(detector.consume(samples: [associatedSample(1, y: 0.5, baseline: 0.1),
            associatedSample(2, y: 0.65, baseline: nil)]))
        XCTAssertFalse(detector.consume(samples: [associatedSample(2, y: 0.65, baseline: 0.1),
            associatedSample(3, y: 0.5, baseline: 0.1)]))
    }

    func testNoCue_WhenPoseIdentityMismatchesAtOrBelowFallback() {
        for mismatch in ["source", "generation", "frame"] {
            for peak in [CGFloat(0.69), 0.70] {
                let candidate = associatedSample(2, y: peak, baseline: 0.1, mismatch: mismatch)
                XCTAssertTrue(candidate.metadata.pose.joints.isEmpty)
                XCTAssertTrue(candidate.metadata.isValid)
                XCTAssertFalse(ServeTossApexDetector().consume(samples: [
                    associatedSample(1, y: 0.5, baseline: 0.1), candidate,
                    associatedSample(3, y: 0.5, baseline: 0.1)]))
            }
        }
    }

    private func sample(t: CFTimeInterval, y: CGFloat, conf: Float = 0.9) -> GridTrackNetDetector.Sample {
        GridTrackNetDetector.Sample(
            tIndex: 0,
            metadata: AnalysisFixture.metadata(time: t),
            position: CGPoint(x: 0.5, y: y),
            confidence: conf
        )
    }

    private func runDetector(
        samples: [GridTrackNetDetector.Sample],
        batchSize: Int = 5,
        baseline: CGFloat? = nil
    ) -> [Int] {
        let detector = ServeTossApexDetector()
        var firingBatchIndices: [Int] = []
        var batchIndex = 0

        for start in stride(from: 0, to: samples.count, by: batchSize) {
            let end = min(start + batchSize, samples.count)
            let batch = samples[start..<end].map { sample in
                guard let baseline else { return sample }
                let identity = sample.metadata.identity
                return GridTrackNetDetector.Sample(tIndex: sample.tIndex,
                    metadata: AnalysisFixture.metadata(identity: identity, pose: .init(identity: identity,
                        joints: [.nose: .init(location: CGPoint(x: 0.5, y: baseline), confidence: 0.9)])),
                    position: sample.position, confidence: sample.confidence)
            }
            if detector.consume(samples: batch) {
                firingBatchIndices.append(batchIndex)
            }
            batchIndex += 1
        }

        return firingBatchIndices
    }

    func testSingleParabolicTossAboveFallbackGateFiresExactlyOnce() {
        let samples = (0..<30).map { i in
            let y = 0.5 + 0.4 * sin(.pi * Double(i) / 30.0)
            return sample(t: Double(i) * 0.033, y: y)
        }

        let firings = runDetector(samples: samples)

        XCTAssertEqual(firings, [3])
    }

    func testTwoTossesSeparatedByCooldownFireTwice() {
        let first = (0..<30).map { i in
            let y = 0.5 + 0.4 * sin(.pi * Double(i) / 30.0)
            return sample(t: Double(i) * 0.033, y: y)
        }
        let second = (0..<30).map { i in
            let y = 0.5 + 0.4 * sin(.pi * Double(i) / 30.0)
            return sample(t: 5.0 + Double(i) * 0.033, y: y)
        }

        let firings = runDetector(samples: first + second)

        XCTAssertEqual(firings.count, 2)
    }

    func testTwoTossesInsideCooldownFireOnce() {
        let first = (0..<30).map { i in
            let y = 0.5 + 0.4 * sin(.pi * Double(i) / 30.0)
            return sample(t: Double(i) * 0.033, y: y)
        }
        let second = (0..<30).map { i in
            let y = 0.5 + 0.4 * sin(.pi * Double(i) / 30.0)
            return sample(t: 2.0 + Double(i) * 0.033, y: y)
        }

        let firings = runDetector(samples: first + second)

        XCTAssertEqual(firings.count, 1)
    }

    func testPeakBelowHeightGateDoesNotFire() {
        let samples = (0..<30).map { i in
            let y = 0.35 + 0.30 * sin(.pi * Double(i) / 30.0)
            return sample(t: Double(i) * 0.033, y: y)
        }

        let firings = runDetector(samples: samples)

        XCTAssertTrue(firings.isEmpty)
    }

    func testPoseRelativeGateSuppressesApexBelowNoseHeight() {
        let samples = (0..<30).map { i in
            let y = 0.45 + 0.40 * sin(.pi * Double(i) / 30.0)
            return sample(t: Double(i) * 0.033, y: y)
        }

        let firings = runDetector(
            samples: samples,
            baseline: 0.95
        )

        XCTAssertTrue(firings.isEmpty)
    }

    func testLowConfidenceSamplesAroundPeakSuppressApex() {
        let samples = (0..<30).map { i in
            let y = 0.5 + 0.4 * sin(.pi * Double(i) / 30.0)
            let conf: Float = (14...16).contains(i) ? 0.3 : 0.9
            return sample(t: Double(i) * 0.033, y: y, conf: conf)
        }

        let firings = runDetector(samples: samples)

        XCTAssertTrue(firings.isEmpty)
    }
}
