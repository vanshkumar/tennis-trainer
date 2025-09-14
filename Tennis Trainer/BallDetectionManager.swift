import Foundation
import CoreVideo
import CoreGraphics

class BallDetectionManager: ObservableObject {
    @Published var ballPosition: CGPoint? // Vision-normalized (origin bottom-left)

    private weak var poseDetectionManager: PoseDetectionManager?

    // Backends
    private let colorKalmanDetector = ColorKalmanBallDetector()
    private let gridTrackNetDetector = GridTrackNetDetector()
    private var logCount = 0

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
            logCount += 1
            if logCount % 30 == 0 {
                if let p = pos {
                    print(String(format: "Ball pos (norm) x=%.3f y=%.3f", p.x, p.y))
                } else {
                    print("Ball pos: nil (no detection)")
                }
            }
            DispatchQueue.main.async { self.ballPosition = pos }
        }
    }
}
