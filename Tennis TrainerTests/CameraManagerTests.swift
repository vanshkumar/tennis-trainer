import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class CameraManagerTests: XCTestCase {
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
