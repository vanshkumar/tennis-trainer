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

    func consume(
        samples: [GridTrackNetDetector.Sample],
        heightGateProvider: ServeTossApexHeightGateProviding?
    ) -> Bool {
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
        buffer.removeAll { $0.timestamp < cutoff }

        guard buffer.count >= 3 else {
            return false
        }

        let candidateIndex = buffer.count - 2
        let previous = buffer[candidateIndex - 1]
        let candidate = buffer[candidateIndex]
        let next = buffer[candidateIndex + 1]

        guard previous.y < candidate.y, next.y < candidate.y else {
            return false
        }

        let requiredHeight = if let baseline = heightGateProvider?.serveTossApexGateBaselineY {
            baseline + poseHeightMargin
        } else {
            frameRelativeFallback
        }

        guard candidate.y > requiredHeight else {
            return false
        }

        guard candidate.confidence >= confidenceThreshold else {
            return false
        }

        guard candidate.timestamp - lastBeep >= cooldownSeconds else {
            return false
        }

        lastBeep = candidate.timestamp
        return true
    }

    func reset() {
        buffer.removeAll(keepingCapacity: true)
        lastBeep = -.greatestFiniteMagnitude
    }
}
