import XCTest
import CoreGraphics
import Vision
@testable import Tennis_Trainer

final class ServeTossApexDetectorTests: XCTestCase {
    func testNoRevision_WhenFirstEstimateHasNoAcceptedPosition() {
        for confidence in [Float(0.2), 0.9] {
            let detector = ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation)
            let candidate = sample(t: 0.2, y: 0.9)
            let missing = GridTrackNetDetector.Sample(tIndex: 0, metadata: candidate.metadata,
                position: confidence < 0.5 ? candidate.position : nil, confidence: confidence)
            XCTAssertFalse(detector.consume(samples: [missing]))
            XCTAssertFalse(detector.consume(samples: [sample(t: 0.1, y: 0.5), candidate,
                sample(t: 0.3, y: 0.5)]))
        }
    }

    func testDenseHistoryRemainsBounded_WhenOneThousandWindowsOverlap() throws {
        let detector = ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation)
        for end in 5...1004 {
            let batch = (end - 4...end).map { sample(t: Double($0) / 100_000, y: 0.5) }
            XCTAssertFalse(detector.consume(samples: batch))
        }
        XCTAssertLessThanOrEqual(detector.diagnostics.retainedEntryCount, 3)
        XCTAssertEqual(detector.diagnostics.consumedCount, 1004)
        XCTAssertEqual(detector.diagnostics.evaluatedCandidateCount, 1002)
        XCTAssertEqual(detector.diagnostics.emittedCount, 0)
    }

    func testHorizonBoundaryAndBatchPartition_PreserveEligibility() {
        for end in [1.5, 1.500001] {
            let batch = [sample(t: 0, y: 0.5), sample(t: 0.5, y: 0.9), sample(t: end, y: 0.5)]
            let expected = end == 1.5
            let together = ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation)
            XCTAssertEqual(together.consume(samples: batch), expected)
            let split = ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation)
            XCTAssertFalse(split.consume(samples: Array(batch.prefix(2))))
            XCTAssertEqual(split.consume(samples: [batch[2]]), expected)
        }
    }

    func testNoCue_WhenEmptyPartialNoAcceptedPositionsOrTiedMaximum() {
        XCTAssertFalse(ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation).consume(samples: []))
        for ys in [[CGFloat(0.9)], [0.5, 0.9], [0.5, 0.9, 0.9, 0.5]] {
            XCTAssertFalse(ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation).consume(samples: ys.enumerated().map {
                sample(t: Double($0.offset) / 10, y: $0.element)
            }))
        }
        XCTAssertFalse(ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation).consume(samples: (0..<5).map {
            sample(t: Double($0) / 10, y: 0.9, conf: 0.2)
        }))
    }

    private func cooldown(_ separation: Int64, expected: Bool) {
        let detector = ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation)
        func point(_ milliseconds: Int64, _ y: CGFloat) -> GridTrackNetDetector.Sample {
            let id = AnalysisFixture.identity(UInt64(milliseconds) + 1,
                time: CMTime(value: milliseconds, timescale: 1000))
            return .init(tIndex: 0, metadata: AnalysisFixture.metadata(identity: id),
                position: CGPoint(x: 0.5, y: y), confidence: 0.9)
        }
        XCTAssertTrue(detector.consume(samples: [point(0, 0.5), point(100, 0.9), point(200, 0.5)]))
        XCTAssertEqual(detector.consume(samples: [point(separation, 0.5),
            point(separation + 100, 0.9), point(separation + 200, 0.5)]), expected)
        XCTAssertEqual(detector.diagnostics.consumedCount, 6)
        XCTAssertEqual(detector.diagnostics.evaluatedCandidateCount, 2)
        XCTAssertEqual(detector.diagnostics.emittedCount, expected ? 2 : 1)
    }

    func testCooldownBelowFourSeconds_RejectsSecondToss() { cooldown(3999, expected: false) }
    func testCooldownAtFourSeconds_AcceptsSecondToss() { cooldown(4000, expected: true) }
    func testCooldownAboveFourSeconds_AcceptsSecondToss() { cooldown(4001, expected: true) }

    func testReplayAfterPruning_DoesNotChangeConsumptionEvaluationOrEmission() {
        let detector = ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation)
        let old = [sample(t: 0, y: 0.5), sample(t: 0.1, y: 0.9), sample(t: 0.2, y: 0.5)]
        XCTAssertTrue(detector.consume(samples: old))
        XCTAssertFalse(detector.consume(samples: [sample(t: 10, y: 0.5)]))
        XCTAssertEqual(detector.diagnostics.retainedEntryCount, 1)
        let before = detector.diagnostics
        for _ in 0..<1000 {
            XCTAssertFalse(detector.consume(samples: old))
            XCTAssertFalse(detector.consume(samples: old.reversed()))
        }
        XCTAssertEqual(detector.diagnostics, before)
        XCTAssertEqual(before.consumedCount, 4)
        XCTAssertEqual(before.evaluatedCandidateCount, 1)
        XCTAssertEqual(before.emittedCount, 1)
    }

    func testEqualRationalTimeAndOlderSequence_AreRejectedIndependently() {
        let detector = ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation)
        let first = AnalysisFixture.identity(10, time: CMTime(value: 1, timescale: 2))
        func value(_ id: BallDetectionManager.FrameIdentity) -> GridTrackNetDetector.Sample {
            .init(tIndex: 0, metadata: AnalysisFixture.metadata(identity: id),
                  position: CGPoint(x: 0.5, y: 0.9), confidence: 0.9)
        }
        XCTAssertFalse(detector.consume(samples: [value(first)]))
        for id in [AnalysisFixture.identity(11, time: CMTime(value: 500, timescale: 1000)),
                   AnalysisFixture.identity(9, time: CMTime(value: 1, timescale: 1)),
                   AnalysisFixture.identity(12, time: .invalid),
                   AnalysisFixture.identity(12, time: .positiveInfinity)] {
            XCTAssertFalse(detector.consume(samples: [value(id)]))
        }
        XCTAssertEqual(detector.diagnostics.consumedCount, 1)
    }

    func testNewDomainRequiresExplicitReset_AndRejectsPreviousGeneration() {
        let detector = ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation)
        let old = [sample(t: 0, y: 0.5), sample(t: 0.1, y: 0.9), sample(t: 0.2, y: 0.5)]
        XCTAssertTrue(detector.consume(samples: old))
        let newGeneration = UUID()
        let fresh = old.map { sample in
            let oldID = sample.metadata.identity
            let id = BallDetectionManager.FrameIdentity(sourceID: oldID.sourceID, generation: newGeneration,
                sequence: oldID.sequence, sourceTime: oldID.sourceTime)
            return GridTrackNetDetector.Sample(tIndex: 0, metadata: AnalysisFixture.metadata(identity: id),
                position: sample.position, confidence: sample.confidence)
        }
        let before = detector.diagnostics
        XCTAssertFalse(detector.consume(samples: fresh))
        detector.reset(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation)
        XCTAssertEqual(detector.diagnostics, before)
        detector.reset(sourceID: AnalysisFixture.source, generation: newGeneration)
        XCTAssertFalse(detector.consume(samples: old))
        XCTAssertEqual(detector.diagnostics.consumedCount, 0)
        XCTAssertFalse(detector.consume(samples: Array(fresh.prefix(2))))
        XCTAssertTrue(detector.consume(samples: [fresh[2]]))
        XCTAssertEqual(detector.diagnostics.consumedCount, 3)
    }

    func testExpiredCandidatesAreNotEvaluatedRetrospectively_WhenBatchSpansHorizon() {
        let detector = ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation)
        XCTAssertFalse(detector.consume(samples: [sample(t: 0, y: 0.5), sample(t: 0.1, y: 0.9),
            sample(t: 0.2, y: 0.5), sample(t: 4, y: 0.5)]))
        XCTAssertEqual(detector.diagnostics.consumedCount, 4)
        XCTAssertEqual(detector.diagnostics.evaluatedCandidateCount, 0)
        XCTAssertEqual(detector.diagnostics.retainedEntryCount, 1)
    }

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
        XCTAssertTrue(ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation).consume(samples: samples))
    }

    func testNoCueUsesCandidatePose_WhenLaterNoseIsLower() {
        let samples = [associatedSample(1, y: 0.5, baseline: 0.95),
                       associatedSample(2, y: 0.71, baseline: 0.95),
                       associatedSample(3, y: 0.5, baseline: 0.6)]
        XCTAssertFalse(ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation).consume(samples: samples))
    }

    func testCueUsesFallback_WhenPoseIdentityMismatchesAboveThreshold() {
        for mismatch in ["source", "generation", "frame"] {
            let candidate = associatedSample(2, y: 0.71, baseline: 0.95, mismatch: mismatch)
            XCTAssertTrue(candidate.metadata.pose.joints.isEmpty)
            XCTAssertTrue(candidate.metadata.isValid)
            XCTAssertTrue(ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation).consume(samples: [
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
            XCTAssertEqual(ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation).consume(samples: samples), expected)
        }
    }

    func testMissingCandidateNeverInheritsPose_AndDelayedPoseCannotReviseCandidate() {
        let detector = ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation)
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
                XCTAssertFalse(ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation).consume(samples: [
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
        let detector = ServeTossApexDetector(sourceID: AnalysisFixture.source, generation: AnalysisFixture.generation)
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
