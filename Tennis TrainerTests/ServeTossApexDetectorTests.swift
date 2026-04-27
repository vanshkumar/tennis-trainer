import XCTest
import CoreGraphics
@testable import Tennis_Trainer

final class ServeTossApexDetectorTests: XCTestCase {
    private final class StubHeightGateProvider: ServeTossApexHeightGateProviding {
        let serveTossApexGateBaselineY: CGFloat?

        init(baselineY: CGFloat?) {
            self.serveTossApexGateBaselineY = baselineY
        }
    }

    private func sample(t: CFTimeInterval, y: CGFloat, conf: Float = 0.9) -> GridTrackNetDetector.Sample {
        GridTrackNetDetector.Sample(
            tIndex: 0,
            timestamp: t,
            position: CGPoint(x: 0.5, y: y),
            confidence: conf
        )
    }

    private func runDetector(
        samples: [GridTrackNetDetector.Sample],
        batchSize: Int = 5,
        provider: ServeTossApexHeightGateProviding? = nil
    ) -> [Int] {
        let detector = ServeTossApexDetector()
        var firingBatchIndices: [Int] = []
        var batchIndex = 0

        for start in stride(from: 0, to: samples.count, by: batchSize) {
            let end = min(start + batchSize, samples.count)
            if detector.consume(samples: Array(samples[start..<end]), heightGateProvider: provider) {
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
            provider: StubHeightGateProvider(baselineY: 0.95)
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
