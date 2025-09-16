import Foundation
import CoreVideo
import CoreGraphics
import QuartzCore

class BallDetectionManager: ObservableObject {
    @Published var ballPosition: CGPoint? // Vision-normalized (origin bottom-left)

    private weak var poseDetectionManager: PoseDetectionManager?

    // Backends
    private let colorKalmanDetector = ColorKalmanBallDetector()
    private let gridTrackNetDetector = GridTrackNetDetector()

    // Async inference plumbing (minimal): a dedicated queue and in-flight gate.
    private let detectionQueue = DispatchQueue(label: "ml.ball.gridtracknet", qos: .userInitiated)
    private var isInFlight = false

    // Optional: structured track callback (five samples per inference)
    var onBallTrack: (([GridTrackNetDetector.Sample]) -> Void)?

    private let overlayTIndex: Int

    init(poseDetectionManager: PoseDetectionManager?, overlayTIndex: Int = 2) {
        self.poseDetectionManager = poseDetectionManager
        self.overlayTIndex = overlayTIndex
    }

    func process(pixelBuffer: CVPixelBuffer) {
        // Default timestamp; callers can use the overload with an explicit time.
        process(pixelBuffer: pixelBuffer, timestamp: CACurrentMediaTime())
    }

    func process(pixelBuffer: CVPixelBuffer, timestamp: CFTimeInterval) {
        switch AppConfig.ballDetectionMethod {
        case .colorKalman:
            let pos = colorKalmanDetector.process(pixelBuffer: pixelBuffer, poseDetectionManager: poseDetectionManager)
            DispatchQueue.main.async { self.ballPosition = pos }

        case .gridTrackNet:
            // Feed frames on caller thread (as before), and only offload inference.
            colorKalmanDetector.reset()
            gridTrackNetDetector.pushFrame(pixelBuffer, timestamp: timestamp)

            detectionQueue.async { [weak self] in
                guard let self = self else { return }
                if self.isInFlight { return }
                self.isInFlight = true
                defer { self.isInFlight = false }

                guard self.gridTrackNetDetector.isReady else { return }
                if let samples = self.gridTrackNetDetector.detectAllSamplesIfReady() {
                    if let s = samples.first(where: { $0.tIndex == self.overlayTIndex }) {
                        DispatchQueue.main.async { self.ballPosition = s.position }
                    }
                    if let cb = self.onBallTrack {
                        DispatchQueue.main.async { cb(samples) }
                    }
                }
            }
        }
    }
}
