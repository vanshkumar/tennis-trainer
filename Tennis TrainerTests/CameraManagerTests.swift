import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class CameraManagerTests: XCTestCase {
  func testStartDoesNotOpenCaptureWithoutPermission() {
    var starts = 0
    let camera = CameraManager(dependencies: .init(
      session: { $0() }, drain: { $0() }, state: { $0() },
      stop: {}, attach: { _ in }, start: { starts += 1; return true }))
    XCTAssertFalse(camera.hasPermission)
    camera.startCapture()
    XCTAssertEqual(starts, 0, "Start must query authorization before opening capture")
    XCTAssertFalse(camera.isRecording)
  }
}
