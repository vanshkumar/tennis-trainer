import Foundation
import CoreVideo
import CoreGraphics
import QuartzCore
import ImageIO
import CoreMedia

class BallDetectionManager: ObservableObject {
    struct Input {
        let pixelBuffer: CVPixelBuffer
        let sourceTime: CMTime
        let orientation: CGImagePropertyOrientation
        let sourceID: UUID
    }

    struct FrameIdentity: Equatable {
        let sourceID: UUID
        let generation: UUID
        let sequence: UInt64
        let sourceTime: CMTime
    }

    struct Analysis {
        let samples: [GridTrackNetDetector.Sample]?
        let position: CGPoint?
    }

    struct Dependencies {
        var analyze: (Input, FrameIdentity) throws -> Analysis
        var reset: () -> Void = {}
        var worker: (@escaping () -> Void) -> Void
        var publication: (@escaping () -> Void) -> Void
    }

    private var dependencies: Dependencies?
    var onFrameProcessed: (() -> Void)?

    init(dependencies: Dependencies, overlayTIndex: Int = 4) {
        self.dependencies = dependencies
        self.overlayTIndex = overlayTIndex
    }

    @discardableResult
    func process(input: Input) -> Bool {
        return false
    }
    @Published var ballPosition: CGPoint? // Vision-normalized (origin bottom-left)

    private weak var poseDetectionManager: PoseDetectionManager?

    // Backends
    private lazy var colorKalmanDetector = ColorKalmanBallDetector()
    private lazy var gridTrackNetDetector = GridTrackNetDetector()

    // Async inference plumbing (minimal): a dedicated queue and in-flight gate.
    private let detectionQueue = DispatchQueue(label: "ml.ball.gridtracknet", qos: .userInitiated)
    private var isInFlight = false
    private let apexDetector = ServeTossApexDetector()

    // Optional: structured track callback (five samples per inference)
    var onBallTrack: (([GridTrackNetDetector.Sample]) -> Void)?
    var onApex: (() -> Void)?

    private let overlayTIndex: Int

    init(poseDetectionManager: PoseDetectionManager?, overlayTIndex: Int = 2) {
        self.poseDetectionManager = poseDetectionManager
        self.overlayTIndex = overlayTIndex
    }

    func process(pixelBuffer: CVPixelBuffer) {
        // Default timestamp; callers can use the overload with an explicit time.
        process(pixelBuffer: pixelBuffer, timestamp: CACurrentMediaTime())
    }

    func process(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        process(
            pixelBuffer: pixelBuffer,
            timestamp: CACurrentMediaTime(),
            orientation: orientation
        )
    }

    func process(
        pixelBuffer: CVPixelBuffer,
        timestamp: CFTimeInterval,
        orientation: CGImagePropertyOrientation = .up
    ) {
        switch AppConfig.ballDetectionMethod {
        case .colorKalman:
            let analysisBuffer = PixelBufferScaler.shared.copyApplyingOrientation(
                pixelBuffer,
                orientation: orientation
            ) ?? pixelBuffer
            let pos = colorKalmanDetector.process(
                pixelBuffer: analysisBuffer,
                poseDetectionManager: poseDetectionManager
            )
            apexDetector.reset()
            DispatchQueue.main.async { self.ballPosition = pos }

        case .gridTrackNet:
            // Feed frames on caller thread (as before), and only offload inference.
            colorKalmanDetector.reset()
            gridTrackNetDetector.pushFrame(
                pixelBuffer,
                timestamp: timestamp,
                orientation: orientation
            )

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
                    DispatchQueue.main.async {
                        self.onBallTrack?(samples)
                        if self.apexDetector.consume(samples: samples, heightGateProvider: self.poseDetectionManager) {
                            self.onApex?()
                        }
                    }
                }
            }
        }
    }

    func resetTrackingState() {
        if let dependencies { dependencies.reset(); return }
        colorKalmanDetector.reset()
        gridTrackNetDetector.clear()
        apexDetector.reset()
        DispatchQueue.main.async {
            self.ballPosition = nil
        }
    }
}
