import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class VideoImportManagerTests: XCTestCase {
  func testFailedReplacementPreservesPreviousPausedSelection() {
    var valid = true
    let player = VideoPlayerManager(dependencies: .init(play: { true }, pause: {},
      startLoop: {}, stopLoop: {}, load: { _ in valid ? 30 : nil }))
    player.loadVideo(from: URL(fileURLWithPath: "/original.mov"))
    player.play()
    valid = false
    player.loadVideo(from: URL(fileURLWithPath: "/invalid.mov"))
    XCTAssertEqual(player.duration, 30, "Failed replacement must preserve the usable selection")
    XCTAssertFalse(player.isPlaying)
    player.play()
    XCTAssertTrue(player.isPlaying, "The preserved selection remains playable")
  }
}
