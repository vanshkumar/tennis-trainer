import Foundation

enum BallDetectionMethod {
    case colorKalman
    case gridTrackNet
}

// Global app configuration flags.
// Toggle these at build time to switch behaviors.
struct AppConfig {
    // Choose which detector handles ball tracking for the app.
    // GridTrackNet is the default; color+Kalman remains available as a fallback.
    static let ballDetectionMethod: BallDetectionMethod = .gridTrackNet
}
