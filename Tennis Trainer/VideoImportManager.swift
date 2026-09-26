import Foundation
import Combine

/// State belongs to the main executor; copying runs inside the provider callback.
final class VideoImportManager: ObservableObject {
  struct MediaHandle {
    let url: URL
    private let copy: OwnedCopy?
    static func external(_ url: URL) -> Self { Self(url: url, copy: nil) }
    fileprivate static func owned(_ url: URL, remove: @escaping (URL) -> Void) -> Self {
      Self(url: url, copy: OwnedCopy(url: url, remove: remove))
    }
    /// Each value retains a lease until its consumer actually finishes.
    func lease() -> Self { self }
    private final class OwnedCopy {
      let url: URL
      let remove: (URL) -> Void
      init(url: URL, remove: @escaping (URL) -> Void) { self.url = url; self.remove = remove }
      deinit { remove(url) }
    }
  }
  struct Effects {
    var directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("PracticeImports", isDirectory: true)
    var prepare: (URL) throws -> Void = { try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true) }
    var copy: (URL, URL) throws -> Void = { try FileManager.default.copyItem(at: $0, to: $1) }
    var remove: (URL) -> Void = { try? FileManager.default.removeItem(at: $0) }
    var state: (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
  }
  typealias Provider = (@escaping (URL?, Error?) -> Void) -> Progress
  enum Outcome { case selected(MediaHandle), cancelled, failed }
  @Published private(set) var isImporting = false
  private var request: UUID?
  private var progress: Progress?
  private var awaitingSelection = false
  private var completion: ((UUID, Outcome) -> Void)?
  private let effects: Effects
  init(effects: Effects = .init()) { self.effects = effects }

  func begin(request: UUID, completion: @escaping (UUID, Outcome) -> Void) {
    cancel()
    self.request = request
    self.completion = completion
    awaitingSelection = true
    isImporting = true
  }
  func receiveSelection(request: UUID, provider: Provider?) {
    guard self.request == request else { return }
    awaitingSelection = false
    guard let provider else { finish(request, .cancelled); return }
    let effects = effects
    let pending = provider { [weak self] source, error in
      let outcome: Outcome
      if let source, error == nil {
        let ext = ["mov", "mp4", "m4v"].contains(source.pathExtension.lowercased()) ? source.pathExtension.lowercased() : "mov"
        let destination = effects.directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        do {
          try effects.prepare(effects.directory)
          // The provider removes its representation after this callback returns.
          try effects.copy(source, destination)
          outcome = .selected(.owned(destination, remove: effects.remove))
        } catch {
          let failure = error as NSError
          // Even an improbable UUID collision never grants deletion authority.
          if failure.domain != NSCocoaErrorDomain || failure.code != NSFileWriteFileExistsError {
            effects.remove(destination)
          }
          outcome = .failed
        }
      } else { outcome = .failed }
      effects.state { [weak self] in self?.finish(request, outcome) }
    }
    // A synchronous provider may already have finished or started a new request.
    if self.request == request { progress = pending } else { pending.cancel() }
  }
  func cancel() {
    request = nil
    awaitingSelection = false
    completion = nil
    isImporting = false
    let retired = progress
    progress = nil
    retired?.cancel()
  }
  func pickerDismissed(request: UUID) {
    guard self.request == request, awaitingSelection else { return }
    finish(request, .cancelled)
  }
  private func finish(_ request: UUID, _ outcome: Outcome) {
    guard self.request == request else { return }
    let completion = completion
    self.request = nil
    awaitingSelection = false
    self.completion = nil
    progress = nil
    isImporting = false
    completion?(request, outcome)
  }
  deinit { progress?.cancel() }
}
