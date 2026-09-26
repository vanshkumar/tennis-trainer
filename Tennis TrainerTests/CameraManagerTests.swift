import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class CameraManagerTests: XCTestCase {
  func testInjectedAndDefaultTestManagersNeverAllocateCaptureForPreviewOrStop() {
    let injected = CameraManager(dependencies: .init(session: { $0() }, drain: { $0() }, state: { $0() },
      stop: {}, attach: { _ in }, start: { false }, authorization: { .denied }))
    for camera in [injected, CameraManager()] {
      XCTAssertNil(camera.getPreviewLayer().session)
      camera.stopCapture()
      camera.setContextActive(false)
      XCTAssertNil(camera.getPreviewLayer().session, "Preview access must not allocate a real backend for injected tests")
    }
  }

  func testInitializedBackendKeepsPreviewAndQueuedLifecycleOnOneSession() {
    let backend = CameraManager.CaptureBackend()
    let session = backend.session
    var jobs: [() -> Void] = []
    var owners: [AVCaptureSession] = []
    var status: AVAuthorizationStatus = .denied
    let camera = CameraManager(dependencies: .init(
      session: { jobs.append($0) }, drain: { $0() }, state: { $0() },
      stop: { owners.append(backend.session) }, attach: { _ in },
      start: { owners.append(backend.session); return true }, authorization: { status },
      configure: { owners.append(backend.session) }), backend: backend)
    XCTAssertEqual(jobs.count, 1, "Denied initialization queues Stop before any preview")
    let preview = camera.getPreviewLayer()
    XCTAssertTrue(preview.session === session)
    while !jobs.isEmpty { jobs.removeFirst()() }
    status = .authorized
    camera.startCapture()
    while !jobs.isEmpty { jobs.removeFirst()() }
    camera.stopCapture()
    while !jobs.isEmpty { jobs.removeFirst()() }
    XCTAssertEqual(owners.count, 5, "Initial Stop, restart Stop, configure, start and final Stop")
    XCTAssertTrue(owners.allSatisfy { $0 === session })
    XCTAssertTrue(camera.getPreviewLayer() === preview)
    XCTAssertTrue(preview.session === session)
    XCTAssertTrue(session.inputs.isEmpty, "Identity test never configures physical hardware")
    XCTAssertFalse(session.isRunning)
  }

  func testConfigurationIsIdempotentAndRunningWaitsForCurrentBackendSnapshot() {
    let f = SessionFixture()
    f.camera.startCapture()
    XCTAssertEqual(f.camera.captureState, .configuring)
    XCTAssertTrue(f.camera.captureRequested)
    XCTAssertFalse(f.camera.isRecording)
    f.flushSession()
    f.stateJobs.removeFirst()()
    XCTAssertEqual(f.camera.captureState, .starting)
    XCTAssertFalse(f.camera.isRecording)
    f.flush()
    XCTAssertEqual(f.camera.captureState, .running)
    f.camera.startCapture()
    XCTAssertEqual(f.starts, 1)
    f.camera.stopCapture()
    f.camera.startCapture()
    f.flush()
    XCTAssertEqual(f.configurations, 1)
    XCTAssertEqual(f.starts, 2)
    XCTAssertEqual(f.removals, 1)
  }

  func testBackendStoppingBeforeStartPublicationNeverReportsRunning() {
    let f = SessionFixture()
    f.camera.startCapture()
    f.flushSession()
    f.running = false
    f.flush()
    XCTAssertFalse(f.camera.isRecording)
    XCTAssertTrue(f.camera.captureState.canRetry)
  }

  func testStopDuringConfigurationStartAndPublicationWinsAndFreshRetryWorks() {
    for stage in 0...2 {
      let f = SessionFixture()
      if stage == 0 { f.onConfigure = { f.camera.stopCapture() } }
      if stage == 1 { f.onStart = { f.camera.stopCapture() } }
      f.camera.startCapture()
      f.flushSession()
      if stage == 2 { f.camera.stopCapture() }
      f.flush()
      XCTAssertEqual(f.camera.captureState, .stopped)
      XCTAssertFalse(f.camera.captureRequested)
      XCTAssertFalse(f.running, "Late physical startup must be stopped")
      XCTAssertFalse(f.attached)
      f.onConfigure = nil
      f.onStart = nil
      f.camera.startCapture()
      f.flush()
      XCTAssertTrue(f.camera.isRecording)
    }
  }

  func testConfigurationErrorsFailClosedAndRetryReconfiguresOnce() {
    for error in [CameraManager.ConfigurationError.missingCamera, .inputUnavailable, .outputUnavailable] {
      let f = SessionFixture()
      f.configurationError = error
      f.camera.startCapture()
      f.flush()
      XCTAssertTrue(f.camera.captureState.canRetry)
      XCTAssertEqual(f.starts, 0)
      XCTAssertFalse(f.attached)
      f.configurationError = nil
      f.camera.startCapture()
      f.flush()
      XCTAssertEqual(f.configurations, 2)
      XCTAssertTrue(f.camera.isRecording)
    }
  }

  func testCurrentInterruptionRecoversOnceAndRetryResetsBudget() {
    let f = SessionFixture()
    f.start()
    f.interrupted = true
    f.send(.interrupted)
    XCTAssertEqual(f.camera.captureState, .interrupted)
    XCTAssertFalse(f.camera.isRecording)
    XCTAssertTrue(f.camera.captureRequested)
    f.interrupted = false
    f.send(.interruptionEnded)
    XCTAssertEqual(f.camera.captureState, .recovering)
    f.flush()
    XCTAssertTrue(f.camera.isRecording)
    XCTAssertEqual(f.starts, 2)
    f.running = false
    f.send(.runtimeError(recoverable: true))
    f.flush()
    XCTAssertTrue(f.camera.captureState.canRetry)
    XCTAssertEqual(f.starts, 2, "Automatic recovery is bounded per explicit intent")
    f.start()
    XCTAssertTrue(f.camera.isRecording)
    f.running = false
    f.send(.runtimeError(recoverable: true))
    f.flush()
    XCTAssertEqual(f.starts, 4)
    XCTAssertTrue(f.camera.isRecording)
  }

  func testStopDuringRecoveryAndOldEventsCannotOverrideNewSession() {
    let f = SessionFixture()
    f.start()
    let oldObserver = f.observers[0]
    f.interrupted = true
    f.send(.interrupted)
    f.interrupted = false
    f.send(.interruptionEnded)
    XCTAssertEqual(f.camera.captureState, .recovering)
    f.camera.stopCapture()
    f.flush()
    XCTAssertEqual(f.starts, 1)
    XCTAssertFalse(f.running)
    f.start()
    for event in [CameraManager.SessionEvent.started, .stopped, .interrupted,
                  .interruptionEnded, .runtimeError(recoverable: false)] {
      oldObserver(event)
    }
    f.flush()
    XCTAssertTrue(f.camera.isRecording)
    XCTAssertEqual(f.starts, 2)
    f.running = false
    f.send(.runtimeError(recoverable: false))
    f.flush()
    XCTAssertTrue(f.camera.captureState.canRetry, "A current fatal error still works")
  }

  func testEventsRequeryActualStateAndAuthorizationAfterStateDispatch() {
    let f = SessionFixture()
    f.start()
    f.interrupted = true
    f.observers.last?(.interrupted)
    f.interrupted = false
    f.flush()
    XCTAssertTrue(f.camera.isRecording, "Historical interruption must not overwrite fresh backend")
    f.observers.last?(.runtimeError(recoverable: true))
    f.authorization = .denied
    f.flush()
    XCTAssertFalse(f.camera.hasPermission)
    XCTAssertFalse(f.camera.captureRequested)
    XCTAssertFalse(f.running)
    XCTAssertEqual(f.starts, 1)
  }

  func testCurrentStopNotificationFailsWhileHistoricalStopDoesNot() {
    let f = SessionFixture()
    f.start()
    f.send(.stopped)
    XCTAssertTrue(f.camera.isRecording)
    f.running = false
    f.send(.stopped)
    f.flush()
    XCTAssertTrue(f.camera.captureState.canRetry)
  }

  func testAuthorizationResetToUndeterminedClosesAnExistingSession() {
    let f = SessionFixture()
    f.start()
    f.authorization = .notDetermined
    f.camera.refreshAuthorization()
    f.flush()
    XCTAssertFalse(f.camera.captureRequested)
    XCTAssertFalse(f.running)
    XCTAssertEqual(f.camera.accessState, .undetermined)
    XCTAssertEqual(f.camera.captureState, .stopped)
  }

  func testOwnerExitRemovesObserversAndHeldEventsDoNotRetainManager() {
    var held: ((CameraManager.SessionEvent) -> Void)?
    var removals = 0
    var camera: CameraManager? = CameraManager(dependencies: .init(
      session: { $0() }, drain: { $0() }, state: { $0() }, stop: {},
      attach: { _ in }, start: { true }, snapshot: { .init(running: true) },
      observe: { callback in held = callback; return { removals += 1 } }))
    weak var weakCamera = camera
    camera?.startCapture()
    camera = nil
    XCTAssertNil(weakCamera)
    XCTAssertEqual(removals, 1)
    held?(.interruptionEnded)
  }

  func testFailedStartRetiresIntentSoExplicitRetryCanStartAgain() {
    var attempts = 0
    let camera = CameraManager(dependencies: .init(
      session: { $0() }, drain: { $0() }, state: { $0() },
      stop: {}, attach: { _ in }, start: { attempts += 1; return attempts > 1 }))
    camera.startCapture()
    XCTAssertFalse(camera.isRecording)
    XCTAssertFalse(camera.captureRequested, "A failed startup must offer a fresh Retry intent")
    camera.startCapture()
    XCTAssertEqual(attempts, 2)
    XCTAssertTrue(camera.isRecording)
  }

  func testStartDoesNotOpenCaptureWithoutPermission() {
    var starts = 0
    let camera = CameraManager(dependencies: .init(
      session: { $0() }, drain: { $0() }, state: { $0() },
      stop: {}, attach: { _ in }, start: { starts += 1; return true }, authorization: { .denied }))
    XCTAssertFalse(camera.hasPermission)
    camera.startCapture()
    XCTAssertEqual(starts, 0, "Start must query authorization before opening capture")
    XCTAssertFalse(camera.isRecording)
  }

  func testRequestCoalescesAndGrantDoesNotCreateCaptureIntent() {
    let fixture = PermissionFixture(.notDetermined)
    XCTAssertEqual(fixture.camera.accessState, .undetermined)
    fixture.camera.requestAccess()
    fixture.camera.requestAccess()
    XCTAssertEqual(fixture.requests.count, 1)
    XCTAssertEqual(fixture.camera.accessState, .requesting)
    fixture.status = .authorized
    fixture.requests[0](true)
    fixture.flush()
    XCTAssertEqual(fixture.camera.accessState, .authorized)
    XCTAssertFalse(fixture.camera.captureRequested)
    XCTAssertEqual(fixture.starts, 0)
    fixture.camera.startCapture()
    fixture.flush()
    XCTAssertEqual(fixture.starts, 1)
    XCTAssertTrue(fixture.camera.isRecording)
  }

  func testDeniedOffersSettingsAndRestrictedNeverRequestsOrOpensSettings() {
    for status in [AVAuthorizationStatus.denied, .restricted] {
      let fixture = PermissionFixture(status)
      fixture.camera.requestAccess()
      fixture.camera.openSettings()
      fixture.camera.startCapture()
      XCTAssertEqual(fixture.requests.count, 0)
      XCTAssertEqual(fixture.settings, status == .denied ? 1 : 0)
      XCTAssertEqual(fixture.starts, 0)
      XCTAssertFalse(fixture.camera.captureRequested)
      XCTAssertEqual(fixture.camera.accessState, status == .denied ? .denied : .restricted)
    }
  }

  func testSettingsReturnRequeriesGrantAndRevocationWithoutImplicitStart() {
    let fixture = PermissionFixture(.denied)
    fixture.camera.openSettings()
    fixture.camera.setContextActive(false)
    fixture.status = .authorized
    fixture.camera.setContextActive(true)
    XCTAssertTrue(fixture.camera.hasPermission)
    XCTAssertEqual(fixture.starts, 0)
    fixture.camera.startCapture()
    fixture.flush()
    XCTAssertTrue(fixture.camera.isRecording)
    fixture.status = .denied
    fixture.camera.refreshAuthorization()
    XCTAssertFalse(fixture.camera.hasPermission)
    XCTAssertFalse(fixture.camera.isRecording)
    XCTAssertFalse(fixture.camera.captureRequested)
    fixture.status = .authorized
    fixture.camera.refreshAuthorization()
    fixture.flush()
    XCTAssertEqual(fixture.starts, 1)
  }

  func testStopAndContextExitWinOverHeldGrantAndFreshStartWorks() {
    for exitContext in [false, true] {
      let fixture = PermissionFixture(.notDetermined)
      fixture.camera.startCapture()
      XCTAssertTrue(fixture.camera.captureRequested)
      XCTAssertEqual(fixture.requests.count, 1)
      if exitContext { fixture.camera.setContextActive(false) }
      else { fixture.camera.stopCapture() }
      fixture.status = .authorized
      fixture.requests[0](true)
      fixture.flush()
      XCTAssertEqual(fixture.starts, 0)
      XCTAssertFalse(fixture.camera.captureRequested)
      XCTAssertFalse(fixture.camera.isRecording)
      fixture.camera.setContextActive(true)
      fixture.camera.startCapture()
      fixture.flush()
      XCTAssertEqual(fixture.starts, 1)
      XCTAssertTrue(fixture.camera.isRecording)
    }
  }

  func testGrantResumesOnlyExplicitCurrentWaitingStart() {
    let fixture = PermissionFixture(.notDetermined)
    fixture.camera.startCapture()
    fixture.camera.stopCapture()
    fixture.camera.startCapture()
    XCTAssertEqual(fixture.requests.count, 1)
    fixture.status = .authorized
    fixture.requests[0](true)
    fixture.flush()
    XCTAssertEqual(fixture.starts, 1)
    XCTAssertTrue(fixture.camera.isRecording)
  }

  func testCallbackBooleanCannotOverrideRevocationBeforeStateDelivery() {
    let fixture = PermissionFixture(.notDetermined)
    fixture.camera.startCapture()
    fixture.status = .authorized
    fixture.requests[0](true)
    fixture.status = .denied
    fixture.flush()
    XCTAssertEqual(fixture.camera.accessState, .denied)
    XCTAssertFalse(fixture.camera.captureRequested)
    XCTAssertEqual(fixture.starts, 0)
  }

  func testDuplicateOldPermissionResultCannotOwnNewRequest() {
    let fixture = PermissionFixture(.notDetermined)
    fixture.camera.requestAccess()
    fixture.requests[0](false)
    fixture.flush()
    fixture.camera.requestAccess()
    XCTAssertEqual(fixture.requests.count, 2)
    fixture.requests[0](true)
    fixture.flush()
    XCTAssertEqual(fixture.camera.accessState, .requesting)
    fixture.status = .authorized
    fixture.requests[1](true)
    fixture.flush()
    XCTAssertTrue(fixture.camera.hasPermission)
    XCTAssertEqual(fixture.starts, 0)
  }

  func testRevocationBeforeSessionStartAndBeforePublicationClosesCapture() {
    for beforeSession in [true, false] {
      let fixture = PermissionFixture(.authorized)
      fixture.camera.startCapture()
      if !beforeSession { fixture.flushSession() }
      fixture.status = .denied
      fixture.flush()
      XCTAssertFalse(fixture.camera.isRecording)
      XCTAssertFalse(fixture.camera.captureRequested)
      XCTAssertEqual(fixture.starts, beforeSession ? 0 : 1)
    }
  }

  func testHeldAuthorizationDoesNotRetainManager() {
    var completion: ((Bool) -> Void)?
    var camera: CameraManager? = CameraManager(dependencies: .init(
      session: { $0() }, drain: { $0() }, state: { $0() }, stop: {},
      attach: { _ in }, start: { false }, authorization: { .notDetermined },
      requestAuthorization: { completion = $0 }))
    weak var weakCamera = camera
    camera?.requestAccess()
    camera = nil
    XCTAssertNil(weakCamera)
    completion?(true)
  }
}

private final class SessionFixture {
  var sessionJobs: [() -> Void] = []
  var stateJobs: [() -> Void] = []
  var observers: [(CameraManager.SessionEvent) -> Void] = []
  var configurations = 0
  var starts = 0
  var removals = 0
  var running = false
  var interrupted = false
  var attached = false
  var authorization: AVAuthorizationStatus = .authorized
  var configurationError: CameraManager.ConfigurationError?
  var onConfigure: (() -> Void)?
  var onStart: (() -> Void)?
  lazy var camera = CameraManager(dependencies: .init(
    session: { [unowned self] in sessionJobs.append($0) }, drain: { $0() },
    state: { [unowned self] in stateJobs.append($0) },
    stop: { [unowned self] in running = false }, attach: { [unowned self] in attached = $0 },
    start: { [unowned self] in starts += 1; onStart?(); running = true; return true },
    authorization: { [unowned self] in authorization },
    configure: { [unowned self] in
      configurations += 1
      onConfigure?()
      if let configurationError { throw configurationError }
    }, snapshot: { [unowned self] in .init(running: running, interrupted: interrupted) },
    observe: { [unowned self] callback in
      observers.append(callback)
      return { [weak self] in self?.removals += 1 }
    }))
  func start() { camera.startCapture(); flush() }
  func send(_ event: CameraManager.SessionEvent) {
    observers.last?(event)
    while !stateJobs.isEmpty { stateJobs.removeFirst()() }
  }
  func flushSession() { while !sessionJobs.isEmpty { sessionJobs.removeFirst()() } }
  func flush() {
    while !sessionJobs.isEmpty || !stateJobs.isEmpty {
      flushSession()
      while !stateJobs.isEmpty { stateJobs.removeFirst()() }
    }
  }
}

private final class PermissionFixture {
  var status: AVAuthorizationStatus
  var requests: [(Bool) -> Void] = []
  var starts = 0
  var settings = 0
  var sessionJobs: [() -> Void] = []
  var stateJobs: [() -> Void] = []
  lazy var camera = CameraManager(dependencies: .init(
    session: { [unowned self] in sessionJobs.append($0) }, drain: { $0() },
    state: { [unowned self] in stateJobs.append($0) }, stop: {}, attach: { _ in },
    start: { [unowned self] in starts += 1; return true },
    authorization: { [unowned self] in status },
    requestAuthorization: { [unowned self] in requests.append($0) },
    openSettings: { [unowned self] in settings += 1 }))

  init(_ status: AVAuthorizationStatus) { self.status = status }

  func flushSession() {
    while !sessionJobs.isEmpty { sessionJobs.removeFirst()() }
  }

  func flush() {
    while !sessionJobs.isEmpty || !stateJobs.isEmpty {
      flushSession()
      while !stateJobs.isEmpty { stateJobs.removeFirst()() }
    }
  }
}
