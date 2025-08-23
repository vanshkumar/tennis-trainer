import SwiftUI
import AVFoundation

struct VideoPlayerView: UIViewRepresentable {
    let playerLayer: AVPlayerLayer
    
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.backgroundColor = .black
        view.setPlayerLayer(playerLayer)
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.setPlayerLayer(playerLayer)
        uiView.updateLayerFrame()
    }
}

class PlayerUIView: UIView {
    private var currentPlayerLayer: AVPlayerLayer?
    
    func setPlayerLayer(_ playerLayer: AVPlayerLayer) {
        // Remove existing layer if different
        if let existing = currentPlayerLayer, existing !== playerLayer {
            existing.removeFromSuperlayer()
        }
        
        // Add new layer if not already added
        if currentPlayerLayer !== playerLayer {
            currentPlayerLayer = playerLayer
            playerLayer.videoGravity = .resizeAspect
            layer.addSublayer(playerLayer)
        }
        
        updateLayerFrame()
    }
    
    func updateLayerFrame() {
        guard let playerLayer = currentPlayerLayer else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            playerLayer.frame = self.bounds
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerFrame()
    }
}