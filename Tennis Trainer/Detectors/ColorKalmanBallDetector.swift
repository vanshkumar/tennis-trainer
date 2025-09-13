import Foundation
import CoreVideo
import QuartzCore

final class ColorKalmanBallDetector {
    // MARK: - Internal State
    private struct Kalman1D {
        var p: Double = 0
        var v: Double = 0
        var P00: Double = 1
        var P01: Double = 0
        var P10: Double = 0
        var P11: Double = 1
        let q: Double
        let r: Double

        mutating func reset(to z: Double) {
            p = z
            v = 0
            P00 = 10; P01 = 0; P10 = 0; P11 = 10
        }

        mutating func predict(dt: Double) {
            let dt2 = dt * dt
            let dt3 = dt2 * dt
            let dt4 = dt2 * dt2
            let q00 = q * dt4 / 4
            let q01 = q * dt3 / 2
            let q10 = q * dt3 / 2
            let q11 = q * dt2

            let P00n = P00 + dt*(P10 + P01) + dt2*P11 + q00
            let P01n = P01 + dt*P11 + q01
            let P10n = P10 + dt*P11 + q10
            let P11n = P11 + q11
            P00 = P00n; P01 = P01n; P10 = P10n; P11 = P11n
            p = p + v * dt
        }

        mutating func update(z: Double) {
            let S = P00 + r
            let K0 = P00 / S
            let K1 = P10 / S
            let y = z - p
            p += K0 * y
            v += K1 * y
            let P00n = (1 - K0) * P00
            let P01n = (1 - K0) * P01
            let P10n = -K1 * P00 + P10
            let P11n = -K1 * P01 + P11
            P00 = P00n; P01 = P01n; P10 = P10n; P11 = P11n
        }
    }

    // Tunables
    private let sampleStride: Int = 4
    private let minGreen: UInt8 = 150
    private let minRed: UInt8 = 105
    private let maxBlue: UInt8 = 100
    private let minBrightnessSum: Int = 380
    private let shoulderMargin: CGFloat = 0.02
    private let gateRadius: CGFloat = 0.06
    private let leadTime: Double = 1.0 / 60.0
    private let maxPredictionMisses = 3

    // Kalman state
    private var missCount = 0
    private var kfX = Kalman1D(q: 30.0, r: 0.0003)
    private var kfY = Kalman1D(q: 30.0, r: 0.0003)
    private var hasKF = false
    private var lastTime: CFTimeInterval?

    func reset() {
        hasKF = false
        missCount = 0
        lastTime = nil
    }

    // MARK: - Public API
    // Returns normalized Vision-space point (origin bottom-left), or nil.
    func process(pixelBuffer: CVPixelBuffer, poseDetectionManager: PoseDetectionManager?) -> CGPoint? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        var shoulderX: CGFloat? = nil
        if let sx = poseDetectionManager?.getJointPosition(for: .rightShoulder)?.x {
            shoulderX = sx + shoulderMargin
        }

        var sumX: Double = 0
        var sumY: Double = 0
        var count: Int = 0

        let now = CACurrentMediaTime()
        var dtEstimate = 1.0 / 60.0
        if let lt = lastTime { dtEstimate = max(1.0/240.0, min(1.0/15.0, now - lt)) }
        var gateCenter: CGPoint? = nil
        if hasKF { gateCenter = CGPoint(x: kfX.p + kfX.v * dtEstimate, y: kfY.p + kfY.v * dtEstimate) }

        for y in stride(from: 0, to: height, by: sampleStride) {
            let row = base.advanced(by: y * bytesPerRow)
            for x in stride(from: 0, to: width, by: sampleStride) {
                let xn = CGFloat(x) / CGFloat(width)
                let yn = 1.0 - (CGFloat(y) / CGFloat(height))
                if let sx = shoulderX, xn < sx { continue }
                if let gc = gateCenter {
                    let dx = xn - gc.x
                    let dy = yn - gc.y
                    if dx*dx + dy*dy > gateRadius*gateRadius { continue }
                }
                let pixel = row.advanced(by: x * 4)
                let b = pixel.load(fromByteOffset: 0, as: UInt8.self)
                let g = pixel.load(fromByteOffset: 1, as: UInt8.self)
                let r = pixel.load(fromByteOffset: 2, as: UInt8.self)
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

        let dt = dtEstimate
        lastTime = now

        if count > 0 {
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
            return CGPoint(x: kfX.p + kfX.v * leadTime, y: kfY.p + kfY.v * leadTime)
        } else {
            if hasKF && missCount < maxPredictionMisses {
                kfX.predict(dt: dt)
                kfY.predict(dt: dt)
                missCount += 1
                return CGPoint(x: kfX.p + kfX.v * leadTime, y: kfY.p + kfY.v * leadTime)
            } else {
                reset()
                return nil
            }
        }
    }
}

