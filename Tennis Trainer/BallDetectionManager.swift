import Foundation
import CoreVideo
import CoreGraphics

class BallDetectionManager: ObservableObject {
    @Published var ballPosition: CGPoint? // Vision-normalized (origin bottom-left)

    private weak var poseDetectionManager: PoseDetectionManager?

    // Backends
    private let colorKalmanDetector = ColorKalmanBallDetector()
    private let gridTrackNetDetector = GridTrackNetDetector()

    // Async inference plumbing (minimal): a dedicated queue and in-flight gate.
    private let detectionQueue = DispatchQueue(label: "ml.ball.gridtracknet", qos: .userInitiated)
    private var isInFlight = false

    init(poseDetectionManager: PoseDetectionManager?) {
        self.poseDetectionManager = poseDetectionManager
    }

    func process(pixelBuffer: CVPixelBuffer) {
        switch AppConfig.ballDetectionMethod {
        case .colorKalman:
            let pos = colorKalmanDetector.process(pixelBuffer: pixelBuffer, poseDetectionManager: poseDetectionManager)
            DispatchQueue.main.async { self.ballPosition = pos }

        case .gridTrackNet:
            // Feed frames on caller thread (as before), and only offload inference.
            colorKalmanDetector.reset()
            gridTrackNetDetector.pushFrame(pixelBuffer)

            detectionQueue.async { [weak self] in
                guard let self = self else { return }
                if self.isInFlight { return }
                self.isInFlight = true
                defer { self.isInFlight = false }

                guard self.gridTrackNetDetector.isReady else { return }
                let pos = self.gridTrackNetDetector.detectNormalizedPositionIfReady()
                DispatchQueue.main.async { self.ballPosition = pos }
            }
        }
    }
}
