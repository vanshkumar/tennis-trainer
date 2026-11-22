import AVFoundation
import SwiftUI

final class VideoPlayerManager: ObservableObject {
    // Control state and display-link delivery are owned by the main executor.
    // Tests replace AV effects, while using the same controls and frame ingress.
    struct Dependencies {
      var play: () -> Bool
      var pause: () -> Void
      var startLoop: () -> Void
      var stopLoop: () -> Void
      var load: (URL) -> Double? = { _ in 30 }
      var seek: (CMTime, @escaping (Bool) -> Void) -> Void = { _, _ in }
      var cancelSeeks: () -> Void = {}
      var currentTime: () -> CMTime = { .zero }
      var state: (@escaping () -> Void) -> Void = { $0() }
      var observeTicks: ((@escaping () -> Void) -> (() -> Void))? = nil
      var observeTime: ((@escaping (CMTime) -> Void) -> (() -> Void))? = nil
      var frameOutput: (() -> FrameOutputReading)? = nil
      var observeEvents: ((@escaping (ItemEvent) -> Void) -> (() -> Void))? = nil
      var snapshot: (() -> PlaybackSnapshot)? = nil
      var prepare: ((VideoImportManager.MediaHandle, @escaping (Result<Metadata, Error>) -> Void,
                     @escaping (Readiness) -> Void) -> (() -> Void))? = nil
    }
    struct Metadata {
      var duration: Double
      var playable = true
      var hasVideo = true
      var orientation: CGImagePropertyOrientation = .up
      var isValid: Bool { playable && hasVideo && duration.isFinite && duration > 0 }
    }
    enum Readiness { case unknown, ready, failed }
    private final class Candidate {
      let id: UUID
      let media: VideoImportManager.MediaHandle
      var metadata: Metadata?
      var ready = false
      var player: AVPlayer?
      var item: AVPlayerItem?
      var task: Task<Void, Never>?
      var status: NSKeyValueObservation?
      var cancel: (() -> Void)?
      init(id: UUID, media: VideoImportManager.MediaHandle) { self.id = id; self.media = media }
      func retire() {
        task?.cancel(); task = nil
        status?.invalidate(); status = nil
        let cancel = cancel; self.cancel = nil; cancel?()
        player?.pause(); item?.cancelPendingSeeks()
        player?.replaceCurrentItem(with: nil)
        player = nil; item = nil
      }
      deinit { retire() }
    }
    private final class PlaybackSession {
      var media: VideoImportManager.MediaHandle?
      var player: AVPlayer?
      var item: AVPlayerItem?
      var output: AVPlayerItemVideoOutput?
      var layer: AVPlayerLayer?
      var timeObservation: (player: AVPlayer, token: Any)?
      func retire() {
        player?.pause()
        item?.cancelPendingSeeks()
        if let observation = timeObservation {
          timeObservation = nil
          observation.player.removeTimeObserver(observation.token)
        }
        if let output, let item { item.remove(output) }
        output = nil
        layer?.player = nil; layer = nil
        player?.replaceCurrentItem(with: nil)
        player = nil; item = nil
        media = nil
      }
      deinit { retire() }
    }
    enum ItemEvent { case ended, failed }
    struct PlaybackSnapshot {
      var position: CMTime
      var stopped: Bool
      var failed: Bool
    }
    enum PlaybackState: Equatable {
      case empty, paused, seeking, playing, ended, failed(String)
      var label: String {
        switch self {
        case .empty: return "No video"
        case .paused: return "Paused"
        case .seeking: return "Seeking…"
        case .playing: return "Playing"
        case .ended: return "Ended"
        case .failed(let message): return message
        }
      }
    }
    @Published private(set) var playbackState: PlaybackState = .empty
    @Published private(set) var playRequested = false
    private var loadID = UUID()
    private var seekID: UUID?
    private var failedSeekTarget: Double?
    private var hasLoadedItem = false
    private var session = PlaybackSession()
    private var media: VideoImportManager.MediaHandle? {
      get { session.media }
      set { session.media = newValue }
    }
    private var replacementID: UUID?
    private var candidate: Candidate?
    private var orientation: CGImagePropertyOrientation = .up
    @Published private(set) var importMessage: String?
    private var retireTicks: (() -> Void)?
    private var retireTime: (() -> Void)?
    private var displayTarget: DisplayTarget?
    private var timelineID: UUID?
    private var retireEvents: (() -> Void)?

    private final class DisplayTarget: NSObject {
      weak var owner: VideoPlayerManager?
      let run: UUID
      init(owner: VideoPlayerManager, run: UUID) { self.owner = owner; self.run = run }
      @objc func tick() { owner?.processDisplayLinkFrame(run: run) }
    }
    private let dependencies: Dependencies?
    private var contextActive = true
    private var ingressOpen = false
    private var frameRun = UUID()
    private var loopActive = false

    init(dependencies: Dependencies? = nil) {
      self.dependencies = dependencies
    }

    protocol FrameOutputReading {
        func hasNewPixelBuffer(forItemTime time: CMTime) -> Bool
        func copyFrame(forItemTime time: CMTime) -> (CVPixelBuffer, CMTime)?
    }

    private struct PlayerOutputReader: FrameOutputReading {
        let output: AVPlayerItemVideoOutput
        func hasNewPixelBuffer(forItemTime time: CMTime) -> Bool {
            output.hasNewPixelBuffer(forItemTime: time)
        }
        func copyFrame(forItemTime time: CMTime) -> (CVPixelBuffer, CMTime)? {
            var displayTime = CMTime.invalid
            guard let pixels = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: &displayTime) else {
                return nil
            }
            return (pixels, displayTime)
        }
    }

    @Published private(set) var sourceID = UUID()
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isLoading = false
    
    private var player: AVPlayer? {
      get { session.player }
      set { session.player = newValue }
    }
    private var playerItem: AVPlayerItem? {
      get { session.item }
      set { session.item = newValue }
    }
    private var playerLayer: AVPlayerLayer? {
      get { session.layer }
      set { session.layer = newValue }
    }
    private var videoOutput: AVPlayerItemVideoOutput? {
      get { session.output }
      set { session.output = newValue }
    }
    private var displayLink: CADisplayLink?
    
    // Pose detection components
    var poseDetectionManager: PoseDetectionManager?
    var ballDetectionManager: BallDetectionManager?
    var onFrameProcessed: (() -> Void)?
    var onApex: (() -> Void)?
    
    func loadVideo(from url: URL) {
        loadVideo(.external(url), request: beginReplacement())
    }

    @discardableResult
    func beginReplacement() -> UUID {
        retireCandidate()
        // Retire the callback before pause settles the preserved item. Keep its
        // unconfirmed target so a later Play still requires a fresh successful seek.
        seekID = nil
        pause()
        if let dependencies { dependencies.cancelSeeks() } else { playerItem?.cancelPendingSeeks() }
        let request = UUID()
        replacementID = request
        isLoading = true
        importMessage = nil
        return request
    }

    func cancelReplacement() {
        guard replacementID != nil else { return }
        retireCandidate()
        isLoading = false
        importMessage = importRecoveryMessage("Video selection cancelled.")
    }

    func acceptImport(_ outcome: VideoImportManager.Outcome, request: UUID) {
        guard replacementID == request else { return }
        switch outcome {
        case .selected(let handle): loadVideo(handle, request: request)
        case .cancelled: cancelReplacement()
        case .failed:
          retireCandidate()
          isLoading = false
          importMessage = importRecoveryMessage("Video could not be imported.")
        }
    }

    func loadVideo(_ handle: VideoImportManager.MediaHandle, request: UUID) {
      guard replacementID == request else { return }
      let pending = Candidate(id: request, media: handle)
      candidate = pending
      if let dependencies {
        if let prepare = dependencies.prepare {
          let cancel = prepare(handle.lease(), { [weak self, weak pending, handle] result in
            self?.deliverState { [weak self, weak pending, handle] in
              defer { withExtendedLifetime(handle) {} }
              guard let self, let pending else { return }
              self.receiveMetadata(result, for: pending)
            }
          }, { [weak self, weak pending, handle] status in
            self?.deliverState { [weak self, weak pending, handle] in
              defer { withExtendedLifetime(handle) {} }
              guard let self, let pending else { return }
              self.receiveReadiness(status, for: pending)
            }
          })
          if isCurrent(pending) { pending.cancel = cancel } else { cancel() }
        } else {
          let seconds = dependencies.load(handle.url)
          guard isCurrent(pending) else { return }
          receiveMetadata(.success(.init(duration: seconds ?? 0)), for: pending)
          receiveReadiness(.ready, for: pending)
        }
        return
      }
      let asset = AVURLAsset(url: handle.url)
      pending.task = Task { [weak self, weak pending, handle] in
        // Cancellation is only a request. Asset loading retains its own file lease
        // until the suspended consumer has actually returned.
        defer { withExtendedLifetime(handle) {} }
        do {
          let playable = try await asset.load(.isPlayable)
          guard await MainActor.run(body: { [weak self, weak pending] in
            guard let self, let pending else { return false }; return self.isCurrent(pending)
          }) else { return }
          let duration = try await asset.load(.duration)
          guard await MainActor.run(body: { [weak self, weak pending] in
            guard let self, let pending else { return false }; return self.isCurrent(pending)
          }) else { return }
          let tracks = try await asset.loadTracks(withMediaType: .video)
          guard await MainActor.run(body: { [weak self, weak pending] in
            guard let self, let pending else { return false }; return self.isCurrent(pending)
          }) else { return }
          let transform = try await tracks.first?.load(.preferredTransform)
          await MainActor.run { [weak self, weak pending] in
            guard let self, let pending, self.isCurrent(pending) else { return }
            let metadata = Metadata(duration: CMTimeGetSeconds(duration), playable: playable,
              hasVideo: !tracks.isEmpty, orientation: Self.orientation(for: transform ?? .identity))
            guard metadata.isValid else { self.failCandidate(pending); return }
            pending.metadata = metadata
            self.observeReadiness(of: pending, asset: asset)
          }
        } catch {
          await MainActor.run { [weak self, weak pending] in
            guard let self, let pending else { return }; self.failCandidate(pending)
          }
        }
      }
    }

    private func isCurrent(_ pending: Candidate) -> Bool {
      candidate === pending && replacementID == pending.id
    }

    private func observeReadiness(of pending: Candidate, asset: AVAsset) {
      let item = AVPlayerItem(asset: asset)
      let player = AVPlayer(playerItem: item)
      player.isMuted = true
      pending.item = item; pending.player = player
      let handle = pending.media.lease()
      pending.status = item.observe(\.status, options: [.initial, .new]) { [weak self, weak pending, handle] _, _ in
        self?.deliverState { [weak self, weak pending, handle] in
          defer { withExtendedLifetime(handle) {} }
          guard let self, let pending, self.isCurrent(pending), let item = pending.item else { return }
          // A queued observation signals reconciliation, not historical readiness.
          let status: Readiness = item.status == .readyToPlay ? .ready : (item.status == .failed ? .failed : .unknown)
          self.receiveReadiness(status, for: pending)
        }
      }
    }

    private func receiveMetadata(_ result: Result<Metadata, Error>, for pending: Candidate) {
      guard isCurrent(pending) else { return }
      guard case .success(let metadata) = result, metadata.isValid else { failCandidate(pending); return }
      pending.metadata = metadata
      commitIfReady(pending)
    }

    private func receiveReadiness(_ status: Readiness, for pending: Candidate) {
      guard isCurrent(pending) else { return }
      switch status {
      case .unknown: return
      case .failed: failCandidate(pending)
      case .ready: pending.ready = true; commitIfReady(pending)
      }
    }

    private func failCandidate(_ pending: Candidate) {
      guard isCurrent(pending) else { return }
      retireCandidate()
      isLoading = false
      importMessage = importRecoveryMessage("Video could not load.")
    }

    private func importRecoveryMessage(_ reason: String) -> String {
      reason + (hasLoadedItem ? " Your previous video is ready to play." : " Choose another video.")
    }

    private func retireCandidate() {
      replacementID = nil
      let retired = candidate
      candidate = nil
      retired?.retire()
    }

    private func commitIfReady(_ pending: Candidate) {
      guard isCurrent(pending), pending.ready, let metadata = pending.metadata else { return }
      if let item = pending.item, item.status != .readyToPlay {
        if item.status == .failed { failCandidate(pending) }
        return
      }
      // Detach from candidate cancellation before retiring the previous session.
      candidate = nil; replacementID = nil
      pending.status?.invalidate(); pending.status = nil
      cleanup()
      media = pending.media
      player = pending.player; playerItem = pending.item
      pending.player = nil; pending.item = nil
      orientation = metadata.orientation
      sourceID = UUID()
      ballDetectionManager?.resetTrackingState(sourceID: sourceID)
      duration = metadata.duration
      currentTime = 0
      hasLoadedItem = true
      playbackState = .paused
      setupVideoOutput()
      setupTimeObserver()
    }

    private func setupVideoOutput() {
        guard let playerItem = playerItem else { return }
        
        let settings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        playerItem.add(videoOutput!)
        
    }
    
    private func startFrameProcessing() {
        guard !loopActive else { return }
        loopActive = true
        let run = frameRun
        if let dependencies {
          dependencies.startLoop()
          retireTicks = dependencies.observeTicks? { [weak self] in self?.processDisplayLinkFrame(run: run) }
          return
        }
        let target = DisplayTarget(owner: self, run: run)
        displayTarget = target
        displayLink = CADisplayLink(target: target, selector: #selector(DisplayTarget.tick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopFrameProcessing() {
        guard loopActive else { return }
        loopActive = false
        retireTicks?()
        retireTicks = nil
        if let dependencies { dependencies.stopLoop(); return }
        displayLink?.invalidate()
        displayLink = nil
        displayTarget = nil
    }
    
    private func processDisplayLinkFrame(run: UUID) {
        if let dependencies, let output = dependencies.frameOutput?() {
          guard run == frameRun, loopActive else { return }
          processPlaybackFrame(output: output, requestedTime: dependencies.currentTime(), orientation: .up)
          return
        }
        guard run == frameRun, loopActive, let videoOutput = videoOutput,
              let player = player,
              isPlaying else {
            return
        }
        
        processPlaybackFrame(output: PlayerOutputReader(output: videoOutput),
                            requestedTime: player.currentTime(), orientation: getVideoOrientation())
    }

    func processCurrentFrame(output: FrameOutputReading, requestedTime: CMTime,
                             orientation: CGImagePropertyOrientation,
                             requiresActiveContext: Bool = false) {
        let lease = media?.lease()
        defer { withExtendedLifetime(lease) {} }
        guard !requiresActiveContext || (contextActive && ingressOpen && isPlaying),
              let manager = ballDetectionManager else { return }
        let generation = manager.admissionGeneration
        let source = sourceID
        let run = frameRun
        let item = playerItem
        guard output.hasNewPixelBuffer(forItemTime: requestedTime),
              let (pixels, time) = output.copyFrame(forItemTime: requestedTime) else { return }
        guard source == sourceID, run == frameRun, item === playerItem,
              !requiresActiveContext || (contextActive && ingressOpen && isPlaying) else { return }
        manager.process(input: .init(
            pixelBuffer: pixels, sourceTime: time, orientation: orientation, sourceID: source
        ), expectedGeneration: generation)
    }

    func processPlaybackFrame(output: FrameOutputReading, requestedTime: CMTime,
                              orientation: CGImagePropertyOrientation) {
      processCurrentFrame(output: output, requestedTime: requestedTime,
        orientation: orientation, requiresActiveContext: true)
    }
    
    private func getVideoOrientation() -> CGImagePropertyOrientation { orientation }

    enum CalibrationError: LocalizedError {
      case notPaused, changed
      var errorDescription: String? {
        switch self {
        case .notPaused: return "Pause on a clear reference frame first."
        case .changed: return "Playback changed while reading the frame. Pause and try again."
        }
      }
    }

    @MainActor
    func captureCalibrationPose(analyze: @escaping (CGImage, BallDetectionManager.FrameIdentity) throws
      -> PoseDetectionManager.FrameObservation = PoseDetectionManager.calibrationObservation(in:identity:))
      async throws -> PoseDetectionManager.FrameObservation {
      guard contextActive, playbackState == .paused, !isLoading, seekID == nil,
            let handle = media?.lease(), let position = finitePosition() else {
        throw CalibrationError.notPaused
      }
      let source = sourceID, load = loadID, run = frameRun
      // Retain the imported file until both image generation and Vision have finished.
      defer { withExtendedLifetime(handle) {} }
      let generator = AVAssetImageGenerator(asset: AVURLAsset(url: handle.url))
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 1280, height: 1280)
      generator.requestedTimeToleranceBefore = .zero
      generator.requestedTimeToleranceAfter = .zero
      let result = try await generator.image(at: CMTime(seconds: position, preferredTimescale: 600))
      let identity = BallDetectionManager.FrameIdentity(sourceID: source, generation: run,
        sequence: 1, sourceTime: result.actualTime)
      let observation = try await Task.detached(priority: .userInitiated) {
        try analyze(result.image, identity)
      }.value
      try Task.checkCancellation()
      guard source == sourceID, load == loadID, run == frameRun, contextActive,
            playbackState == .paused, !isLoading, seekID == nil else {
        throw CalibrationError.changed
      }
      return observation
    }

    private static func orientation(for transform: CGAffineTransform) -> CGImagePropertyOrientation {
      if transform.a == 0 && transform.b == 1 && transform.c == -1 && transform.d == 0 { return .right }
      if transform.a == 0 && transform.b == -1 && transform.c == 1 && transform.d == 0 { return .left }
      if transform.a == -1 && transform.b == 0 && transform.c == 0 && transform.d == -1 { return .down }
      return .up
    }

    private func setupTimeObserver() {
        let load = loadID
        let lease = media?.lease()
        let accept: (CMTime) -> Void = { [weak self, lease] _ in
          defer { withExtendedLifetime(lease) {} }
          guard let self else { return }
          self.deliverState { [weak self, lease] in
            defer { withExtendedLifetime(lease) {} }
            guard let self, self.loadID == load, self.seekID == nil else { return }
            // A delayed periodic callback is only a signal; read the owned backend now.
            if let seconds = self.finitePosition() { self.currentTime = seconds }
          }
        }
        if let dependencies {
          retireTime = dependencies.observeTime?(accept)
          return
        }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        if let player {
          session.timeObservation = (player, player.addPeriodicTimeObserver(forInterval: interval, queue: .main, using: accept))
        }
    }

    private func deliverState(_ job: @escaping () -> Void) {
      if let dependencies { dependencies.state(job) }
      else { DispatchQueue.main.async(execute: job) }
    }

    private func finitePosition() -> Double? {
      let time = dependencies?.currentTime() ?? player?.currentTime() ?? .invalid
      let seconds = CMTimeGetSeconds(time)
      guard time.isValid, time.isNumeric, seconds.isFinite, duration.isFinite, duration > 0 else { return nil }
      return min(max(seconds, 0), duration)
    }
    
    func play() {
        guard contextActive, !isLoading, hasLoadedItem, !isPlaying else { return }
        if playbackState == .ended { replay(); return }
        playRequested = true
        guard seekID == nil else { return }
        if let target = failedSeekTarget { seek(to: target); return }
        beginPlayback()
    }

    private func beginPlayback() {
        guard contextActive, !isLoading, playRequested, seekID == nil, hasLoadedItem, !isPlaying else { return }
        if let dependencies {
          guard dependencies.play() else { return }
        } else {
          guard let player else { return }

          // Ensure player layer is connected.
          if let layer = playerLayer, layer.player !== player {
            layer.player = player
          }
          player.play()
        }
        frameRun = UUID()
        ballDetectionManager?.resetTrackingState()
        ingressOpen = true
        isPlaying = true
        playbackState = .playing
        armTimeline()
        if ingressOpen && isPlaying { startFrameProcessing() }
    }
    
    func pause() {
        playRequested = false
        closePlayback()
        if seekID == nil, hasLoadedItem { playbackState = .paused }
    }

    private func closePlayback() {
        timelineID = nil
        retireEvents?()
        retireEvents = nil
        ingressOpen = false
        frameRun = UUID()
        ballDetectionManager?.resetTrackingState()
        isPlaying = false
        if let dependencies { dependencies.pause() } else { player?.pause() }
        stopFrameProcessing()
    }

    func setContextActive(_ active: Bool) {
      contextActive = active
      if !active { cancelReplacement(); pause() }
    }
    
    // Method to refresh player layer connection if needed
    func refreshPlayerLayerConnection() {
        guard let player = player, let layer = playerLayer else { return }
        
        if layer.player !== player {
            layer.player = player
        }
    }
    
    func seek(to time: Double) {
        guard !isLoading, hasLoadedItem, time.isFinite, duration.isFinite, duration > 0 else { return }
        let target = min(max(time, 0), duration)
        let cmTime = CMTime(seconds: target, preferredTimescale: 600)
        guard cmTime.isValid, cmTime.isNumeric, CMTimeGetSeconds(cmTime).isFinite else { return }
        let request = UUID(), load = loadID
        // Replace identity before cancellation can synchronously report old failure.
        seekID = request
        failedSeekTarget = target
        closePlayback()
        playbackState = .seeking
        if let dependencies { dependencies.cancelSeeks() } else { playerItem?.cancelPendingSeeks() }
        let lease = media?.lease()
        let completion: (Bool) -> Void = { [weak self, lease] success in
          defer { withExtendedLifetime(lease) {} }
          self?.deliverState { [weak self, lease] in
            defer { withExtendedLifetime(lease) {} }
            guard let self, self.loadID == load, self.seekID == request else { return }
            self.seekID = nil
            guard success, let position = self.finitePosition() else {
              self.playRequested = false
              self.playbackState = .failed("Seek failed. Tap Play to retry.")
              return
            }
            self.failedSeekTarget = nil
            self.currentTime = position
            self.playbackState = .paused
            if self.playRequested && self.contextActive { self.beginPlayback() }
          }
        }
        if let dependencies { dependencies.seek(cmTime, completion) }
        else { player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: completion) }
    }
    
    func resetToBeginning() {
        seek(to: 0)
    }

    func replay() {
      guard contextActive, !isLoading, hasLoadedItem else { return }
      playRequested = true
      seek(to: 0)
    }

    private func armTimeline() {
      let timeline = UUID(), load = loadID
      timelineID = timeline
      let lease = media?.lease()
      let callback: (ItemEvent) -> Void = { [weak self, lease] _ in
        // Capture the registration's immutable owner BEFORE the executor hop.
        // Native notifications have no run token, so even a matching owner is
        // only a reconciliation signal, never proof of current end/failure.
        self?.deliverState { [weak self, lease] in
          defer { withExtendedLifetime(lease) {} }
          self?.reconcileTimeline(load: load, timeline: timeline)
        }
      }
      let retire: () -> Void
      if let dependencies {
        retire = dependencies.observeEvents?(callback) ?? {}
      } else if let item = playerItem, let player {
        let center = NotificationCenter.default
        let end = center.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification,
          object: item, queue: nil) { _ in callback(.ended) }
        let failure = center.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification,
          object: item, queue: nil) { _ in callback(.failed) }
        let itemStatus = item.observe(\.status, options: [.new]) { _, _ in callback(.failed) }
        let playerStatus = player.observe(\.status, options: [.new]) { _, _ in callback(.failed) }
        retire = {
          center.removeObserver(end); center.removeObserver(failure)
          itemStatus.invalidate(); playerStatus.invalidate()
        }
      } else { retire = {} }
      guard timelineID == timeline, loadID == load else { retire(); return }
      retireEvents = retire
      // Cover an end/failure that became observable while installing the owner.
      reconcileTimeline(load: load, timeline: timeline)
    }

    private func reconcileTimeline(load: UUID, timeline: UUID) {
      guard loadID == load, timelineID == timeline, seekID == nil,
            contextActive, playRequested, isPlaying else { return }
      let snapshot: PlaybackSnapshot
      if let read = dependencies?.snapshot { snapshot = read() }
      else if dependencies != nil { return }
      else {
        guard let player, let item = playerItem, player.currentItem === item else { return }
        snapshot = .init(position: player.currentTime(), stopped: player.rate == 0,
          failed: item.status == .failed || player.status == .failed)
      }
      // An injected/reentrant reader can change ownership too.
      guard loadID == load, timelineID == timeline, seekID == nil,
            contextActive, playRequested, isPlaying else { return }
      if snapshot.failed {
        let retryPosition = finitePosition() ?? currentTime
        playRequested = false
        closePlayback()
        failedSeekTarget = retryPosition
        playbackState = .failed("Playback failed. Tap Play to retry.")
      } else if snapshot.stopped, snapshot.position.isValid, snapshot.position.isNumeric,
                CMTimeGetSeconds(snapshot.position).isFinite, duration.isFinite, duration > 0,
                CMTimeCompare(snapshot.position, CMTime(seconds: duration, preferredTimescale: 600)) >= 0 {
        playRequested = false
        closePlayback()
        currentTime = duration
        playbackState = .ended
      }
    }

    func shutdown() { cleanup() }
    
    func getPlayerItem() -> AVPlayerItem? {
        return playerItem
    }
    
    func getPlayerLayer() -> AVPlayerLayer? {
        guard let player = player else { return nil }
        
        // Create new layer if needed or if player changed
        if playerLayer == nil || playerLayer?.player !== player {
            playerLayer = AVPlayerLayer(player: player)
            playerLayer?.videoGravity = .resizeAspect
        }
        
        // Ensure layer is connected to player
        if playerLayer?.player !== player {
            playerLayer?.player = player
        }
        
        return playerLayer
    }

    func setupBallDetection(with pose: PoseDetectionManager,
                            factory: ((PoseDetectionManager) -> BallDetectionManager)? = nil) {
        guard ballDetectionManager == nil else { return }
        guard factory != nil || !AppRuntime.isRunningTests else { return }
        // Video overlay favors the freshest frame to avoid visible lag.
        let manager = factory?(pose) ?? BallDetectionManager(poseDetectionManager: pose, overlayTIndex: 4)
        manager.onApex = { [weak self] in
            self?.onApex?()
        }
        manager.onFrameProcessed = { [weak self] in self?.onFrameProcessed?() }
        self.ballDetectionManager = manager
    }
    
    private func cleanup() {
        retireCandidate()
        loadID = UUID()
        seekID = nil
        failedSeekTarget = nil
        pause()
        if let dependencies { dependencies.cancelSeeks() } else { playerItem?.cancelPendingSeeks() }
        retireTime?()
        retireTime = nil
        session.retire()
        session = PlaybackSession()
        isPlaying = false
        currentTime = 0
        duration = 0
        isLoading = false
        hasLoadedItem = false
        playbackState = .empty
    }
    
    deinit {
        cleanup()
    }
}
