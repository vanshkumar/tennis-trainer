import Foundation
import CoreVideo
import Vision
import CoreMedia
import QuartzCore

private struct Kalman1D {
    // State: position (p), velocity (v)
    var p: Double = 0
    var v: Double = 0
    // Covariance matrix P (2x2)
    var P00: Double = 1
    var P01: Double = 0
    var P10: Double = 0
    var P11: Double = 1
    // Noise parameters
    let q: Double   // process (acceleration) noise intensity
    let r: Double   // measurement noise variance

    mutating func reset(to z: Double) {
        p = z
        v = 0
        P00 = 10; P01 = 0; P10 = 0; P11 = 10
    }

    mutating func predict(dt: Double) {
        // F = [[1, dt], [0, 1]]
        // Q for constant acceleration model
        let dt2 = dt * dt
        let dt3 = dt2 * dt
        let dt4 = dt2 * dt2
        let q00 = q * dt4 / 4
        let q01 = q * dt3 / 2
        let q10 = q * dt3 / 2
        let q11 = q * dt2

        // State prediction
        p = p + v * dt
        // v = v (no change)

        // Covariance prediction: P = F*P*F^T + Q
        let P00n = P00 + dt*(P10 + P01) + dt2*P11 + q00
        let P01n = P01 + dt*P11 + q01
        let P10n = P10 + dt*P11 + q10
        let P11n = P11 + q11
        P00 = P00n; P01 = P01n; P10 = P10n; P11 = P11n
    }

    mutating func update(z: Double) {
        // H = [1, 0]
        // S = H*P*H^T + R = P00 + r
        let S = P00 + r
        let K0 = P00 / S // Kalman gain for position
        let K1 = P10 / S // Kalman gain for velocity
        let y = z - p    // innovation

        // State update
        p += K0 * y
        v += K1 * y

        // Covariance update: P = (I - K*H) * P
        // (I - K*H) = [[1-K0, 0], [-K1, 1]] with H=[1,0]
        let P00n = (1 - K0) * P00
        let P01n = (1 - K0) * P01
        let P10n = -K1 * P00 + P10
        let P11n = -K1 * P01 + P11
        P00 = P00n; P01 = P01n; P10 = P10n; P11 = P11n
    }
}

class BallDetectionManager: ObservableObject {
    @Published var ballPosition: CGPoint? // Vision-normalized (origin bottom-left)

    private weak var poseDetectionManager: PoseDetectionManager?

    // Tunables
    private let sampleStride: Int = 4 // sample every N pixels for speed
    private let minGreen: UInt8 = 150
    private let minRed: UInt8 = 105
    private let maxBlue: UInt8 = 100
    private let minBrightnessSum: Int = 380 // r+g+b should exceed this
    private let shoulderMargin: CGFloat = 0.02
    private let gateRadius: CGFloat = 0.06 // tighter gating radius
    private let leadTime: Double = 1.0 / 60.0 // predictive lead for overlay
    // Kalman filter settings
    private let maxPredictionMisses = 3
    private var missCount = 0
    private var kfX = Kalman1D(q: 30.0, r: 0.0003)
    private var kfY = Kalman1D(q: 30.0, r: 0.0003)
    private var hasKF = false
    private var lastTime: CFTimeInterval?

    init(poseDetectionManager: PoseDetectionManager?) {
        self.poseDetectionManager = poseDetectionManager
    }

    func process(pixelBuffer: CVPixelBuffer) {
        // Feature selection gate: only run this path when color+Kalman is selected.
        guard AppConfig.ballDetectionMethod == .colorKalman else {
            // Clear any stale state/output when disabled.
            hasKF = false
            missCount = 0
            lastTime = nil
            DispatchQueue.main.async { self.ballPosition = nil }
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        // Optional gating: only search to right of right shoulder
        var shoulderX: CGFloat? = nil
        if let sx = poseDetectionManager?.getJointPosition(for: .rightShoulder)?.x {
            shoulderX = sx + shoulderMargin
        }

        var sumX: Double = 0
        var sumY: Double = 0
        var count: Int = 0

        // Estimate dt for gating prediction (do not commit lastTime yet)
        let now = CACurrentMediaTime()
        var dtEstimate = 1.0 / 60.0
        if let lt = lastTime {
            dtEstimate = max(1.0/240.0, min(1.0/15.0, now - lt))
        }
        var gateCenter: CGPoint? = nil
        if hasKF {
            gateCenter = CGPoint(x: kfX.p + kfX.v * dtEstimate, y: kfY.p + kfY.v * dtEstimate)
        }

        for y in Swift.stride(from: 0, to: height, by: sampleStride) {
            let row = base.advanced(by: y * bytesPerRow)
            for x in Swift.stride(from: 0, to: width, by: sampleStride) {
                let xn = CGFloat(x) / CGFloat(width)
                let yn = 1.0 - (CGFloat(y) / CGFloat(height))
                if let sx = shoulderX, xn < sx { continue }
                if let gc = gateCenter {
                    let dx = xn - gc.x
                    let dy = yn - gc.y
                    if dx*dx + dy*dy > gateRadius*gateRadius { continue }
                }
                let pixel = row.advanced(by: x * 4)
                // BGRA
                let b = pixel.load(fromByteOffset: 0, as: UInt8.self)
                let g = pixel.load(fromByteOffset: 1, as: UInt8.self)
                let r = pixel.load(fromByteOffset: 2, as: UInt8.self)
                // Tennis ball heuristic: bright yellow-green, strong green dominance over red/blue, low blue
                if g >= minGreen && b <= maxBlue {
                    let gi = Int(g), ri = Int(r), bi = Int(b)
                    let sum = ri + gi + bi
                    if sum >= minBrightnessSum {
                        let greenOverRed = gi - ri
                        let greenOverBlue = gi - bi
                        if greenOverRed >= 20 && greenOverBlue >= 60 && ri >= Int(minRed) {
                            sumX += Double(x)
                            sumY += Double(y)
                            count += 1
                        }
                    }
                }
            }
        }

        // Compute dt and commit timestamp
        let dt = dtEstimate
        lastTime = now

        if count > 0 {
            // Measurement in normalized coords
            let mx = (sumX / Double(count)) / Double(width)
            let my = 1.0 - ((sumY / Double(count)) / Double(height))

            if !hasKF {
                kfX.reset(to: mx)
                kfY.reset(to: my)
                hasKF = true
            } else {
                kfX.predict(dt: dt)
                kfY.predict(dt: dt)
            }
            kfX.update(z: mx)
            kfY.update(z: my)
            missCount = 0

            // Predict slightly ahead for overlay to reduce lag
            let pos = CGPoint(x: kfX.p + kfX.v * leadTime, y: kfY.p + kfY.v * leadTime)
            DispatchQueue.main.async { self.ballPosition = pos }
        } else {
            // No measurement this frame: predict for a few frames, then clear
            if hasKF && missCount < maxPredictionMisses {
                kfX.predict(dt: dt)
                kfY.predict(dt: dt)
                missCount += 1
                let pos = CGPoint(x: kfX.p + kfX.v * leadTime, y: kfY.p + kfY.v * leadTime)
                DispatchQueue.main.async { self.ballPosition = pos }
            } else {
                hasKF = false
                missCount = 0
                DispatchQueue.main.async { self.ballPosition = nil }
            }
        }
    }
}
