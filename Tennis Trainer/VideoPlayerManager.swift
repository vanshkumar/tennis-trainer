import AVFoundation
import SwiftUI

class VideoPlayerManager: ObservableObject {
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
    var onFrameProcessed: ((Bool) -> Void)?
    
    private let horizontalDetector = ForearmHorizontalDetector()
    
    func loadVideo(from url: URL) {
        isLoading = true
        
        // Clean up previous player
        cleanup()
        
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
        displayLink = CADisplayLink(target: self, selector: #selector(processCurrentFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopFrameProcessing() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func processCurrentFrame() {
        guard let videoOutput = videoOutput,
              let player = player,
              isPlaying else {
            return
        }
        
        let currentTime = player.currentTime()
        guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) else {
            return
        }
        
        let orientation = getVideoOrientation()
        poseDetectionManager?.detectPose(in: pixelBuffer, orientation: orientation)
        let ts = CMTimeGetSeconds(currentTime)
        ballDetectionManager?.process(pixelBuffer: pixelBuffer, timestamp: ts)
        
        // Check for horizontal forearm and trigger callback
        let shouldBeep = checkForearmHorizontal()
        
        DispatchQueue.main.async {
            self.onFrameProcessed?(shouldBeep)
        }
    }
    
    private func checkForearmHorizontal() -> Bool {
        guard let poseManager = poseDetectionManager else { return false }
        return horizontalDetector.checkForearmHorizontal(forearmAngle: poseManager.forearmAngle)
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
        guard let player = player else { return }
        
        // Ensure player layer is connected
        if let layer = playerLayer, layer.player !== player {
            layer.player = player
        }
        
        player.play()
        isPlaying = true
        startFrameProcessing()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopFrameProcessing()
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
    }
    
    func resetToBeginning() {
        player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = 0
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

    func setupBallDetection(with pose: PoseDetectionManager) {
        // Video overlay can favor stability (t=2, default)
        self.ballDetectionManager = BallDetectionManager(poseDetectionManager: pose, overlayTIndex: 2)
    }
    
    private func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        player?.pause()
        
        // Stop frame processing
        stopFrameProcessing()
        
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
        
        // Reset horizontal detection state
        horizontalDetector.reset()
        
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
