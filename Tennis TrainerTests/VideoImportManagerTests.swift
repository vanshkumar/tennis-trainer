import XCTest
import AVFoundation
@testable import Tennis_Trainer

final class VideoImportManagerTests: XCTestCase {
  func testPickerDismissalCancelsOnlyBeforeASelection() {
    let importer = VideoImportManager(effects: .init(prepare: { _ in }, copy: { _, _ in }, remove: { _ in }, state: { $0() }))
    var cancellations = 0, selections = 0
    let empty = UUID()
    importer.begin(request: empty) { _, result in if case .cancelled = result { cancellations += 1 } }
    importer.pickerDismissed(request: empty)
    XCTAssertEqual(cancellations, 1)
    let selected = UUID()
    var provider: ((URL?, Error?) -> Void)?
    importer.begin(request: selected) { _, result in if case .selected = result { selections += 1 } }
    importer.receiveSelection(request: selected) { provider = $0; return Progress() }
    importer.pickerDismissed(request: selected)
    XCTAssertTrue(importer.isImporting)
    provider?(URL(fileURLWithPath: "/provider/movie.mov"), nil)
    XCTAssertEqual(selections, 1)
    XCTAssertEqual(cancellations, 1)
  }
  func testDestinationCollisionFailureNeverRemovesExistingFile() {
    var removals = 0
    let importer = VideoImportManager(effects: .init(prepare: { _ in }, copy: { _, _ in
      throw CocoaError(.fileWriteFileExists)
    }, remove: { _ in removals += 1 }, state: { $0() }))
    let request = UUID()
    importer.begin(request: request) { _, _ in }
    importer.receiveSelection(request: request) { callback in
      callback(URL(fileURLWithPath: "/provider/movie.mov"), nil); return Progress()
    }
    XCTAssertEqual(removals, 0)
  }
  func testActualCopiesPreserveExternalAndUnknownLegacyFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let original = root.appendingPathComponent("original.mov")
    let legacy = root.appendingPathComponent("legacy.mov")
    try Data([1, 2, 3]).write(to: original)
    try Data([4, 5]).write(to: legacy)
    let importer = VideoImportManager(effects: .init(directory: root.appendingPathComponent("owned"), state: { $0() }))
    var handle: VideoImportManager.MediaHandle?
    let request = UUID()
    importer.begin(request: request) { _, result in if case .selected(let media) = result { handle = media } }
    importer.receiveSelection(request: request) { callback in callback(original, nil); return Progress() }
    let copied = try XCTUnwrap(handle?.url)
    XCTAssertEqual(try Data(contentsOf: copied), Data([1, 2, 3]))
    handle = nil
    XCTAssertFalse(FileManager.default.fileExists(atPath: copied.path))
    XCTAssertEqual(try Data(contentsOf: original), Data([1, 2, 3]))
    XCTAssertEqual(try Data(contentsOf: legacy), Data([4, 5]))
  }
  func testCancelledMetadataConsumerKeepsLeaseUntilActualCompletion() {
    var removed: [URL] = []
    let importer = VideoImportManager(effects: .init(prepare: { _ in }, copy: { _, _ in },
      remove: { removed.append($0) }, state: { $0() }))
    var held: ((Result<VideoPlayerManager.Metadata, Error>) -> Void)?
    var cancellations = 0
    let player = VideoPlayerManager(dependencies: .init(play: { true }, pause: {}, startLoop: {}, stopLoop: {},
      prepare: { _, metadata, _ in held = metadata; return { cancellations += 1 } }))
    let request = player.beginReplacement()
    importer.begin(request: request) { player.acceptImport($1, request: $0) }
    importer.receiveSelection(request: request) { completion in
      completion(URL(fileURLWithPath: "/original.mov"), nil); return Progress()
    }
    player.cancelReplacement()
    XCTAssertEqual(cancellations, 1)
    XCTAssertTrue(removed.isEmpty, "Cancel is not consumer completion")
    held?(.success(.init(duration: 12)))
    XCTAssertEqual(player.duration, 0)
    held = nil
    XCTAssertEqual(removed.count, 1)
    XCTAssertNotEqual(removed[0], URL(fileURLWithPath: "/original.mov"))
  }
  func testCopyOccursInsideProviderLifetimeAndCurrentImportLoadsPausedPlayer() {
    var inCallback = false
    var copied: [URL] = [], removed: [URL] = []
    let importer = VideoImportManager(effects: .init(prepare: { _ in }, copy: { _, destination in
      XCTAssertTrue(inCallback)
      copied.append(destination)
    }, remove: { removed.append($0) }, state: { $0() }))
    let player = VideoPlayerManager(dependencies: .init(play: { true }, pause: {}, startLoop: {}, stopLoop: {}))
    let request = player.beginReplacement()
    importer.begin(request: request) { player.acceptImport($1, request: $0) }
    importer.receiveSelection(request: request) { completion in
      inCallback = true
      completion(URL(fileURLWithPath: "/provider/clip.mov"), nil)
      inCallback = false
      return Progress()
    }
    XCTAssertEqual(player.duration, 30)
    XCTAssertEqual(player.playbackState, .paused)
    XCTAssertFalse(importer.isImporting)
    XCTAssertTrue(removed.isEmpty)
    player.shutdown()
    XCTAssertEqual(removed, copied)
  }

  func testSameBasenameCopiesAreUniqueAndFinalConsumerOwnsRelease() {
    var copied: [URL] = [], removed: [URL] = []
    var handles: [VideoImportManager.MediaHandle] = []
    let importer = VideoImportManager(effects: .init(prepare: { _ in }, copy: { _, url in copied.append(url) },
      remove: { removed.append($0) }, state: { $0() }))
    for _ in 0..<2 {
      let request = UUID()
      importer.begin(request: request) { _, outcome in
        if case .selected(let handle) = outcome { handles.append(handle) }
      }
      importer.receiveSelection(request: request) { completion in
        completion(URL(fileURLWithPath: "/provider/same.mov"), nil)
        return Progress()
      }
    }
    XCTAssertEqual(Set(copied).count, 2)
    var consumer: VideoImportManager.MediaHandle? = handles[0].lease()
    handles.removeAll()
    XCTAssertEqual(removed, [copied[1]])
    XCTAssertNotNil(consumer)
    consumer = nil
    XCTAssertEqual(Set(removed), Set(copied))
  }

  func testCancelledStaleAndFailedProviderResultsPreserveSelectionAndOriginals() {
    var removed: [URL] = [], copied: [URL] = []
    var state: [() -> Void] = []
    var callback: ((URL?, Error?) -> Void)?
    let progress = Progress()
    let importer = VideoImportManager(effects: .init(prepare: { _ in }, copy: { _, url in copied.append(url) },
      remove: { removed.append($0) }, state: { state.append($0) }))
    var completions = 0
    let old = UUID()
    importer.begin(request: old) { _, _ in completions += 1 }
    importer.receiveSelection(request: old) { callback = $0; return progress }
    importer.cancel()
    XCTAssertTrue(progress.isCancelled)
    callback?(URL(fileURLWithPath: "/provider/clip.mov"), nil)
    let current = UUID()
    importer.begin(request: current) { _, outcome in
      if case .cancelled = outcome { completions += 1 } else { XCTFail("Expected cancellation") }
    }
    while !state.isEmpty { state.removeFirst()() }
    XCTAssertEqual(completions, 0)
    XCTAssertEqual(removed, copied)
    importer.receiveSelection(request: current, provider: nil)
    XCTAssertEqual(completions, 1)
    XCTAssertFalse(removed.contains(URL(fileURLWithPath: "/provider/clip.mov")))
  }

  func testCopyFailureRemovesOnlyItsPartialDestination() {
    var destination: URL?, removed: [URL] = []
    let importer = VideoImportManager(effects: .init(prepare: { _ in }, copy: { _, url in
      destination = url; throw NSError(domain: "fixture", code: 1)
    }, remove: { removed.append($0) }, state: { $0() }))
    let request = UUID()
    var failed = false
    importer.begin(request: request) { _, outcome in if case .failed = outcome { failed = true } }
    importer.receiveSelection(request: request) { completion in
      completion(URL(fileURLWithPath: "/original.mov"), nil); return Progress()
    }
    XCTAssertTrue(failed)
    XCTAssertEqual(removed, [destination!])
  }
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
