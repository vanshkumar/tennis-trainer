import XCTest
import AVFoundation
import CoreML
@testable import Tennis_Trainer

final class BallDetectionManagerTests: XCTestCase {
  func testPoseOnlyPublishesOrientedFrame_WithoutRunningBallInference() throws {
    var analyses = 0
    var observations: [PoseDetectionManager.FrameObservation] = []
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
      analyses += 1
      return .init(samples: nil, position: nil)
    }, extractPose: { _, identity in .init(identity: identity, joints: [:]) },
      worker: { $0() }, publication: { $0() }))
    manager.setPoseOnly(true)
    manager.onPoseFrame = { observations.append($0) }
    let source = UUID()
    let buffer = try AnalysisFixture.pixels(width: 768, height: 432)
    XCTAssertTrue(manager.process(input: .init(pixelBuffer: buffer, sourceTime: .zero,
      orientation: .right, sourceID: source)))
    XCTAssertEqual(analyses, 0)
    XCTAssertEqual(observations.count, 1)
    XCTAssertEqual(observations.first?.orientedSize, CGSize(width: 432, height: 768))
    XCTAssertEqual(observations.first?.pose.identity.sourceID, source)
    manager.setPoseOnly(false)
    XCTAssertTrue(manager.process(input: .init(pixelBuffer: buffer, sourceTime: .zero,
      orientation: .up, sourceID: source)))
    XCTAssertEqual(analyses, 1)
  }

  func testPoseCallbackRetired_WhenDrillChangesBeforePublication() throws {
    var jobs: [() -> Void] = []
    var observations = 0
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
      .init(samples: nil, position: nil)
    }, worker: { $0() }, publication: { jobs.append($0) }))
    manager.onPoseFrame = { _ in observations += 1 }
    XCTAssertTrue(manager.process(input: input(try pixels(), 0, source: UUID())))
    manager.setPoseOnly(true)
    jobs.removeFirst()()
    XCTAssertEqual(observations, 0)
    XCTAssertEqual(manager.diagnostics.currentLeases, 0)
  }

  func testExpectedGenerationRejectsAcquiredInput_WithoutPoseOrLease() throws {
    var poses = 0
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
      .init(samples: nil, position: nil)
    }, extractPose: { _, identity in
      poses += 1
      return .init(identity: identity, joints: [:])
    }, worker: { $0() }, publication: { $0() }))
    let old = manager.admissionGeneration
    manager.resetTrackingState()
    let input = input(try pixels(), 0, source: UUID())
    XCTAssertFalse(manager.process(input: input, expectedGeneration: old))
    XCTAssertEqual(poses, 0)
    XCTAssertEqual(manager.diagnostics.admitted, 0)
    XCTAssertEqual(manager.diagnostics.currentLeases, 0)
    XCTAssertTrue(manager.process(input: input, expectedGeneration: manager.admissionGeneration))
    XCTAssertEqual(poses, 1)
  }

  func testUniqueBufferBound_WhenTwoManagersHoldPreparationPredictionAndPublication() throws {
    for resetDuringPrediction in [false, true] {
      let ledger = BufferLedger()
      let prepared = expectation(description: "two transient preparations")
      prepared.expectedFulfillmentCount = 2
      let predicting = expectation(description: "two prediction snapshots")
      predicting.expectedFulfillmentCount = 2
      let finished = expectation(description: "workers return")
      finished.expectedFulfillmentCount = 2
      let resumePreparation = DispatchSemaphore(value: 0)
      let resumePrediction = DispatchSemaphore(value: 0)
      let workers = [Scheduler(), Scheduler()], publications = [Scheduler(), Scheduler()]
      var holding = false
      var effects = 0
      var managers: [BallDetectionManager] = (0..<2).map { index in
        let preparation = AnalysisFrame.Preparation(orient: { raw, orientation in
          ledger.record(raw, owner: index)
          let oriented = PixelBufferScaler.shared.copyApplyingOrientation(raw, orientation: orientation)
          if let oriented { ledger.record(oriented, owner: index) }
          return oriented
        }, resize: { oriented, portrait in
          let resized = portrait
            ? PixelBufferScaler.shared.resizeAspectFit(oriented, width: 768, height: 432)
            : PixelBufferScaler.shared.resizeAspectFill(oriented, width: 768, height: 432)
          if let resized { ledger.record(resized, owner: index) }
          if holding { prepared.fulfill(); resumePreparation.wait() }
          return resized
        })
        let grid = GridTrackNetDetector(preparation: preparation, predictor: { window in
          XCTAssertEqual(Set(window.frames.map { ObjectIdentifier($0.pixels) }).count, 5)
          if holding { predicting.fulfill(); resumePrediction.wait() }
          return try DecoderFixture.tossOutputs(window)
        })
        let manager = BallDetectionManager(dependencies: .init(analyze: { input, identity, pose in
          guard grid.pushFrame(input: input, identity: identity, pose: pose) else { return .init(samples: nil, position: nil) }
          return .init(samples: grid.detectAllSamplesIfReady(), position: nil)
        }, reset: grid.clear, bufferDiagnostics: { grid.diagnostics },
        worker: workers[index].enqueue, publication: publications[index].enqueue))
        manager.onApex = { effects += 1 }
        return manager
      }
      let sources = [UUID(), UUID()]
      for index in 0..<2 {
        for sequence in 1...5 {
          try autoreleasepool {
            let raw = try ledger.rawPixels()
            XCTAssertTrue(managers[index].process(input: .init(pixelBuffer: raw,
              sourceTime: CMTime(value: Int64(sequence), timescale: 30), orientation: .right, sourceID: sources[index])))
            workers[index].run()
          }
          publications[index].run()
        }
      }
      XCTAssertEqual(ledger.liveCount, 10)
      XCTAssertEqual(ledger.destroyedRaw, 10)
      XCTAssertEqual(effects, 2)
      holding = true
      for index in 0..<2 {
        try autoreleasepool {
          let raw = try ledger.rawPixels()
          XCTAssertTrue(managers[index].process(input: .init(pixelBuffer: raw,
            sourceTime: CMTime(value: 6, timescale: 30), orientation: .right, sourceID: sources[index])))
        }
        DispatchQueue.global().async { autoreleasepool { workers[index].run() }; finished.fulfill() }
      }
      wait(for: [prepared], timeout: 10)
      XCTAssertEqual(ledger.liveCount, 16)
      XCTAssertEqual(ledger.highWater, 16)
      for index in 0..<2 { XCTAssertEqual(ledger.liveCount(owner: index), 8) }
      let rejected = try AnalysisFixture.pixels(width: 16, height: 16)
      for index in 0..<2 {
        for time in 7...1006 {
          XCTAssertFalse(managers[index].process(input: input(rejected, Int64(time), source: sources[index])))
        }
      }
      XCTAssertEqual(ledger.liveCount, 16)
      XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.currentLeases }, 2)
      XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.pendingInputs }, 0)
      resumePreparation.signal(); resumePreparation.signal()
      wait(for: [predicting], timeout: 10)
      XCTAssertEqual(ledger.liveCount, 12) // ten shared ring/snapshot pixels plus two raw inputs
      for index in 0..<2 {
        XCTAssertEqual(ledger.liveCount(owner: index), 6)
        for time in 2007...3006 {
          XCTAssertFalse(managers[index].process(input: input(rejected, Int64(time), source: sources[index])))
        }
      }
      if resetDuringPrediction { managers.forEach { $0.resetTrackingState() } }
      resumePrediction.signal(); resumePrediction.signal()
      wait(for: [finished], timeout: 10)
      XCTAssertEqual(ledger.destroyedRaw, 12)
      XCTAssertEqual(ledger.liveCount, resetDuringPrediction ? 0 : 10)
      XCTAssertEqual(publications.reduce(0) { $0 + $1.jobs.count }, 2)
      XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.publications }, 2)
      for index in 0..<2 {
        for time in 1007...2006 {
          XCTAssertFalse(managers[index].process(input: input(rejected, Int64(time), source: sources[index])))
        }
      }
      managers.forEach { $0.resetTrackingState() }
      publications.forEach { $0.run() }
      XCTAssertEqual(effects, 2)
      XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.released }, 12)
      XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.currentLeases }, 0)
      XCTAssertLessThanOrEqual(managers.reduce(0) { $0 + $1.cueDiagnostics.retainedEntryCount }, 6)
      managers.removeAll()
      XCTAssertEqual(ledger.liveCount, 0)
      XCTAssertEqual(ledger.highWater, 16)
    }
  }

  func testPixelAndLeaseRelease_WhenRealPipelineTerminatesOrOwnerDisappears() throws {
    enum Failure: Error { case missingModel, prediction, pose }
    for terminal in ["warmup", "missing-model", "pose-absent", "pose-error", "orientation", "resize",
                     "prediction", "malformed", "stale", "reset-in-prediction", "discard", "teardown-worker", "teardown-publication"] {
      let ledger = BufferLedger(), worker = Scheduler(), publication = Scheduler()
      let preparation = AnalysisFrame.Preparation(orient: { raw, orientation in
        ledger.record(raw)
        if terminal == "orientation" { return nil }
        let result = PixelBufferScaler.shared.copyApplyingOrientation(raw, orientation: orientation)
        if let result { ledger.record(result) }
        return result
      }, resize: { oriented, portrait in
        if terminal == "resize" { return nil }
        let result = portrait ? PixelBufferScaler.shared.resizeAspectFit(oriented, width: 768, height: 432)
          : PixelBufferScaler.shared.resizeAspectFill(oriented, width: 768, height: 432)
        if let result { ledger.record(result) }
        return result
      })
      let pose = PoseDetectionManager(transaction: { _, _ in
        if terminal == "pose-error" { throw Failure.pose }
        return [:]
      })
      var invalidate: (() -> Void)?
      var manager: BallDetectionManager? = {
        let grid = GridTrackNetDetector(preparation: preparation, predictor: { window in
          if terminal == "missing-model" { throw Failure.missingModel }
          if terminal == "prediction" { throw Failure.prediction }
          if terminal == "reset-in-prediction" { invalidate?() }
          let output = try DecoderFixture.tossOutputs(window)
          if terminal == "malformed" { output.xOff[0] = NSNumber(value: Float.infinity) }
          return output
        })
        return BallDetectionManager(dependencies: .init(analyze: { input, identity, pose in
          guard grid.pushFrame(input: input, identity: identity, pose: pose) else { return .init(samples: nil, position: nil) }
          return .init(samples: grid.detectAllSamplesIfReady(), position: nil)
        }, extractPose: { input, identity in
          pose.extractPose(in: input.pixelBuffer, orientation: input.orientation, identity: identity)
        }, reset: grid.clear, bufferDiagnostics: { grid.diagnostics }, worker: worker.enqueue, publication: publication.enqueue))
      }()
      invalidate = { [weak manager] in manager?.resetTrackingState() }
      var cues = 0
      manager?.onApex = { cues += 1 }
      weak var weakManager = manager
      let source = UUID()
      let total = terminal == "warmup" || terminal.hasPrefix("teardown") ? 1 : 5
      for sequence in 1...total {
        try autoreleasepool {
          let raw = try ledger.rawPixels()
          XCTAssertTrue(manager!.process(input: .init(pixelBuffer: raw,
            sourceTime: CMTime(value: Int64(sequence), timescale: 30), orientation: .right, sourceID: source)))
        }
        if terminal == "teardown-worker" { manager = nil }
        if terminal == "stale" && sequence == total { manager?.resetTrackingState() }
        autoreleasepool { worker.run() }
        XCTAssertEqual(ledger.destroyedRaw, sequence, terminal)
        if terminal == "teardown-publication" { manager = nil }
        if terminal == "discard" && sequence == total { manager?.resetTrackingState() }
        if !publication.jobs.isEmpty { publication.run() }
        XCTAssertEqual(manager?.diagnostics.currentLeases ?? 0, 0, terminal)
        if let manager { XCTAssertEqual(manager.diagnostics.released, UInt64(sequence), terminal) }
        XCTAssertLessThanOrEqual(ledger.liveCount, 5, terminal)
      }
      XCTAssertEqual(cues, ["pose-absent", "pose-error"].contains(terminal) ? 1 : 0, terminal)
      manager = nil
      XCTAssertNil(weakManager, terminal)
      XCTAssertEqual(ledger.liveCount, 0, terminal)
      XCTAssertLessThanOrEqual(ledger.highWater, 8, terminal)
    }
  }

  func testPublicationOwnsNoTensors_WhenPredictionHasReturned() throws {
    final class WeakTensor {
      weak var value: MLMultiArray?
      init(_ value: MLMultiArray) { self.value = value }
    }
    var tensors: [WeakTensor] = []
    let publication = Scheduler()
    let grid = GridTrackNetDetector(predictor: { window in
      let output = try DecoderFixture.tossOutputs(window)
      tensors = [output.conf, output.xOff, output.yOff].map(WeakTensor.init)
      return output
    })
    let manager = BallDetectionManager(dependencies: .init(analyze: { input, identity, pose in
      guard grid.pushFrame(input: input, identity: identity, pose: pose) else { return .init(samples: nil, position: nil) }
      return .init(samples: grid.detectAllSamplesIfReady(), position: nil)
    }, worker: { $0() }, publication: publication.enqueue))
    let source = UUID()
    for sequence in 1...5 {
      manager.process(input: input(try AnalysisFixture.pixels(), Int64(sequence), source: source))
      if sequence < 5 { publication.run() }
    }
    XCTAssertEqual(tensors.count, 3)
    XCTAssertTrue(tensors.allSatisfy { $0.value == nil })
    grid.clear()
    XCTAssertEqual(grid.diagnostics.ringCount, 0)
    XCTAssertEqual(publication.jobs.count, 1)
    publication.run()
    XCTAssertEqual(manager.diagnostics.released, 5)
  }

  func testPreparedPixelsRemainOwned_WhenSourceIsMutated() throws {
    let source = try AnalysisFixture.pixels(sentinel: 42)
    let identity = AnalysisFixture.identity(1)
    let input = BallDetectionManager.Input(pixelBuffer: source, sourceTime: identity.sourceTime,
      orientation: .up, sourceID: identity.sourceID)
    let frame = try XCTUnwrap(AnalysisFrame.prepare(input: input, identity: identity,
      pose: .init(identity: identity, joints: [:])))
    XCTAssertEqual(frame.metadata.ingressTime, input.ingressTime)
    XCTAssertFalse(frame.pixels === source)
    let before = AnalysisFixture.sentinel(frame.pixels)
    AnalysisFixture.fill(source, 99)
    XCTAssertEqual(AnalysisFixture.sentinel(frame.pixels), before)
    XCTAssertNotEqual(AnalysisFixture.sentinel(frame.pixels), AnalysisFixture.sentinel(source))
    XCTAssertEqual(frame.metadata.mapping.sourceNormalizedPoint(modelX: 384, modelYFromTop: 216),
                   CGPoint(x: 0.5, y: 0.5))
  }

  func testWindowRetainsOriginalMetadata_WhenPredictionIsHeld() throws {
    let entered = expectation(description: "predictor holds A")
    let complete = expectation(description: "prediction completes")
    let release = DispatchSemaphore(value: 0)
    let outputs = try AnalysisFixture.outputs()
    var captured: AnalysisFrame.Window?
    var result: [GridTrackNetDetector.Sample]?
    let detector = GridTrackNetDetector(predictor: { window in
      captured = window
      entered.fulfill()
      release.wait()
      return outputs
    })
    for i in 1...5 { try AnalysisFixture.push(i, into: detector) }
    let original = try XCTUnwrap(detector.snapshot())
    DispatchQueue.global().async {
      result = detector.detectAllSamplesIfReady()
      complete.fulfill()
    }
    wait(for: [entered], timeout: 5)
    for i in 6...10 { try AnalysisFixture.push(i, into: detector, width: 432, height: 768, orientation: .down) }
    release.signal()
    wait(for: [complete], timeout: 5)
    let held = try XCTUnwrap(captured)
    let samples = try XCTUnwrap(result)
    XCTAssertEqual(samples.count, 5)
    for i in 0..<5 {
      let a = original.frames[i]
      let b = held.frames[i]
      XCTAssertTrue(a.pixels === b.pixels)
      XCTAssertEqual(AnalysisFixture.sentinel(a.pixels), AnalysisFixture.sentinel(b.pixels))
      XCTAssertEqual(samples[i].metadata.identity, a.metadata.identity)
      XCTAssertEqual(samples[i].metadata.sourceTime.value, a.metadata.sourceTime.value)
      XCTAssertEqual(samples[i].metadata.sourceTime.timescale, 1000)
      XCTAssertEqual(samples[i].metadata.rawSize, a.metadata.rawSize)
      XCTAssertEqual(samples[i].metadata.orientedSize, a.metadata.orientedSize)
      XCTAssertEqual(samples[i].metadata.orientation, .up)
      XCTAssertEqual(samples[i].metadata.mapping, a.metadata.mapping)
      XCTAssertEqual(samples[i].metadata.pose.baselineY, a.metadata.pose.baselineY)
      XCTAssertEqual(try XCTUnwrap(samples[i].position).x, 0.5, accuracy: 0.001)
      XCTAssertEqual(try XCTUnwrap(samples[i].position).y, 1 - 8.0 / 27, accuracy: 0.001)
    }
    XCTAssertEqual(detector.diagnostics.ringCount, 5)
    XCTAssertEqual(detector.diagnostics.uniquePreparedBufferCount, 5)
  }

  func testNoPrediction_WhenWindowIsIncompleteOrMetadataInvalid() throws {
    var calls = 0
    let outputs = try AnalysisFixture.outputs()
    let detector = GridTrackNetDetector(predictor: { _ in calls += 1; return outputs })
    XCTAssertNil(detector.detectAllSamplesIfReady())
    for i in 1...4 {
      try AnalysisFixture.push(i, into: detector)
      XCTAssertNil(detector.detectAllSamplesIfReady())
    }
    XCTAssertEqual(calls, 0)
    try AnalysisFixture.push(5, into: detector)
    let valid = try XCTUnwrap(detector.snapshot())
    XCTAssertNotNil(detector.detectAllSamplesIfReady())
    XCTAssertEqual(calls, 1)
    for count in 0...4 { XCTAssertNil(AnalysisFrame.Window(Array(valid.frames.prefix(count)))) }
    for time in [CMTime.invalid, .indefinite, .positiveInfinity, .negativeInfinity] {
      let id = BallDetectionManager.FrameIdentity(sourceID: AnalysisFixture.source,
        generation: AnalysisFixture.generation, sequence: 6, sourceTime: time)
      XCTAssertFalse(detector.pushFrame(input: .init(pixelBuffer: try AnalysisFixture.pixels(),
        sourceTime: time, orientation: .up, sourceID: id.sourceID), identity: id,
        pose: .init(identity: id, joints: [:])))
    }
    for invalid in ["source", "generation", "sequence", "time", "geometry", "mapping"] {
      var frames = valid.frames
      let old = frames[4]
      let id = BallDetectionManager.FrameIdentity(
        sourceID: invalid == "source" ? UUID() : old.metadata.identity.sourceID,
        generation: invalid == "generation" ? UUID() : old.metadata.identity.generation,
        sequence: invalid == "sequence" ? 1 : 5,
        sourceTime: invalid == "time" ? .zero : old.metadata.sourceTime)
      let metadata = AnalysisFrame.Metadata(identity: id, sourceTime: id.sourceTime,
        ingressTime: 1, rawSize: invalid == "geometry" ? .zero : old.metadata.rawSize,
        orientedSize: old.metadata.orientedSize, orientation: .up,
        mapping: invalid == "mapping" ? .init(sourceWidth: 768, sourceHeight: 432,
          scale: .nan, offsetX: 0, offsetY: 0) : old.metadata.mapping,
        pose: .init(identity: id, joints: [:]))
      frames[4] = AnalysisFrame(pixels: old.pixels, metadata: metadata)
      XCTAssertNil(AnalysisFrame.Window(frames), invalid)
    }
    XCTAssertEqual(calls, 1)
  }

  private final class Scheduler {
    var jobs: [() -> Void] = []
    func enqueue(_ job: @escaping () -> Void) { jobs.append(job) }
    func run() { jobs.removeFirst()() }
  }

  private func input(_ pixels: CVPixelBuffer, _ time: Int64, source: UUID) -> BallDetectionManager.Input {
    .init(pixelBuffer: pixels, sourceTime: CMTime(value: time, timescale: 1000),
          orientation: .up, sourceID: source)
  }

  func testBoundedWork_WhenWorkerAndPublicationAreHeld() throws {
    let worker = Scheduler()
    let publication = Scheduler()
    var calls = 0
    var poses = 0
    var effects = 0
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
      calls += 1
      return .init(samples: nil, position: CGPoint(x: 0.5, y: 0.5))
    }, extractPose: { _, identity in
      poses += 1
      return .init(identity: identity, joints: [:])
    }, worker: worker.enqueue, publication: publication.enqueue))
    manager.onFrameProcessed = { effects += 1 }
    let buffer = try pixels()
    let source = UUID()
    XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)))
    for i in 1...1000 { XCTAssertFalse(manager.process(input: input(buffer, Int64(i), source: source))) }
    XCTAssertEqual(worker.jobs.count, 1)
    XCTAssertEqual(calls, 0)
    XCTAssertEqual(poses, 0)
    worker.run()
    for i in 1001...2000 { XCTAssertFalse(manager.process(input: input(buffer, Int64(i), source: source))) }
    XCTAssertEqual(calls, 1)
    XCTAssertEqual(poses, 1)
    XCTAssertEqual(publication.jobs.count, 1)
    XCTAssertEqual(effects, 0)
    publication.run()
    XCTAssertEqual(effects, 1)
    XCTAssertEqual(manager.diagnostics.admitted, 1)
    XCTAssertEqual(manager.diagnostics.dropped, 2000)
    XCTAssertEqual(manager.diagnostics.completed, 1)
    XCTAssertEqual(manager.diagnostics.released, 1)
    XCTAssertEqual(manager.diagnostics.pendingInputs, 0)
    XCTAssertEqual(manager.diagnostics.leaseHighWater, 1)
    XCTAssertEqual(manager.diagnostics.publicationHighWater, 1)
    XCTAssertTrue(manager.process(input: input(buffer, 2001, source: source)))
  }

  func testClearsValues_WhenResetWhileIdle() throws {
    let publication = Scheduler()
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
      .init(samples: nil, position: CGPoint(x: 0.5, y: 0.5))
    }, worker: { $0() }, publication: publication.enqueue))
    XCTAssertTrue(manager.process(input: input(try pixels(), 0, source: UUID())))
    publication.run()
    XCTAssertNotNil(manager.ballPosition)
    for _ in 0..<1000 { manager.resetTrackingState() }
    XCTAssertEqual(publication.jobs.count, 1)
    if !publication.jobs.isEmpty { publication.run() }
    XCTAssertNil(manager.ballPosition)
  }

  func testNoCue_WhenTrackCallbackResetsGeneration() throws {
    let manager = tracer { _ in }
    let buffer = try pixels()
    let source = UUID()
    var cues = 0
    manager.onApex = { cues += 1 }
    for i in 0..<16 {
      manager.process(input: input(buffer, 10000 + Int64(i) * 33, source: source))
    }
    manager.onBallTrack = { _ in manager.resetTrackingState() }
    manager.process(input: input(buffer, 10528, source: source))
    XCTAssertEqual(cues, 0)
  }

  func testOccupiedLease_WhenRepeatedResetDuringWorkerAndPublication() throws {
    let worker = Scheduler()
    let publication = Scheduler()
    var effects = 0
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
      .init(samples: nil, position: CGPoint(x: 0.5, y: 0.5))
    }, worker: worker.enqueue, publication: publication.enqueue))
    manager.onFrameProcessed = { effects += 1 }
    let buffer = try pixels()
    let source = UUID()
    manager.process(input: input(buffer, 0, source: source))
    for _ in 0..<1000 { manager.resetTrackingState() }
    XCTAssertFalse(manager.process(input: input(buffer, 1, source: source)))
    XCTAssertEqual(worker.jobs.count, 1)
    worker.run()
    for _ in 0..<1000 { manager.resetTrackingState() }
    XCTAssertFalse(manager.process(input: input(buffer, 2, source: source)))
    XCTAssertEqual(publication.jobs.count, 1)
    publication.run()
    XCTAssertEqual(effects, 0)
    XCTAssertNil(manager.ballPosition)
    XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)))
    worker.run()
    publication.run()
    XCTAssertEqual(effects, 1)
  }
  private final class Output: VideoPlayerManager.FrameOutputReading {
    let pixels: CVPixelBuffer
    var time: CMTime = .zero
    var isNew = true
    var copies = 0
    init(_ pixels: CVPixelBuffer) { self.pixels = pixels }
    func hasNewPixelBuffer(forItemTime time: CMTime) -> Bool { isNew }
    func copyFrame(forItemTime time: CMTime) -> (CVPixelBuffer, CMTime)? {
      copies += 1
      return (pixels, self.time)
    }
  }

  private func pixels() throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    XCTAssertEqual(CVPixelBufferCreate(nil, 16, 16, kCVPixelFormatType_32BGRA,
                                       nil, &buffer), kCVReturnSuccess)
    return try XCTUnwrap(buffer)
  }

  private func sample(_ pixels: CVPixelBuffer, time: CMTime) throws -> CMSampleBuffer {
    var format: CMVideoFormatDescription?
    XCTAssertEqual(CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil,
      imageBuffer: pixels, formatDescriptionOut: &format), noErr)
    var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time,
                                   decodeTimeStamp: .invalid)
    var sample: CMSampleBuffer?
    XCTAssertEqual(CMSampleBufferCreateReadyWithImageBuffer(allocator: nil,
      imageBuffer: pixels, formatDescription: try XCTUnwrap(format),
      sampleTiming: &timing, sampleBufferOut: &sample), noErr)
    return try XCTUnwrap(sample)
  }

  private func tracer(_ received: @escaping (BallDetectionManager.Input) -> Void) -> BallDetectionManager {
    BallDetectionManager(dependencies: .init(analyze: { input, identity, pose in
      received(input)
      let t = CMTimeGetSeconds(input.sourceTime)
      let y = 0.5 + 0.4 * sin(.pi * (t - 10) / 0.99)
      return .init(samples: [.init(tIndex: 4, metadata: AnalysisFixture.metadata(identity: identity, pose: pose),
        position: CGPoint(x: 0.5, y: y), confidence: 0.9)], position: nil)
    }, worker: { $0() }, publication: { $0() }))
  }

  func testAutomaticCue_WhenCameraSampleHasSourcePTS() throws {
    let camera = CameraManager()
    var received: [CMTime] = []
    var orientations: [CGImagePropertyOrientation] = []
    let manager = tracer { received.append($0.sourceTime); orientations.append($0.orientation) }
    camera.setupBallDetection(with: PoseDetectionManager(), factory: { _ in manager })
    var cues = 0
    var processed = 0
    camera.onApex = { cues += 1 }
    camera.onFrameProcessed = { processed += 1 }
    let buffer = try pixels()
    let times = (0..<30).map { CMTime(value: 10000 + Int64($0) * 33, timescale: 1000) }
    for time in times { camera.submitSampleBuffer(try sample(buffer, time: time)) }
    XCTAssertEqual(received, times)
    XCTAssertEqual(orientations, Array(repeating: .right, count: 30))
    XCTAssertEqual(cues, 1)
    XCTAssertEqual(processed, 30)
  }

  func testAutomaticCue_WhenPlaybackReturnsDifferentDisplayTime() throws {
    let player = VideoPlayerManager()
    var received: [CMTime] = []
    let manager = tracer { received.append($0.sourceTime) }
    player.setupBallDetection(with: PoseDetectionManager(), factory: { _ in manager })
    var cues = 0
    player.onApex = { cues += 1 }
    let output = Output(try pixels())
    let times = (0..<30).map { CMTime(value: 10000 + Int64($0) * 33, timescale: 1000) }
    for time in times {
      output.time = time
      player.processCurrentFrame(output: output, requestedTime: CMTime(value: 900, timescale: 1),
                                 orientation: .left)
    }
    output.isNew = false
    player.processCurrentFrame(output: output, requestedTime: .zero, orientation: .left)
    XCTAssertEqual(received, times)
    XCTAssertEqual(output.copies, 30)
    XCTAssertEqual(cues, 1)
  }

  func testNoRealServices_WhenDependenciesAreInjected() throws {
    XCTAssertTrue(AppRuntime.isRunningTests)
    var analyses = 0
    var factories = 0
    var productionFactories = 0
    let fake = BallDetectionManager.Dependencies(analyze: { _, _, _ in
      .init(samples: nil, position: nil)
    }, worker: { $0() }, publication: { $0() })
    _ = BallDetectionManager(poseDetectionManager: nil, dependencies: fake, productionFactory: { _ in
      productionFactories += 1
      return fake
    })
    let manager = tracer { _ in analyses += 1 }
    let camera = CameraManager()
    camera.setupBallDetection(with: PoseDetectionManager(), factory: { _ in
      factories += 1
      return manager
    })
    camera.submitSampleBuffer(try sample(pixels(), time: CMTime(value: 10, timescale: 1)))
    XCTAssertEqual(factories, 1)
    XCTAssertTrue(camera.ballDetectionManager === manager)
    XCTAssertFalse(camera.isRecording)
    XCTAssertEqual(analyses, 1)
    XCTAssertEqual(productionFactories, 0)
  }

  func testRejectsInvalidEqualAndRegressingTimes_WhenGenerationUnchanged() throws {
    let manager = tracer { _ in }
    let buffer = try pixels()
    let source = UUID()
    XCTAssertTrue(manager.process(input: input(buffer, 1000, source: source)))
    for time in [CMTime.invalid, .indefinite, .positiveInfinity, .negativeInfinity,
                 CMTime(value: 2, timescale: 2), CMTime(value: 999, timescale: 1000)] {
      XCTAssertFalse(manager.process(input: .init(pixelBuffer: buffer, sourceTime: time,
        orientation: .up, sourceID: source)))
    }
    XCTAssertFalse(manager.process(input: input(buffer, 1001, source: UUID())))
    manager.resetTrackingState(sourceID: source)
    XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)))
  }

  func testSequenceFailsClosed_WhenCounterExhaustedUntilReset() throws {
    var sequences: [UInt64] = []
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, identity, _ in
      sequences.append(identity.sequence)
      return .init(samples: nil, position: nil)
    }, worker: { $0() }, publication: { $0() }), initialSequence: UInt64.max - 1)
    let buffer = try pixels()
    let source = UUID()
    XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)))
    XCTAssertFalse(manager.process(input: input(buffer, 1, source: source)))
    manager.resetTrackingState()
    XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)))
    XCTAssertEqual(sequences, [UInt64.max, 1])
  }

  func testReleasesCapacity_WhenWarmupMissingModelPreparationOrPredictionFails() throws {
    enum Failure: Error { case prediction }
    for terminal in ["warmup", "missing-model", "preparation-failed", "prediction-threw", "result-rejected"] {
      var calls = 0
      var processed = 0
      let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
        calls += 1
        if terminal == "prediction-threw" { throw Failure.prediction }
        // These backend terminal conditions all return no usable sample batch.
        return .init(samples: nil, position: nil)
      }, worker: { $0() }, publication: { $0() }))
      manager.onFrameProcessed = { processed += 1 }
      let buffer = try pixels()
      let source = UUID()
      XCTAssertTrue(manager.process(input: input(buffer, 0, source: source)), terminal)
      XCTAssertTrue(manager.process(input: input(buffer, 1, source: source)), terminal)
      XCTAssertEqual(calls, 2, terminal)
      XCTAssertEqual(processed, 2, terminal)
      XCTAssertEqual(manager.diagnostics.released, 2, terminal)
      XCTAssertEqual(manager.diagnostics.currentLeases, 0, terminal)
    }
  }

  func testPublishesPoseAndProcessedTogether_WhenWarmupCompletes() throws {
    let worker = Scheduler()
    let publication = Scheduler()
    var events: [String] = []
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, pose in
      XCTAssertEqual(pose.baselineY, 0.8)
      events.append("analysis")
      return .init(samples: nil, position: nil)
    }, extractPose: { _, identity in
      events.append("extract")
      return .init(identity: identity, joints: [.nose: .init(location: CGPoint(x: 0.5, y: 0.8), confidence: 0.9)])
    }, publishPose: { _ in events.append("publish-pose") },
    worker: worker.enqueue, publication: publication.enqueue))
    manager.onFrameProcessed = { events.append("processed") }
    manager.process(input: input(try pixels(), 0, source: UUID()))
    XCTAssertEqual(events, [])
    worker.run()
    XCTAssertEqual(events, ["extract", "analysis"])
    publication.run()
    XCTAssertEqual(events, ["extract", "analysis", "publish-pose", "processed"])
  }

  func testMissingPose_WhenExtractorReturnsAnotherIdentity() throws {
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, pose in
      XCTAssertNil(pose.baselineY)
      XCTAssertTrue(pose.joints.isEmpty)
      return .init(samples: nil, position: nil)
    }, extractPose: { _, identity in
      .init(identity: .init(sourceID: UUID(), generation: identity.generation,
        sequence: identity.sequence, sourceTime: identity.sourceTime),
        joints: [.nose: .init(location: CGPoint(x: 0.5, y: 0.9), confidence: 0.9)])
    }, worker: { $0() }, publication: { $0() }))
    XCTAssertTrue(manager.process(input: input(try pixels(), 0, source: UUID())))
  }

  func testTeardown_WhenWorkerOrPublicationHeld() throws {
    for holdPublication in [false, true] {
      let worker = Scheduler()
      let publication = Scheduler()
      var effects = 0
      var manager: BallDetectionManager? = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
        .init(samples: nil, position: nil)
      }, worker: worker.enqueue, publication: publication.enqueue))
      weak var weakManager = manager
      manager?.onFrameProcessed = { effects += 1 }
      manager?.process(input: input(try pixels(), 0, source: UUID()))
      if holdPublication { worker.run() }
      manager = nil
      XCTAssertNil(weakManager)
      if holdPublication { publication.run() } else { worker.run() }
      XCTAssertEqual(effects, 0)
      XCTAssertTrue(worker.jobs.isEmpty)
      XCTAssertTrue(publication.jobs.isEmpty)
    }
  }

  func testOldCompletionCannotReleaseNewLease_WhenDeliveredTwice() throws {
    let publication = Scheduler()
    let manager = BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
      .init(samples: nil, position: nil)
    }, worker: { $0() }, publication: publication.enqueue))
    let buffer = try pixels()
    let source = UUID()
    manager.process(input: input(buffer, 0, source: source))
    let old = publication.jobs[0]
    publication.run()
    manager.process(input: input(buffer, 1, source: source))
    old()
    XCTAssertEqual(manager.diagnostics.currentLeases, 1)
    XCTAssertEqual(manager.diagnostics.released, 1)
    XCTAssertFalse(manager.process(input: input(buffer, 2, source: source)))
    publication.run()
    XCTAssertEqual(manager.diagnostics.released, 2)
  }

  func testCombinedBounds_WhenTwoManagersSharePose() throws {
    let buffer = try pixels()
    let poseLock = NSLock()
    var active = 0
    var maximum = 0
    var poseCalls = 0
    let pose = PoseDetectionManager(transaction: { _, _ in
      poseLock.lock()
      active += 1
      maximum = max(maximum, active)
      poseCalls += 1
      poseLock.unlock()
      defer { poseLock.lock(); active -= 1; poseLock.unlock() }
      return [:]
    })
    let workers = [Scheduler(), Scheduler()]
    let publications = [Scheduler(), Scheduler()]
    let managers = (0..<2).map { i in
      BallDetectionManager(dependencies: .init(analyze: { _, _, _ in
        .init(samples: nil, position: nil)
      }, extractPose: { input, identity in
        pose.extractPose(in: input.pixelBuffer, orientation: input.orientation, identity: identity)
      }, worker: workers[i].enqueue, publication: publications[i].enqueue))
    }
    let sources = [UUID(), UUID()]
    for i in 0..<2 {
      XCTAssertTrue(managers[i].process(input: input(buffer, 0, source: sources[i])))
      for time in 1...1000 {
        XCTAssertFalse(managers[i].process(input: input(buffer, Int64(time), source: sources[i])))
      }
    }
    XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.currentLeases }, 2)
    XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.pendingInputs }, 0)
    DispatchQueue.concurrentPerform(iterations: 2) { workers[$0].run() }
    XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.publications }, 2)
    XCTAssertEqual(poseCalls, 2)
    XCTAssertEqual(maximum, 1)
    publications.forEach { $0.run() }
    XCTAssertEqual(managers.reduce(0) { $0 + $1.diagnostics.currentLeases }, 0)
  }
}

private final class BufferLedger {
  private final class WeakBuffer {
    weak var value: CVPixelBuffer?
    init(_ value: CVPixelBuffer) { self.value = value }
  }
  private final class RawStorage {
    let bytes = UnsafeMutableRawPointer.allocate(byteCount: 768 * 432 * 4, alignment: 64)
    let onRelease: () -> Void
    init(onRelease: @escaping () -> Void) { self.onRelease = onRelease; bytes.initializeMemory(as: UInt8.self, repeating: 0, count: 768 * 432 * 4) }
    deinit { bytes.deallocate(); onRelease() }
  }
  private let lock = NSLock()
  private var buffers: [(owner: Int, buffer: WeakBuffer)] = []
  private var maximum = 0
  private var releases = 0
  var highWater: Int { lock.lock(); defer { lock.unlock() }; return maximum }
  var destroyedRaw: Int { lock.lock(); defer { lock.unlock() }; return releases }
  var liveCount: Int {
    lock.lock(); defer { lock.unlock() }
    return Set(buffers.compactMap { $0.buffer.value.map(ObjectIdentifier.init) }).count
  }
  func liveCount(owner: Int) -> Int {
    lock.lock(); defer { lock.unlock() }
    return Set(buffers.filter { $0.owner == owner }.compactMap { $0.buffer.value.map(ObjectIdentifier.init) }).count
  }
  func record(_ buffer: CVPixelBuffer, owner: Int = 0) {
    lock.lock(); defer { lock.unlock() }
    buffers.removeAll { $0.buffer.value == nil }
    buffers.append((owner, WeakBuffer(buffer)))
    maximum = max(maximum, Set(buffers.compactMap { $0.buffer.value.map(ObjectIdentifier.init) }).count)
  }
  func rawPixels() throws -> CVPixelBuffer {
    let storage = RawStorage { [weak self] in
      guard let self else { return }
      self.lock.lock(); self.releases += 1; self.lock.unlock()
    }
    let context = Unmanaged.passRetained(storage).toOpaque()
    var pixels: CVPixelBuffer?
    let result = CVPixelBufferCreateWithBytes(nil, 768, 432, kCVPixelFormatType_32BGRA,
      storage.bytes, 768 * 4, { context, _ in
        if let context { Unmanaged<RawStorage>.fromOpaque(context).release() }
      }, context, nil, &pixels)
    if result != kCVReturnSuccess { Unmanaged<RawStorage>.fromOpaque(context).release() }
    XCTAssertEqual(result, kCVReturnSuccess)
    return try XCTUnwrap(pixels)
  }
}

enum AnalysisFixture {
  static let source = UUID()
  static let generation = UUID()

  static func identity(_ sequence: UInt64, time: CMTime? = nil) -> BallDetectionManager.FrameIdentity {
    .init(sourceID: source, generation: generation, sequence: sequence,
          sourceTime: time ?? CMTime(value: Int64(sequence) * 33, timescale: 1000))
  }

  static func metadata(time: Double = 0, identity: BallDetectionManager.FrameIdentity? = nil,
                       pose: PoseDetectionManager.FramePose? = nil) -> AnalysisFrame.Metadata {
    let id = identity ?? self.identity(UInt64(max(0, time) * 1_000_000) + 1,
      time: CMTime(seconds: time, preferredTimescale: 1_000_000))
    return .init(identity: id, sourceTime: id.sourceTime, ingressTime: 1,
      rawSize: CGSize(width: 768, height: 432), orientedSize: CGSize(width: 768, height: 432),
      orientation: .up, mapping: .init(sourceWidth: 768, sourceHeight: 432, scale: 1, offsetX: 0, offsetY: 0),
      pose: pose ?? .init(identity: id, joints: [:]))
  }

  static func pixels(width: Int = 768, height: Int = 432, sentinel: UInt8 = 42) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    XCTAssertEqual(CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA,
      [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer), kCVReturnSuccess)
    let result = try XCTUnwrap(buffer)
    fill(result, sentinel)
    return result
  }

  static func fill(_ pixels: CVPixelBuffer, _ value: UInt8) {
    CVPixelBufferLockBaseAddress(pixels, [])
    let bytes = CVPixelBufferGetBaseAddress(pixels)!.assumingMemoryBound(to: UInt8.self)
    for row in 0..<CVPixelBufferGetHeight(pixels) {
      for col in 0..<CVPixelBufferGetWidth(pixels) {
        let offset = row * CVPixelBufferGetBytesPerRow(pixels) + col * 4
        bytes[offset] = value; bytes[offset + 1] = value; bytes[offset + 2] = value; bytes[offset + 3] = 255
      }
    }
    CVPixelBufferUnlockBaseAddress(pixels, [])
  }

  static func sentinel(_ pixels: CVPixelBuffer) -> UInt8 {
    CVPixelBufferLockBaseAddress(pixels, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
    return CVPixelBufferGetBaseAddress(pixels)!.load(as: UInt8.self)
  }

  static func outputs() throws -> GridTrackNetDetector.RawOutputs {
    let arrays = try (0..<3).map { _ in try MLMultiArray(shape: [5, 27, 48], dataType: .float16) }
    for array in arrays {
      for i in 0..<array.count { array[i] = 0 }
    }
    for t in 0..<5 { arrays[0][[NSNumber(value: t), 8, 24]] = 0.9 }
    return .init(conf: arrays[0], xOff: arrays[1], yOff: arrays[2])
  }

  static func push(_ index: Int, into detector: GridTrackNetDetector, width: Int = 768,
                   height: Int = 432, orientation: CGImagePropertyOrientation = .up) throws {
    let id = identity(UInt64(index))
    XCTAssertTrue(detector.pushFrame(input: .init(pixelBuffer: try pixels(width: width, height: height,
      sentinel: UInt8(index * 10)), sourceTime: id.sourceTime, orientation: orientation, sourceID: source),
      identity: id, pose: .init(identity: id, joints: [.nose: .init(
        location: CGPoint(x: 0.5, y: CGFloat(index) / 20), confidence: 0.9)])))
  }
}
