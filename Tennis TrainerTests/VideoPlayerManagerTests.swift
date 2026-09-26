import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class VideoPlayerManagerTests: XCTestCase {
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
  var stateJobs: [() -> Void] = []
  lazy var manager = VideoPlayerManager(dependencies: .init(
    play: { true }, pause: {}, startLoop: { [weak self] in
      guard let self else { return }
      activeLoops += 1; maximumLoops = max(maximumLoops, activeLoops)
    }, stopLoop: { [weak self] in self?.activeLoops -= 1 },
    seek: { [weak self] in self?.seeks.append(.init(target: $0, completion: $1)) },
    currentTime: { [weak self] in self?.position ?? .invalid }, state: { [weak self] job in
      if self?.holdState == true { self?.stateJobs.append(job) } else { job() }
    }, observeTicks: { [weak self] callback in
      self?.ticks.append(callback)
      return { [weak self] in self?.retiredTicks += 1 }
    }, observeTime: { [weak self] callback in self?.timeCallbacks.append(callback); return {} }))
  func load() { position = .zero; manager.loadVideo(from: URL(fileURLWithPath: "/fixture.mov")) }
  func finish(_ index: Int, _ success: Bool) {
    if success { position = seeks[index].target }
    seeks[index].completion(success)
  }
  func drainState() { while !stateJobs.isEmpty { stateJobs.removeFirst()() } }
}
