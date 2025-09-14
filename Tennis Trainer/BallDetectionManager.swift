import Foundation
import CoreVideo
import CoreGraphics

class BallDetectionManager: ObservableObject {
    @Published var ballPosition: CGPoint? // Vision-normalized (origin bottom-left)

    private weak var poseDetectionManager: PoseDetectionManager?

    // Backends
    private let colorKalmanDetector = ColorKalmanBallDetector()
    private let gridTrackNetDetector = GridTrackNetDetector()

    init(poseDetectionManager: PoseDetectionManager?) {
        self.poseDetectionManager = poseDetectionManager
    }

    func process(pixelBuffer: CVPixelBuffer) {
        switch AppConfig.ballDetectionMethod {
        case .colorKalman:
            let pos = colorKalmanDetector.process(pixelBuffer: pixelBuffer, poseDetectionManager: poseDetectionManager)
            DispatchQueue.main.async { self.ballPosition = pos }
        case .gridTrackNet:
            // Feed frames; when ready, run detection and publish a normalized point.
            colorKalmanDetector.reset()
            gridTrackNetDetector.pushFrame(pixelBuffer)
            let pos = gridTrackNetDetector.isReady ? gridTrackNetDetector.detectNormalizedPositionIfReady() : nil
            DispatchQueue.main.async { self.ballPosition = pos }
        }
    }
}
