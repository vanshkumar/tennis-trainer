import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        CameraPreviewUIView(previewLayer: previewLayer)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? CameraPreviewUIView else {
            return
        }
        view.updateLayerFrameAndOrientation()
    }
}

private final class CameraPreviewUIView: UIView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)

        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateLayerFrameAndOrientation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerFrameAndOrientation()
    }

    func updateLayerFrameAndOrientation() {
        previewLayer.frame = bounds
        updatePreviewOrientation()
    }

    private func updatePreviewOrientation() {
        guard
            let connection = previewLayer.connection,
            connection.isVideoOrientationSupported,
            let interfaceOrientation = window?.windowScene?.interfaceOrientation,
            let videoOrientation = AVCaptureVideoOrientation(interfaceOrientation)
        else {
            return
        }

        connection.videoOrientation = videoOrientation
    }
}

private extension AVCaptureVideoOrientation {
    init?(_ interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }
}
