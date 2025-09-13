import Foundation
import CoreVideo
import CoreGraphics

class BallDetectionManager: ObservableObject {
    @Published var ballPosition: CGPoint? // Vision-normalized (origin bottom-left)

    private weak var poseDetectionManager: PoseDetectionManager?

    // Backends
    private let colorKalmanDetector = ColorKalmanBallDetector()
    // Future: private let gridTrackNetDetector = GridTrackNetDetector()

    init(poseDetectionManager: PoseDetectionManager?) {
        self.poseDetectionManager = poseDetectionManager
    }

    func process(pixelBuffer: CVPixelBuffer) {
        switch AppConfig.ballDetectionMethod {
        case .colorKalman:
            let pos = colorKalmanDetector.process(pixelBuffer: pixelBuffer, poseDetectionManager: poseDetectionManager)
            DispatchQueue.main.async { self.ballPosition = pos }
        case .gridTrackNet:
            // Not implemented yet. Clear any previous state/output.
            colorKalmanDetector.reset()
            DispatchQueue.main.async { self.ballPosition = nil }
        }
    }
}
