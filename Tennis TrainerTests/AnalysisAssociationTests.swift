import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class AnalysisAssociationTests: XCTestCase {
  func testCompleteCameraCue_WhenRealPreparationAndDecoderAreUsed() throws {
    try runCompleteAdapter(cameraMode: true)
  }

  func testCompletePlaybackCue_WhenRealPreparationAndDecoderAreUsed() throws {
    try runCompleteAdapter(cameraMode: false)
  }

  private func runCompleteAdapter(cameraMode: Bool) throws {
    var windows: [[AnalysisFrame.Metadata]] = []
    let grid = GridTrackNetDetector(predictor: { window in
      windows.append(window.frames.map(\.metadata))
      return try DecoderFixture.tossOutputs(window)
    })
    let manager = BallDetectionManager(dependencies: .init(analyze: { input, identity, pose in
      guard grid.pushFrame(input: input, identity: identity, pose: pose) else { return .init(samples: nil, position: nil) }
      return .init(samples: grid.detectAllSamplesIfReady(), position: nil)
    }, extractPose: { _, identity in
      .init(identity: identity, joints: [.nose: .init(location: CGPoint(x: 0.5,
        y: identity.sequence == 3 ? 0.6 : 0.95), confidence: 0.9)])
    }, reset: grid.clear, bufferDiagnostics: { grid.diagnostics }, worker: { $0() }, publication: { $0() }))
    let camera = CameraManager(), player = VideoPlayerManager()
    let pose = PoseDetectionManager()
    var cues = 0
    if cameraMode {
      camera.setupBallDetection(with: pose, factory: { _ in manager })
      camera.onApex = { cues += 1 }
    } else {
      player.setupBallDetection(with: pose, factory: { _ in manager })
      player.onApex = { cues += 1 }
    }
    let pixels = try AnalysisFixture.pixels()
    let output = CompleteOutput(pixels)
    for sequence in 1...9 {
      let time = CMTime(value: Int64(10000 + sequence * 33), timescale: 1000)
      if cameraMode { camera.submitSampleBuffer(try CompleteOutput.sample(pixels, time: time)) }
      else {
        output.time = time
        player.processCurrentFrame(output: output, requestedTime: CMTime(value: 900, timescale: 1), orientation: .left)
      }
      if sequence < 5 { XCTAssertEqual(cues, 0) }
    }
    XCTAssertEqual(cues, 1)
    XCTAssertEqual(windows.count, 5)
    XCTAssertEqual(manager.cueDiagnostics.consumedCount, 9)
    XCTAssertEqual(manager.cueDiagnostics.lastEmittedCandidateIdentity?.sequence, 3)
    for (windowIndex, window) in windows.enumerated() {
      for (t, metadata) in window.enumerated() {
        let sequence = windowIndex + t + 1
        XCTAssertEqual(metadata.identity.sequence, UInt64(sequence))
        XCTAssertEqual(metadata.sourceTime, CMTime(value: Int64(10000 + sequence * 33), timescale: 1000))
        XCTAssertEqual(metadata.pose.identity, metadata.identity)
        XCTAssertEqual(metadata.pose.baselineY, sequence == 3 ? 0.6 : 0.95)
        XCTAssertEqual(metadata.orientedSize, CGSize(width: 432, height: 768))
        XCTAssertEqual(metadata.mapping.scale, 0.5625)
        XCTAssertEqual(metadata.mapping.offsetX, 262.5)
        XCTAssertEqual(metadata.orientation, cameraMode ? .right : .left)
      }
    }
    // The same acquired rational time, even under another representation, cannot be consumed twice.
    let last = CMTime(value: 20594, timescale: 2000)
    if cameraMode { camera.submitSampleBuffer(try CompleteOutput.sample(pixels, time: last)) }
    else { output.time = last; player.processCurrentFrame(output: output, requestedTime: .zero, orientation: .left) }
    XCTAssertEqual(manager.cueDiagnostics.consumedCount, 9)
    XCTAssertEqual(cues, 1)
    XCTAssertEqual(windows.count, 5)
  }

  private final class CompleteOutput: VideoPlayerManager.FrameOutputReading {
    let pixels: CVPixelBuffer
    var time = CMTime.zero
    init(_ pixels: CVPixelBuffer) { self.pixels = pixels }
    func hasNewPixelBuffer(forItemTime: CMTime) -> Bool { true }
    func copyFrame(forItemTime: CMTime) -> (CVPixelBuffer, CMTime)? { (pixels, time) }
    static func sample(_ pixels: CVPixelBuffer, time: CMTime) throws -> CMSampleBuffer {
      var format: CMVideoFormatDescription?
      XCTAssertEqual(CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixels,
        formatDescriptionOut: &format), noErr)
      var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
      var sample: CMSampleBuffer?
      XCTAssertEqual(CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixels,
        formatDescription: try XCTUnwrap(format), sampleTiming: &timing, sampleBufferOut: &sample), noErr)
      return try XCTUnwrap(sample)
    }
  }

  func testSlidingWindowsAndReplayAfterPruning_KeepBoundedManagerCueState() throws {
    var history: [GridTrackNetDetector.Sample] = []
    var original: [GridTrackNetDetector.Sample] = []
    var replay = false
    var cues = 0
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, identity, pose in
      if replay { return .init(samples: original, position: nil) }
      let item = GridTrackNetDetector.Sample(tIndex: 4,
        metadata: AnalysisFixture.metadata(identity: identity, pose: pose),
        position: CGPoint(x: 0.5, y: identity.sequence == 3 ? 0.9 : 0.5), confidence: 0.9)
      if history.count == 5 { history.removeFirst() }
      history.append(item)
      if identity.sequence == 5 { original = history }
      return .init(samples: history.count == 5 ? history : nil, position: nil)
    }, worker: { $0() }, publication: { $0() }))
    manager.onApex = { cues += 1 }
    let pixels = try AnalysisFixture.pixels(width: 16, height: 16)
    let source = UUID()
    for index in 1...1004 {
      XCTAssertTrue(manager.process(input: .init(pixelBuffer: pixels,
        sourceTime: CMTime(value: Int64(index), timescale: 100), orientation: .up, sourceID: source)))
      XCTAssertLessThanOrEqual(manager.cueDiagnostics.retainedEntryCount, 3)
      if index < 5 { XCTAssertEqual(cues, 0) }
    }
    XCTAssertEqual(cues, 1)
    XCTAssertEqual(manager.cueDiagnostics.consumedCount, 1004)
    XCTAssertEqual(manager.cueDiagnostics.evaluatedCandidateCount, 1002)
    let before = manager.cueDiagnostics
    replay = true
    manager.process(input: .init(pixelBuffer: pixels, sourceTime: CMTime(value: 20, timescale: 1),
      orientation: .up, sourceID: source))
    XCTAssertEqual(manager.cueDiagnostics, before)
    manager.resetTrackingState(sourceID: source)
    manager.process(input: .init(pixelBuffer: pixels, sourceTime: .zero, orientation: .up, sourceID: source))
    XCTAssertEqual(manager.cueDiagnostics.consumedCount, 0)
    XCTAssertEqual(cues, 1)
  }

  func testLaterPoseAndConfidentContextCannotReviseMissingCandidate_ThroughManager() throws {
    var first: [GridTrackNetDetector.Sample] = []
    var cues = 0
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, identity, pose in
      let sample = GridTrackNetDetector.Sample(tIndex: 4,
        metadata: AnalysisFixture.metadata(identity: identity, pose: pose),
        position: identity.sequence == 2 ? nil : CGPoint(x: 0.5, y: 0.5), confidence: 0.9)
      if identity.sequence <= 5 {
        first.append(sample)
        return .init(samples: first.count == 5 ? first : nil, position: nil)
      }
      let revised = first.map { previous in
        let id = previous.metadata.identity
        return GridTrackNetDetector.Sample(tIndex: 0,
          metadata: AnalysisFixture.metadata(identity: id, pose: .init(identity: id,
            joints: [.nose: .init(location: CGPoint(x: 0.5, y: 0.1), confidence: 0.9)])),
          position: CGPoint(x: 0.5, y: id.sequence == 2 ? 0.9 : 0.5), confidence: 0.9)
      }
      return .init(samples: revised + [sample], position: nil)
    }, worker: { $0() }, publication: { $0() }))
    manager.onApex = { cues += 1 }
    let source = UUID()
    let pixels = try AnalysisFixture.pixels(width: 16, height: 16)
    for index in 1...6 {
      manager.process(input: .init(pixelBuffer: pixels, sourceTime: CMTime(value: Int64(index), timescale: 100),
        orientation: .up, sourceID: source))
    }
    XCTAssertEqual(cues, 0)
    XCTAssertEqual(manager.cueDiagnostics.consumedCount, 6)
  }

  func testNoAutomaticCue_WhenRealWindowIsEmptyWarmingUpOrHasNoPositions() throws {
    var predictions = 0
    let outputs = try AnalysisFixture.outputs()
    for index in 0..<outputs.conf.count { outputs.conf[index] = 0 }
    let grid = GridTrackNetDetector(predictor: { _ in predictions += 1; return outputs })
    var cues = 0
    let manager = BallDetectionManager(dependencies: .init(analyze: { input, identity, pose in
      guard grid.pushFrame(input: input, identity: identity, pose: pose) else {
        return .init(samples: nil, position: nil)
      }
      return .init(samples: grid.detectAllSamplesIfReady(), position: nil)
    }, reset: grid.clear, bufferDiagnostics: { grid.diagnostics },
    worker: { $0() }, publication: { $0() }))
    manager.onApex = { cues += 1 }
    XCTAssertEqual(cues, 0)
    let source = UUID()
    let pixels = try AnalysisFixture.pixels()
    for index in 1...5 {
      manager.process(input: .init(pixelBuffer: pixels, sourceTime: CMTime(value: Int64(index), timescale: 30),
        orientation: .up, sourceID: source))
      XCTAssertEqual(predictions, index == 5 ? 1 : 0)
      XCTAssertEqual(cues, 0)
    }
    XCTAssertEqual(manager.cueDiagnostics.consumedCount, 5)
    XCTAssertEqual(manager.cueDiagnostics.retainedEntryCount, 0)
    XCTAssertEqual(manager.diagnostics.preparedRingCount, 5)
    XCTAssertEqual(manager.diagnostics.uniquePreparedBufferCount, 5)
    manager.resetTrackingState(sourceID: source)
    manager.process(input: .init(pixelBuffer: pixels, sourceTime: .zero, orientation: .up, sourceID: source))
    XCTAssertEqual(predictions, 1)
    XCTAssertEqual(manager.diagnostics.preparedRingCount, 1)
    XCTAssertEqual(manager.cueDiagnostics.consumedCount, 0)
  }

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
