import XCTest
@preconcurrency import AVFoundation
import Combine
@testable import Tennis_Trainer

final class VideoPlayerManagerTests: XCTestCase {
  func testFrameReaderRetainsFileAcrossReentrantRetirement() {
    var removed = 0
    let importer = VideoImportManager(effects: .init(prepare: { _ in }, copy: { _, _ in },
      remove: { _ in removed += 1 }, state: { $0() }))
    let player = VideoPlayerManager(dependencies: .init(play: { true }, pause: {}, startLoop: {}, stopLoop: {}))
    player.ballDetectionManager = BallDetectionManager(dependencies: .init(
      analyze: { _, _, _ in .init(samples: nil, position: nil) }, worker: { $0() }, publication: { $0() }))
    let request = player.beginReplacement()
    importer.begin(request: request) { player.acceptImport($1, request: $0) }
    importer.receiveSelection(request: request) { callback in
      callback(URL(fileURLWithPath: "/provider/movie.mov"), nil); return Progress()
    }
    player.play()
    player.processPlaybackFrame(output: RetirementReader(check: {
      player.shutdown()
      XCTAssertEqual(removed, 0, "An executing output reader still owns its lease")
    }), requestedTime: .zero, orientation: .up)
    XCTAssertEqual(removed, 1)
  }
  func testHundredReplacementCyclesBalanceOwnersAndReleaseAllCopies() {
    var copies: Set<URL> = [], removals: Set<URL> = []
    var loops = 0, maximumLoops = 0, timeOwners = 0, maximumTimeOwners = 0, eventOwners = 0
    var timeCallbacks: [(CMTime) -> Void] = [], eventCallbacks: [(VideoPlayerManager.ItemEvent) -> Void] = []
    var ticks: [() -> Void] = []
    var seeks: [(Bool) -> Void] = []
    let importer = VideoImportManager(effects: .init(prepare: { _ in }, copy: { _, url in copies.insert(url) },
      remove: { XCTAssertTrue(removals.insert($0).inserted, "Exactly one removal per owned copy") }, state: { $0() }))
    var player: VideoPlayerManager? = VideoPlayerManager(dependencies: .init(play: { true }, pause: {},
      startLoop: { loops += 1; maximumLoops = max(maximumLoops, loops) }, stopLoop: { loops -= 1 },
      seek: { _, done in seeks.append(done) },
      observeTicks: { callback in ticks.append(callback); return {} },
      observeTime: { callback in
        timeOwners += 1; maximumTimeOwners = max(maximumTimeOwners, timeOwners)
        timeCallbacks.append(callback)
        var removed = false
        return { XCTAssertFalse(removed); removed = true; timeOwners -= 1 }
      }, observeEvents: { callback in
        eventOwners += 1; XCTAssertLessThanOrEqual(eventOwners, 1)
        eventCallbacks.append(callback)
        var removed = false
        return { XCTAssertFalse(removed); removed = true; eventOwners -= 1 }
      }))
    weak var probe = player
    for _ in 0..<100 {
      let request = player!.beginReplacement()
      importer.begin(request: request) { [weak player] in player?.acceptImport($1, request: $0) }
      importer.receiveSelection(request: request) { done in
        done(URL(fileURLWithPath: "/external/same.mov"), nil); return Progress()
      }
      player!.play(); player!.play(); player!.pause(); player!.play()
      player!.seek(to: 2)
      seeks.last?(true)
      XCTAssertEqual(loops, 1)
      XCTAssertEqual(timeOwners, 1)
      // Deliver all retained old callbacks; they cannot affect the current owner.
      timeCallbacks.forEach { $0(.zero) }; eventCallbacks.forEach { $0(.ended) }; ticks.forEach { $0() }
      XCTAssertTrue(player!.isPlaying)
    }
    player!.shutdown(); player!.shutdown()
    XCTAssertEqual(loops, 0); XCTAssertEqual(timeOwners, 0); XCTAssertEqual(eventOwners, 0)
    XCTAssertEqual(maximumLoops, 1); XCTAssertEqual(maximumTimeOwners, 1)
    player = nil
    XCTAssertNil(probe, "Delayed callbacks must not retain the manager")
    timeCallbacks.removeAll(); eventCallbacks.removeAll(); ticks.removeAll(); seeks.removeAll()
    XCTAssertEqual(copies.count, 100)
    XCTAssertEqual(removals, copies)
    XCTAssertFalse(removals.contains(URL(fileURLWithPath: "/external/same.mov")))
  }

  @MainActor
  func testGeneratedMovieReadinessSeekEndReplayAndRetirement() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
    defer { try? FileManager.default.removeItem(at: url) }
    try await writeMovie(to: url)
    var manager: VideoPlayerManager? = VideoPlayerManager()
    weak var probe = manager
    let loaded = expectation(description: "real ready paused item")
    var observation: AnyCancellable? = manager!.$playbackState.filter { $0 == .paused }.prefix(1).sink { _ in loaded.fulfill() }
    manager!.loadVideo(from: url)
    await fulfillment(of: [loaded], timeout: 10)
    observation = nil
    XCTAssertEqual(manager!.duration, 1, accuracy: 0.05)
    let item = try XCTUnwrap(manager!.getPlayerItem())
    let layer = try XCTUnwrap(manager!.getPlayerLayer())
    XCTAssertEqual(item.status, .readyToPlay)
    XCTAssertEqual(item.outputs.count, 1)
    let sought = expectation(description: "real seek completion")
    observation = manager!.$playbackState.dropFirst().filter { $0 == .paused }.prefix(1).sink { _ in sought.fulfill() }
    manager!.seek(to: 0.5)
    await fulfillment(of: [sought], timeout: 5)
    observation = nil
    XCTAssertEqual(manager!.currentTime, 0.5, accuracy: 0.05)
    let ended = expectation(description: "real end notification")
    observation = manager!.$playbackState.filter { $0 == .ended }.prefix(1).sink { _ in ended.fulfill() }
    manager!.play()
    await fulfillment(of: [ended], timeout: 5)
    observation = nil
    XCTAssertFalse(manager!.isPlaying)
    let replayed = expectation(description: "real replay zero seek")
    observation = manager!.$playbackState.filter { $0 == .playing }.prefix(1).sink { _ in replayed.fulfill() }
    manager!.replay()
    await fulfillment(of: [replayed], timeout: 5)
    observation = nil
    XCTAssertLessThan(manager!.currentTime, 0.1)
    manager!.shutdown(); manager!.shutdown()
    XCTAssertNil(layer.player)
    XCTAssertTrue(item.outputs.isEmpty)
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "External original survives retirement")
    manager = nil
    XCTAssertNil(probe)
    withExtendedLifetime(observation) {}
  }

  private func writeMovie(to url: URL) async throws {
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64
    ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
      sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                   kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64])
    writer.add(input)
    XCTAssertTrue(writer.startWriting())
    writer.startSession(atSourceTime: .zero)
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      var index: Int64 = 0
      var finished = false
      input.requestMediaDataWhenReady(on: DispatchQueue(label: "test.synthetic-movie")) {
        guard !finished else { return }
        while input.isReadyForMoreMediaData && index < 30 {
          var buffer: CVPixelBuffer?
          let result = CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
          guard result == kCVReturnSuccess, let buffer else {
            finished = true; writer.cancelWriting()
            continuation.resume(throwing: NSError(domain: "SyntheticMovieBuffer", code: Int(result))); return
          }
          CVPixelBufferLockBaseAddress(buffer, [])
          memset(CVPixelBufferGetBaseAddress(buffer), Int32(index * 7), CVPixelBufferGetDataSize(buffer))
          CVPixelBufferUnlockBaseAddress(buffer, [])
          guard adaptor.append(buffer, withPresentationTime: CMTime(value: index, timescale: 30)) else {
            finished = true; writer.cancelWriting()
            continuation.resume(throwing: writer.error ?? NSError(domain: "SyntheticMovieWrite", code: 1)); return
          }
          index += 1
        }
        if index == 30 {
          finished = true
          input.markAsFinished()
          writer.endSession(atSourceTime: CMTime(value: 1, timescale: 1))
          writer.finishWriting {
            if writer.status == .completed { continuation.resume() }
            else { continuation.resume(throwing: writer.error ?? NSError(domain: "SyntheticMovieFinish", code: 1)) }
          }
        }
      }
    }
  }
  func testRetiredSessionFileSurvivesPendingSeekConsumer() {
    var removed: [URL] = []
    var completion: ((Bool) -> Void)?
    let importer = VideoImportManager(effects: .init(prepare: { _ in }, copy: { _, _ in },
      remove: { removed.append($0) }, state: { $0() }))
    let player = VideoPlayerManager(dependencies: .init(play: { true }, pause: {}, startLoop: {}, stopLoop: {},
      seek: { _, callback in completion = callback }))
    let request = player.beginReplacement()
    importer.begin(request: request) { player.acceptImport($1, request: $0) }
    importer.receiveSelection(request: request) { callback in
      callback(URL(fileURLWithPath: "/provider/clip.mov"), nil); return Progress()
    }
    player.seek(to: 4)
    player.shutdown()
    XCTAssertTrue(removed.isEmpty, "Retirement must not delete a still-consumed seek file")
    completion?(true)
    completion = nil
    XCTAssertEqual(removed.count, 1)
  }
  func testCandidatesRequireValidMetadataAndReadinessInEitherOrder() {
    for readyFirst in [false, true] {
      let f = CandidateEffects()
      f.player.loadVideo(from: URL(fileURLWithPath: "/candidate.mov"))
      if readyFirst { f.ready[0](.ready) } else { f.metadata[0](.success(.init(duration: 17))) }
      XCTAssertEqual(f.player.duration, 0)
      XCTAssertTrue(f.player.isLoading)
      f.player.play()
      XCTAssertFalse(f.player.isPlaying)
      if readyFirst { f.metadata[0](.success(.init(duration: 17))) } else { f.ready[0](.ready) }
      XCTAssertEqual(f.player.duration, 17)
      XCTAssertEqual(f.player.playbackState, .paused)
      XCTAssertFalse(f.player.isLoading)
      f.player.play()
      f.metadata[0](.success(.init(duration: 44))); f.ready[0](.failed)
      XCTAssertEqual(f.player.duration, 17)
      XCTAssertTrue(f.player.isPlaying, "Duplicate completion must not recommit or fail")
    }
  }

  func testSupersededMetadataReadinessAndErrorsCannotAlterNewCandidate() {
    for staleFirst in [false, true] {
      let f = CandidateEffects()
      f.load("A"); f.load("B")
      XCTAssertEqual(f.cancelled, 1)
      if staleFirst { f.metadata[0](.success(.init(duration: 99))); f.ready[0](.ready) }
      f.metadata[1](.success(.init(duration: 22))); f.ready[1](.ready)
      f.player.play()
      f.metadata[0](.failure(NSError(domain: "fixture", code: 1)))
      f.ready[0](.failed); f.metadata[0](.success(.init(duration: 99))); f.ready[0](.ready)
      XCTAssertEqual(f.player.duration, 22)
      XCTAssertTrue(f.player.isPlaying)
      XCTAssertNil(f.player.importMessage)
      XCTAssertFalse(f.player.isLoading)
    }
  }

  func testInvalidCandidateLeavesPriorSelectionPausedAndFirstFailureEmpty() {
    let invalid: [VideoPlayerManager.Metadata] = [
      .init(duration: 4, playable: false), .init(duration: 4, hasVideo: false),
      .init(duration: 0), .init(duration: -1), .init(duration: .infinity), .init(duration: .nan)
    ]
    for initial in [false, true] {
      for metadata in invalid {
        let f = CandidateEffects()
        if initial { f.load("original"); f.metadata[0](.success(.init(duration: 30))); f.ready[0](.ready); f.player.play() }
        f.load("invalid")
        f.metadata.last?(.success(metadata)); f.ready.last?(.ready)
        XCTAssertEqual(f.player.duration, initial ? 30 : 0)
        XCTAssertFalse(f.player.isLoading)
        XCTAssertFalse(f.player.isPlaying)
        XCTAssertNotNil(f.player.importMessage)
        f.player.play()
        XCTAssertEqual(f.player.isPlaying, initial)
      }
    }
  }

  func testReadinessFailureMetadataErrorCancelAndContextExitPreserveSelection() {
    for outcome in 0..<4 {
      let f = CandidateEffects()
      f.load("original"); f.metadata[0](.success(.init(duration: 30))); f.ready[0](.ready)
      f.player.play(); f.load("replacement")
      switch outcome {
      case 0: f.metadata[1](.success(.init(duration: 20))); f.ready[1](.failed)
      case 1: f.metadata[1](.failure(NSError(domain: "fixture", code: 1)))
      case 2: f.player.cancelReplacement()
      default: f.player.setContextActive(false)
      }
      f.metadata[1](.success(.init(duration: 20))); f.ready[1](.ready)
      XCTAssertEqual(f.player.duration, 30)
      XCTAssertFalse(f.player.isPlaying)
      XCTAssertFalse(f.player.isLoading)
      f.player.setContextActive(true); f.player.play()
      XCTAssertTrue(f.player.isPlaying)
    }
  }

  func testCandidateRechecksIdentityAfterStateDeliveryHop() {
    let f = CandidateEffects()
    f.load("A"); f.hold = true
    f.metadata[0](.success(.init(duration: 10))); f.ready[0](.ready)
    f.load("B")
    while !f.jobs.isEmpty { f.jobs.removeFirst()() }
    XCTAssertTrue(f.player.isLoading)
    XCTAssertEqual(f.player.duration, 0)
    f.hold = false
    f.metadata[1](.success(.init(duration: 20))); f.ready[1](.ready)
    XCTAssertEqual(f.player.duration, 20)
  }
  func testReentrantNewerReplacementWinsOlderLoadReturn() {
    var player: VideoPlayerManager!
    player = VideoPlayerManager(dependencies: .init(play: { true }, pause: {}, startLoop: {}, stopLoop: {}, load: { url in
      if url.lastPathComponent == "old.mov" {
        player.loadVideo(from: URL(fileURLWithPath: "/new.mov"))
        return 11
      }
      return 22
    }))
    player.loadVideo(from: URL(fileURLWithPath: "/old.mov"))
    XCTAssertEqual(player.duration, 22, "Only the latest candidate may publish metadata")
  }
  func testObserverAndTickCallbacksDoNotRetainManagerAfterOwnerExit() {
    var activeLoops = 0, activeObservers = 0
    var ticks: [() -> Void] = []
    var events: [(VideoPlayerManager.ItemEvent) -> Void] = []
    var manager: VideoPlayerManager? = VideoPlayerManager(dependencies: .init(
      play: { true }, pause: {}, startLoop: { activeLoops += 1 }, stopLoop: { activeLoops -= 1 },
      observeTicks: { callback in ticks.append(callback); return {} },
      observeEvents: { callback in
        events.append(callback); activeObservers += 1
        return { activeObservers -= 1 }
      }))
    weak var weakManager = manager
    manager?.loadVideo(from: URL(fileURLWithPath: "/fixture.mov"))
    manager?.play()
    XCTAssertEqual(activeLoops, 1)
    manager = nil
    XCTAssertNil(weakManager)
    XCTAssertEqual(activeLoops, 0)
    XCTAssertEqual(activeObservers, 0)
    ticks.forEach { $0() }
    events.forEach { $0(.ended) }
    XCTAssertEqual(activeLoops, 0)
  }

  func testReplayWaitsForZeroSuccessAndPauseExitOrNewSeekWins() {
    for action in 0..<3 {
      let f = PlayerEffects()
      f.load(); f.manager.play()
      f.position = CMTime(value: 30, timescale: 1); f.stopped = true
      f.events.last?(.ended)
      XCTAssertEqual(f.manager.playbackState, .ended)
      f.manager.replay()
      XCTAssertEqual(f.seeks[0].target, .zero)
      XCTAssertFalse(f.manager.isPlaying)
      switch action {
      case 0: f.manager.pause()
      case 1: f.manager.setContextActive(false)
      default: f.manager.seek(to: 12)
      }
      f.finish(0, true)
      XCTAssertFalse(f.manager.isPlaying)
      XCTAssertEqual(f.activeLoops, 0)
      if action == 2 {
        f.finish(1, true)
        XCTAssertTrue(f.manager.isPlaying)
        XCTAssertEqual(f.manager.currentTime, 12)
      }
    }
  }

  func testOldItemEventsAndRetiredRegistrationsCannotStopCurrentPlayback() {
    let f = PlayerEffects()
    f.load(); f.manager.play()
    let old = f.events[0]
    f.load(); f.manager.play()
    old(.ended); old(.failed)
    XCTAssertTrue(f.manager.isPlaying)
    XCTAssertEqual(f.activeLoops, 1)
    XCTAssertEqual(f.activeObservers, 1)
    f.manager.shutdown()
    XCTAssertEqual(f.activeLoops, 0)
    XCTAssertEqual(f.activeObservers, 0)
    f.events.last?(.ended)
    XCTAssertEqual(f.manager.playbackState, .empty)
  }

  func testAmbiguousNotificationUsesFreshStateAfterHopAndCurrentFailureIsRecoverable() {
    let f = PlayerEffects()
    f.load(); f.manager.play()
    f.holdState = true
    f.failed = true
    f.events.last?(.failed)
    f.failed = false
    f.position = CMTime(value: 5, timescale: 1)
    f.drainState()
    XCTAssertTrue(f.manager.isPlaying)
    f.holdState = false
    f.failed = true
    f.events.last?(.failed)
    XCTAssertFalse(f.manager.playRequested)
    XCTAssertEqual(f.activeLoops, 0)
    XCTAssertEqual(f.manager.playbackState, .failed("Playback failed. Tap Play to retry."))
    f.failed = false
    f.manager.play()
    XCTAssertFalse(f.manager.isPlaying)
    XCTAssertEqual(CMTimeGetSeconds(f.seeks[0].target), 5)
    f.finish(0, true)
    XCTAssertTrue(f.manager.isPlaying)
  }

  func testArmingReconcilesAnAlreadyCurrentFailure() {
    let f = PlayerEffects()
    f.load(); f.failed = true
    f.manager.play()
    XCTAssertFalse(f.manager.isPlaying)
    XCTAssertFalse(f.manager.playRequested)
    XCTAssertEqual(f.activeLoops, 0)
    XCTAssertEqual(f.activeObservers, 0)
  }

  func testRepeatedReplayAndPlayKeepSingleLoopAndOwner() {
    let f = PlayerEffects()
    f.load(); f.manager.play()
    for index in 0..<50 {
      f.manager.replay(); f.manager.play()
      XCTAssertEqual(f.activeLoops, 0)
      XCTAssertEqual(f.activeObservers, 0)
      f.finish(index, true)
      XCTAssertEqual(f.activeLoops, 1)
      XCTAssertEqual(f.activeObservers, 1)
    }
    XCTAssertEqual(f.maximumLoops, 1)
    XCTAssertEqual(f.maximumObservers, 1)
  }

  func testCurrentEndClosesPlayIntentAndExtraction() {
    let f = PlayerEffects()
    f.load(); f.manager.play()
    f.position = CMTime(value: 30, timescale: 1)
    f.stopped = true
    f.events.last?(.ended)
    XCTAssertFalse(f.manager.playRequested, "Current end retires requested playback")
    XCTAssertFalse(f.manager.isPlaying, "Current end closes extraction")
    XCTAssertEqual(f.activeLoops, 0)
  }
  func testOnlyLatestSuccessfulSeekMayResume_InEveryCompletionOrder() {
    for oldFirst in [false, true] {
      for oldSuccess in [false, true] {
        let f = PlayerEffects()
        f.load(); f.manager.play()
        f.manager.seek(to: 4); f.manager.seek(to: 8)
        XCTAssertEqual(f.activeLoops, 0)
        if oldFirst { f.finish(0, oldSuccess) }
        XCTAssertFalse(f.manager.isPlaying)
        f.finish(1, true)
        XCTAssertTrue(f.manager.isPlaying)
        if !oldFirst { f.finish(0, oldSuccess) }
        f.seeks[1].completion(false) // duplicate current callback is retired too
        XCTAssertTrue(f.manager.isPlaying)
        XCTAssertEqual(f.manager.currentTime, 8)
        XCTAssertEqual(f.activeLoops, 1)
        XCTAssertEqual(f.maximumLoops, 1)
      }
    }
  }

  func testPauseAndContextExitWinLateSeekSuccess() {
    for contextExit in [false, true] {
      let f = PlayerEffects()
      f.load(); f.manager.play(); f.manager.seek(to: 6)
      if contextExit { f.manager.setContextActive(false) } else { f.manager.pause() }
      f.finish(0, true)
      XCTAssertEqual(f.manager.currentTime, 6)
      XCTAssertFalse(f.manager.isPlaying)
      XCTAssertFalse(f.manager.playRequested)
      XCTAssertEqual(f.activeLoops, 0)
      f.manager.setContextActive(true)
      XCTAssertFalse(f.manager.isPlaying)
      f.manager.play()
      XCTAssertTrue(f.manager.isPlaying)
    }
  }

  func testPlayDuringSeekRecordsIntentWithoutOpeningLoop() {
    let f = PlayerEffects()
    f.load(); f.manager.seek(to: 9); f.manager.play()
    XCTAssertTrue(f.manager.playRequested)
    XCTAssertFalse(f.manager.isPlaying)
    XCTAssertEqual(f.activeLoops, 0)
    f.finish(0, true)
    XCTAssertTrue(f.manager.isPlaying)
    XCTAssertEqual(f.activeLoops, 1)
  }

  func testFailedSeekRequiresSuccessfulRetryBeforePlay() {
    let f = PlayerEffects()
    f.load(); f.manager.play(); f.manager.seek(to: 7)
    f.finish(0, false)
    XCTAssertFalse(f.manager.playRequested)
    XCTAssertFalse(f.manager.isPlaying)
    XCTAssertEqual(f.manager.playbackState, .failed("Seek failed. Tap Play to retry."))
    f.manager.play()
    XCTAssertEqual(f.seeks.count, 2)
    XCTAssertFalse(f.manager.isPlaying)
    f.finish(1, true)
    XCTAssertTrue(f.manager.isPlaying)
    XCTAssertEqual(f.manager.currentTime, 7)
  }

  func testInvalidSeekValuesNeverReachBackendAndValidValuesClamp() {
    let f = PlayerEffects()
    f.load()
    for target in [Double.nan, .infinity, -.infinity] { f.manager.seek(to: target) }
    XCTAssertEqual(f.seeks.count, 0)
    for duration in [0, -1, Double.nan, .infinity] {
      f.manager.duration = duration
      f.manager.seek(to: 1)
    }
    XCTAssertEqual(f.seeks.count, 0)
    f.manager.duration = Double.greatestFiniteMagnitude
    f.manager.seek(to: Double.greatestFiniteMagnitude)
    XCTAssertEqual(f.seeks.count, 0, "A finite Double may overflow CMTime")
    f.manager.duration = 30
    f.manager.seek(to: -4); f.manager.seek(to: 40)
    XCTAssertEqual(f.seeks.map { CMTimeGetSeconds($0.target) }, [0, 30])
  }

  func testInvalidBackendPositionCannotAuthorizeSuccessfulSeek() {
    let f = PlayerEffects()
    f.load(); f.manager.play(); f.manager.seek(to: 2)
    f.position = .indefinite
    f.seeks[0].completion(true)
    XCTAssertFalse(f.manager.isPlaying)
    XCTAssertFalse(f.manager.playRequested)
    XCTAssertEqual(f.activeLoops, 0)
  }

  func testOldItemSeekAndTimeCallbacksCannotChangeNewSelection() {
    let f = PlayerEffects()
    f.load(); f.manager.play(); f.manager.seek(to: 7)
    let oldTime = f.timeCallbacks[0]
    f.load(); f.manager.play()
    f.position = CMTime(value: 3, timescale: 1)
    f.timeCallbacks[1](f.position)
    oldTime(CMTime(value: 20, timescale: 1))
    f.seeks[0].completion(true)
    XCTAssertEqual(f.manager.currentTime, 3)
    XCTAssertTrue(f.manager.isPlaying)
    XCTAssertEqual(f.activeLoops, 1)
  }

  func testCallbacksCheckOwnershipAfterStateExecutorHop() {
    let f = PlayerEffects()
    f.load(); f.manager.play(); f.manager.seek(to: 4)
    f.holdState = true
    f.finish(0, true)
    f.manager.seek(to: 9)
    f.drainState()
    XCTAssertEqual(f.manager.playbackState, .seeking)
    XCTAssertFalse(f.manager.isPlaying)
    f.holdState = false
    f.finish(1, true)
    XCTAssertEqual(f.manager.currentTime, 9)
    XCTAssertTrue(f.manager.isPlaying)
  }

  func testRepeatedControlsOwnOneLoopAndRetireEachRegistration() {
    let f = PlayerEffects()
    f.load()
    for _ in 0..<100 { f.manager.play() }
    XCTAssertEqual(f.activeLoops, 1)
    for index in 0..<20 {
      f.manager.seek(to: Double(index))
      f.finish(index, true)
      f.manager.play()
    }
    f.manager.pause(); f.manager.pause()
    XCTAssertEqual(f.activeLoops, 0)
    XCTAssertEqual(f.maximumLoops, 1)
    XCTAssertEqual(f.retiredTicks, 21)
  }
}

private struct RetirementReader: VideoPlayerManager.FrameOutputReading {
  let check: () -> Void
  func hasNewPixelBuffer(forItemTime time: CMTime) -> Bool { check(); return false }
  func copyFrame(forItemTime time: CMTime) -> (CVPixelBuffer, CMTime)? { nil }
}

final class CandidateEffects {
  var metadata: [(Result<VideoPlayerManager.Metadata, Error>) -> Void] = []
  var ready: [(VideoPlayerManager.Readiness) -> Void] = []
  var cancelled = 0
  var hold = false
  var jobs: [() -> Void] = []
  lazy var player = VideoPlayerManager(dependencies: .init(play: { true }, pause: {}, startLoop: {}, stopLoop: {},
    state: { [weak self] job in if self?.hold == true { self?.jobs.append(job) } else { job() } },
    prepare: { [weak self] _, metadata, ready in
      self?.metadata.append(metadata); self?.ready.append(ready)
      return { [weak self] in self?.cancelled += 1 }
    }))
  func load(_ name: String) { player.loadVideo(from: URL(fileURLWithPath: "/" + name + ".mov")) }
}

final class PlayerEffects {
  struct Seek { let target: CMTime; let completion: (Bool) -> Void }
  var seeks: [Seek] = []
  var position = CMTime.zero
  var activeLoops = 0
  var maximumLoops = 0
  var retiredTicks = 0
  var ticks: [() -> Void] = []
  var timeCallbacks: [(CMTime) -> Void] = []
  var holdState = false
  var stopped = false
  var failed = false
  var events: [(VideoPlayerManager.ItemEvent) -> Void] = []
  var activeObservers = 0
  var maximumObservers = 0
  var stateJobs: [() -> Void] = []
  lazy var manager = VideoPlayerManager(dependencies: .init(
    play: { [weak self] in self?.stopped = false; return true }, pause: {}, startLoop: { [weak self] in
      guard let self else { return }
      activeLoops += 1; maximumLoops = max(maximumLoops, activeLoops)
    }, stopLoop: { [weak self] in self?.activeLoops -= 1 },
    seek: { [weak self] in self?.seeks.append(.init(target: $0, completion: $1)) },
    currentTime: { [weak self] in self?.position ?? .invalid }, state: { [weak self] job in
      if self?.holdState == true { self?.stateJobs.append(job) } else { job() }
    }, observeTicks: { [weak self] callback in
      self?.ticks.append(callback)
      return { [weak self] in self?.retiredTicks += 1 }
    }, observeTime: { [weak self] callback in self?.timeCallbacks.append(callback); return {} },
    observeEvents: { [weak self] callback in
      if let self {
        events.append(callback); activeObservers += 1
        maximumObservers = max(maximumObservers, activeObservers)
      }
      return { [weak self] in self?.activeObservers -= 1 }
    },
    snapshot: { [weak self] in .init(position: self?.position ?? .invalid,
      stopped: self?.stopped ?? true, failed: self?.failed ?? false) }))
  func load() { position = .zero; manager.loadVideo(from: URL(fileURLWithPath: "/fixture.mov")) }
  func finish(_ index: Int, _ success: Bool) {
    if success { position = seeks[index].target }
    seeks[index].completion(success)
  }
  func drainState() { while !stateJobs.isEmpty { stateJobs.removeFirst()() } }
}
