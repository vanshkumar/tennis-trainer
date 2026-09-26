import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class VideoPlayerManagerTests: XCTestCase {
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
