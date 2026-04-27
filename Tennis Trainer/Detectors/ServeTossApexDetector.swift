import Foundation
import CoreGraphics
import QuartzCore

protocol ServeTossApexHeightGateProviding: AnyObject {
    var serveTossApexGateBaselineY: CGFloat? { get }
}

/// Detects the apex of a serve toss from the GridTrackNet sample stream.
/// Apex = local maximum in Vision-normalized vertical position that passes
/// the configured height gate and cooldown checks.
final class ServeTossApexDetector {
    private let cooldownSeconds: CFTimeInterval = 4.0
    private let bufferHorizonSeconds: CFTimeInterval = 1.5
    private let confidenceThreshold: Float = 0.5
    private let poseHeightMargin: CGFloat = 0.05
    private let frameRelativeFallback: CGFloat = 0.70

    private struct Entry {
        let timestamp: CFTimeInterval
        let y: CGFloat
        let confidence: Float
    }

    private var buffer: [Entry] = []
    private var lastBeep: CFTimeInterval = -.greatestFiniteMagnitude
    private var nextCandidateIndex = 1

    func consume(
        samples: [GridTrackNetDetector.Sample],
        heightGateProvider: ServeTossApexHeightGateProviding?
    ) -> Bool {
        var didFire = false

        for sample in samples {
            guard
                let position = sample.position,
                sample.confidence >= confidenceThreshold
            else {
                continue
            }

            if let lastTimestamp = buffer.last?.timestamp, sample.timestamp <= lastTimestamp {
                continue
            }

            buffer.append(
                Entry(
                    timestamp: sample.timestamp,
                    y: position.y,
                    confidence: sample.confidence
                )
            )
        }

        guard let newestTimestamp = buffer.last?.timestamp else {
            return false
        }

        let cutoff = newestTimestamp - bufferHorizonSeconds
        let removedCount = buffer.prefix { $0.timestamp < cutoff }.count
        if removedCount > 0 {
            buffer.removeFirst(removedCount)
            nextCandidateIndex = max(1, nextCandidateIndex - removedCount)
        }

        guard buffer.count >= 3 else {
            return false
        }

        while nextCandidateIndex + 1 < buffer.count {
            let previous = buffer[nextCandidateIndex - 1]
            let candidate = buffer[nextCandidateIndex]
            let next = buffer[nextCandidateIndex + 1]
            nextCandidateIndex += 1

            guard previous.y < candidate.y, next.y < candidate.y else {
                continue
            }

            let requiredHeight = if let baseline = heightGateProvider?.serveTossApexGateBaselineY {
                baseline + poseHeightMargin
            } else {
                frameRelativeFallback
            }

            guard candidate.y > requiredHeight else {
                continue
            }

            guard candidate.confidence >= confidenceThreshold else {
                continue
            }

            guard candidate.timestamp - lastBeep >= cooldownSeconds else {
                continue
            }

            lastBeep = candidate.timestamp
            didFire = true
        }

        return didFire
    }

    func reset() {
        buffer.removeAll(keepingCapacity: true)
        lastBeep = -.greatestFiniteMagnitude
        nextCandidateIndex = 1
    }
}
