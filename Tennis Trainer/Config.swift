import Foundation

enum BallDetectionMethod {
    case colorKalman
    case gridTrackNet
}

// Global app configuration flags.
// Toggle these at build time to switch behaviors.
struct AppConfig {
    // Select the active ball detection backend.
    // For now, default to the existing color+Kalman method.
    static let ballDetectionMethod: BallDetectionMethod = .colorKalman
}
