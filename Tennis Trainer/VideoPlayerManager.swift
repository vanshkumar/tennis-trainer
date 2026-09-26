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
        isLoading = true
        
        // Clean up previous player
        cleanup()
        sourceID = UUID()
        ballDetectionManager?.resetTrackingState(sourceID: sourceID)
        
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
                    self.duration = CMTimeGetSeconds(duration)
                    self.isLoading = false
                    
                    // Ensure we start from the beginning
                    if let player = self.player {
                        player.seek(to: .zero)
                        self.currentTime = 0
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
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
        if let dependencies { dependencies.startLoop(); return }
        displayLink = CADisplayLink(target: self, selector: #selector(processDisplayLinkFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopFrameProcessing() {
        guard loopActive else { return }
        loopActive = false
        if let dependencies { dependencies.stopLoop(); return }
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func processDisplayLinkFrame() {
        guard let videoOutput = videoOutput,
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
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = CMTimeGetSeconds(time)
        }
    }
    
    func play() {
        guard contextActive, !isPlaying else { return }
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
        if ingressOpen && isPlaying { startFrameProcessing() }
    }
    
    func pause() {
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
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        ballDetectionManager?.resetTrackingState()
    }
    
    func resetToBeginning() {
        player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = 0
        ballDetectionManager?.resetTrackingState()
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
        pause()
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
    }
    
    deinit {
        cleanup()
    }
}
