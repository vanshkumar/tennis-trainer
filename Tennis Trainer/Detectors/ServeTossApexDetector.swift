import Foundation
import CoreGraphics
import CoreMedia

// Retained for the independent pose UI helper; automatic cues never read it.
protocol ServeTossApexHeightGateProviding: AnyObject {
  var serveTossApexGateBaselineY: CGFloat? { get }
}

/// Confirms strict local maxima using first-consumed estimates and candidate-owned pose.
final class ServeTossApexDetector {
  struct CueDiagnostics: Equatable {
    let retainedEntryCount: Int
    let consumedCount: UInt64
    let evaluatedCandidateCount: UInt64
    let emittedCount: UInt64
    let lastEmittedCandidateIdentity: BallDetectionManager.FrameIdentity?
  }

  private struct Entry {
    let identity: BallDetectionManager.FrameIdentity
    let y: CGFloat
    let baselineY: CGFloat?
  }

  private var sourceID: UUID?
  private var generation: UUID?
  private var watermark: BallDetectionManager.FrameIdentity?
  private var buffer: [Entry] = []
  private var lastEvaluatedCandidate: BallDetectionManager.FrameIdentity?
  private var lastEmittedCandidate: BallDetectionManager.FrameIdentity?
  private var consumedCount: UInt64 = 0
  private var evaluatedCount: UInt64 = 0
  private var emittedCount: UInt64 = 0

  init(sourceID: UUID? = nil, generation: UUID? = nil) {
    self.sourceID = sourceID
    self.generation = generation
  }

  var diagnostics: CueDiagnostics {
    .init(retainedEntryCount: buffer.count, consumedCount: consumedCount,
      evaluatedCandidateCount: evaluatedCount, emittedCount: emittedCount,
      lastEmittedCandidateIdentity: lastEmittedCandidate)
  }

  private func isNew(_ sample: GridTrackNetDetector.Sample,
                     after previous: BallDetectionManager.FrameIdentity?) -> Bool {
    let id = sample.metadata.identity
    guard sample.metadata.isValid, id.sourceID == sourceID, id.generation == generation else { return false }
    guard let previous else { return true }
    return id.sequence > previous.sequence && CMTimeCompare(id.sourceTime, previous.sourceTime) > 0
  }

  private func eligiblePosition(_ sample: GridTrackNetDetector.Sample) -> CGPoint? {
    guard let position = sample.position, position.x.isFinite, position.y.isFinite,
          (0...1).contains(position.x), (0...1).contains(position.y),
          sample.confidence.isFinite, sample.confidence >= 0.5 else { return nil }
    return position
  }

  func consume(samples: [GridTrackNetDetector.Sample]) -> Bool {
    // Match the original batch horizon before evaluating any candidates. Scan without
    // retaining another array; missing points also advance the provisional watermark.
    var provisional = watermark
    var newestEligible = buffer.last?.identity.sourceTime
    for sample in samples where isNew(sample, after: provisional) {
      provisional = sample.metadata.identity
      if eligiblePosition(sample) != nil { newestEligible = sample.metadata.sourceTime }
    }
    let cutoff = newestEligible.map { CMTimeSubtract($0, CMTime(value: 3, timescale: 2)) }
    if let cutoff { buffer.removeAll { CMTimeCompare($0.identity.sourceTime, cutoff) < 0 } }

    var didFire = false
    for sample in samples {
      guard isNew(sample, after: watermark) else { continue }
      watermark = sample.metadata.identity
      increment(&consumedCount)
      guard let position = eligiblePosition(sample),
            cutoff.map({ CMTimeCompare(sample.metadata.sourceTime, $0) >= 0 }) ?? true else { continue }
      if buffer.count == 3 { buffer.removeFirst() }
      buffer.append(Entry(identity: sample.metadata.identity, y: position.y,
                          baselineY: sample.metadata.pose.baselineY))
      guard buffer.count == 3 else { continue }
      let candidate = buffer[1]
      guard candidate.identity != lastEvaluatedCandidate else { continue }
      lastEvaluatedCandidate = candidate.identity
      increment(&evaluatedCount)
      let requiredHeight = candidate.baselineY.map { $0 + 0.05 } ?? 0.70
      guard buffer[0].y < candidate.y, buffer[2].y < candidate.y,
            candidate.y > requiredHeight else { continue }
      if let previous = lastEmittedCandidate {
        let elapsed = CMTimeSubtract(candidate.identity.sourceTime, previous.sourceTime)
        guard CMTimeCompare(elapsed, CMTime(value: 4, timescale: 1)) >= 0 else { continue }
      }
      lastEmittedCandidate = candidate.identity
      increment(&emittedCount)
      didFire = true
    }
    return didFire
  }

  /// Only the owning manager authorizes a new domain. Mismatched samples cannot reset it.
  func reset(sourceID: UUID, generation: UUID) {
    guard self.sourceID != sourceID || self.generation != generation else { return }
    self.sourceID = sourceID
    self.generation = generation
    watermark = nil
    buffer.removeAll(keepingCapacity: true)
    lastEvaluatedCandidate = nil
    lastEmittedCandidate = nil
    consumedCount = 0
    evaluatedCount = 0
    emittedCount = 0
  }

  private func increment(_ value: inout UInt64) {
    if value < UInt64.max { value += 1 }
  }
}
