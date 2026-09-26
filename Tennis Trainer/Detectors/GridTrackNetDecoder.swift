import Foundation
import CoreML

/// Validates each head independently; tensor storage never escapes its scoped access.
enum GridTrackNetDecoder {
  static func decode(outputs: GridTrackNetDetector.RawOutputs,
                     window: AnalysisFrame.Window) -> [GridTrackNetDetector.Sample]? {
    guard let confidence = values(outputs.conf), let x = values(outputs.xOff),
          let y = values(outputs.yOff) else { return nil }
    return (0..<5).map { t in
      // Canonical order is temporal, row, column; strict > preserves first ties.
      let start = t * 27 * 48
      var best = start
      for index in (start + 1)..<(start + 27 * 48) where confidence[index] > confidence[best] {
        best = index
      }
      let row = (best - start) / 48, column = (best - start) % 48
      let position = confidence[best] >= 0.5
        ? window.frames[t].metadata.mapping.sourceNormalizedPoint(
          modelX: (Float(column) + x[best]) * 16, modelYFromTop: (Float(row) + y[best]) * 16)
        : nil
      return .init(tIndex: t, metadata: window.frames[t].metadata,
        position: position, confidence: confidence[best])
    }
  }

  private static func values(_ array: MLMultiArray) -> [Float]? {
    guard array.dataType == .float16 else { return nil }
    let shape = array.shape.map(\.intValue)
    guard [[5, 48, 27], [5, 27, 48], [1, 5, 48, 27], [1, 5, 27, 48]].contains(shape) else { return nil }
    return array.withUnsafeBytes { bytes -> [Float]? in
      // Read strides inside access: Core ML owns the backing storage contract.
      let strides = array.strides.map(\.intValue)
      guard strides.count == shape.count, strides.allSatisfy({ $0 > 0 }) else { return nil }
      var span = 1
      // Reject overlapping axes as well as overflow before doing any pointer reads.
      for axis in shape.indices.filter({ shape[$0] > 1 }).sorted(by: { strides[$0] < strides[$1] }) {
        guard strides[axis] >= span else { return nil }
        let (extent, multiplyOverflow) = (shape[axis] - 1).multipliedReportingOverflow(by: strides[axis])
        let (next, addOverflow) = span.addingReportingOverflow(extent)
        guard !multiplyOverflow, !addOverflow else { return nil }
        span = next
      }
      guard span <= bytes.count / MemoryLayout<UInt16>.size else { return nil }
      let timeAxis = shape.count == 4 ? 1 : 0
      let rowAxis = shape.firstIndex(of: 27)!, columnAxis = shape.firstIndex(of: 48)!
      var result: [Float] = []
      result.reserveCapacity(5 * 27 * 48)
      for t in 0..<5 {
        for row in 0..<27 {
          for column in 0..<48 {
            // All positive terms are bounded by the checked storage span above.
            let offset = t * strides[timeAxis] + row * strides[rowAxis] + column * strides[columnAxis]
            let bits = bytes.loadUnaligned(fromByteOffset: offset * 2, as: UInt16.self)
            let value = Float(Float16(bitPattern: bits))
            guard value.isFinite else { return nil }
            result.append(value)
          }
        }
      }
      return result
    }
  }
}
