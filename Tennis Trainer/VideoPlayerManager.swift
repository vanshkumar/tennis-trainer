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
    }
    enum ItemEvent { case ended, failed }
    struct PlaybackSnapshot {
      var position: CMTime
      var stopped: Bool
      var failed: Bool
    }
    enum PlaybackState: Equatable {
      case empty, paused, seeking, playing, failed(String)
      var label: String {
        switch self {
        case .empty: return "No video"
        case .paused: return "Paused"
        case .seeking: return "Seeking…"
        case .playing: return "Playing"
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
    private var retireTicks: (() -> Void)?
    private var retireTime: (() -> Void)?
    private var displayTarget: DisplayTarget?

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

    private var sourceID = UUID()
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isLoading = false
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var playerLayer: AVPlayerLayer?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    
    // Pose detection components
    var poseDetectionManager: PoseDetectionManager?
    var ballDetectionManager: BallDetectionManager?
    var onFrameProcessed: (() -> Void)?
    var onApex: (() -> Void)?
    
    func loadVideo(from url: URL) {
        // Clean up previous player
        cleanup()
        let load = loadID
        isLoading = true
        sourceID = UUID()
        ballDetectionManager?.resetTrackingState(sourceID: sourceID)
        if let dependencies {
          if let seconds = dependencies.load(url), seconds.isFinite, seconds > 0 {
            duration = seconds
            hasLoadedItem = true
            playbackState = .paused
            setupTimeObserver()
          } else { playbackState = .failed("Video could not load") }
          isLoading = false
          return
        }
        
        let asset = AVAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        // Mute the video audio
        player?.isMuted = true
        
        // Set up video output for frame extraction
        setupVideoOutput()
        
        
        setupTimeObserver()
        
        Task {
            do {
                let duration = try await asset.load(.duration)
                let isPlayable = try await asset.load(.isPlayable)
                
                await MainActor.run {
                    guard self.loadID == load else { return }
                    let seconds = CMTimeGetSeconds(duration)
                    self.isLoading = false
                    guard isPlayable, seconds.isFinite, seconds > 0 else {
                      self.playbackState = .failed("Video could not load")
                      return
                    }
                    self.duration = seconds
                    self.hasLoadedItem = true
                    self.playbackState = .paused
                }
            } catch {
                await MainActor.run {
                    guard self.loadID == load else { return }
                    self.isLoading = false
                    self.playbackState = .failed("Video could not load")
                }
            }
        }
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
    
    private func getVideoOrientation() -> CGImagePropertyOrientation {
        guard let playerItem = playerItem,
              let videoTrack = playerItem.asset.tracks(withMediaType: .video).first else {
            return .right // Default fallback
        }
        
        let transform = videoTrack.preferredTransform
        
        // Convert CGAffineTransform to CGImagePropertyOrientation
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            // 90 degree rotation
            return .right
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            // -90 degree rotation  
            return .left
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            // 180 degree rotation
            return .down
        } else {
            // No rotation or identity transform
            return .up
        }
    }
    
    private func setupTimeObserver() {
        let load = loadID
        let accept: (CMTime) -> Void = { [weak self] _ in
          guard let self else { return }
          self.deliverState { [weak self] in
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
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main, using: accept)
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
        guard contextActive, hasLoadedItem, !isPlaying else { return }
        playRequested = true
        guard seekID == nil else { return }
        if let target = failedSeekTarget { seek(to: target); return }
        beginPlayback()
    }

    private func beginPlayback() {
        guard contextActive, playRequested, seekID == nil, hasLoadedItem, !isPlaying else { return }
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
        if ingressOpen && isPlaying { startFrameProcessing() }
    }
    
    func pause() {
        playRequested = false
        closePlayback()
        if seekID == nil, hasLoadedItem { playbackState = .paused }
    }

    private func closePlayback() {
        ingressOpen = false
        frameRun = UUID()
        ballDetectionManager?.resetTrackingState()
        isPlaying = false
        if let dependencies { dependencies.pause() } else { player?.pause() }
        stopFrameProcessing()
    }

    func setContextActive(_ active: Bool) {
      contextActive = active
      if !active { pause() }
    }
    
    // Method to refresh player layer connection if needed
    func refreshPlayerLayerConnection() {
        guard let player = player, let layer = playerLayer else { return }
        
        if layer.player !== player {
            layer.player = player
        }
    }
    
    func seek(to time: Double) {
        guard hasLoadedItem, time.isFinite, duration.isFinite, duration > 0 else { return }
        let target = min(max(time, 0), duration)
        let request = UUID(), load = loadID
        // Replace identity before cancellation can synchronously report old failure.
        seekID = request
        failedSeekTarget = target
        closePlayback()
        playbackState = .seeking
        if let dependencies { dependencies.cancelSeeks() } else { playerItem?.cancelPendingSeeks() }
        let completion: (Bool) -> Void = { [weak self] success in
          self?.deliverState { [weak self] in
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
        let cmTime = CMTime(seconds: target, preferredTimescale: 600)
        if let dependencies { dependencies.seek(cmTime, completion) }
        else { player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: completion) }
    }
    
    func resetToBeginning() {
        seek(to: 0)
    }
    
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
        loadID = UUID()
        seekID = nil
        failedSeekTarget = nil
        pause()
        if let dependencies { dependencies.cancelSeeks() } else { playerItem?.cancelPendingSeeks() }
        retireTime?()
        retireTime = nil
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Clean up video output
        if let videoOutput = videoOutput, let playerItem = playerItem {
            playerItem.remove(videoOutput)
        }
        videoOutput = nil
        
        // Disconnect layer from player
        if let layer = playerLayer {
            layer.player = nil
            playerLayer = nil
        }
        
        player = nil
        playerItem = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        hasLoadedItem = false
        playbackState = .empty
    }
    
    deinit {
        cleanup()
    }
}
