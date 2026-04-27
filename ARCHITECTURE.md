# Architecture

Top-level map of the app as it exists today. This file is intentionally short: it should help an agent or engineer find the right code quickly, not duplicate every product or implementation detail.

## Purpose

`Tennis Trainer` is a SwiftUI iPhone app for tennis practice feedback. It currently supports:
- live camera analysis
- offline video playback analysis
- on-device pose detection
- on-device ball detection
- audio feedback triggered by a motion cue

## Current Product vs Code Reality

The repository documentation has pivoted to a serve-training product whose primary cue should be "beep at toss apex."

The live Swift implementation still uses the older forehand heuristic:
- `ForearmHorizontalDetector` drives the beep today.
- `SERVE_PIVOT_IMPL.md` is the active migration brief for replacing it with a serve toss-apex detector.

Treat that mismatch as intentional in-repo state, not accidental drift.

## Code Layout

- `Tennis Trainer/ContentView.swift`
  Wires the app together, selects mode, renders overlays and controls.
- `Tennis Trainer/CameraManager.swift`
  Owns the live camera capture session and sends frames into pose + ball detection.
- `Tennis Trainer/VideoPlayerManager.swift`
  Owns AVPlayer playback and frame extraction for offline analysis.
- `Tennis Trainer/PoseDetectionManager.swift`
  Runs Vision pose detection and computes right-arm angles used by the current cue.
- `Tennis Trainer/BallDetectionManager.swift`
  Chooses the active ball detector backend and exposes the current ball position plus optional track callbacks.
- `Tennis Trainer/Detectors/GridTrackNetDetector.swift`
  Core ML wrapper for the 5-frame GridTrackNet model.
- `Tennis Trainer/Detectors/ColorKalmanBallDetector.swift`
  Simpler fallback detector based on color thresholding + Kalman smoothing.
- `Tennis Trainer/AudioManager.swift`
  Generates and plays the app beep.
- `Tennis TrainerTests/`
  Unit test target.
- `Tennis TrainerUITests/`
  UI test target.

## Runtime Flow

### Live Camera

1. `ContentView` creates `CameraManager`, `PoseDetectionManager`, `BallDetectionManager`, and `AudioManager`.
2. `CameraManager` receives camera frames from `AVCaptureVideoDataOutput`.
3. Each frame is sent to:
   - `PoseDetectionManager.detectPose(...)`
   - `BallDetectionManager.process(...)`
4. `CameraManager` currently computes `shouldBeep` from `ForearmHorizontalDetector`.
5. `ContentView` receives the callback and calls `AudioManager.playBeep()`.

### Video Playback

1. `VideoPlayerManager` loads a local video into `AVPlayer`.
2. `AVPlayerItemVideoOutput` exposes the current frame on each display-link tick.
3. Each frame is sent to:
   - `PoseDetectionManager.detectPose(...)`
   - `BallDetectionManager.process(..., timestamp:)`
4. `VideoPlayerManager` currently computes `shouldBeep` from `ForearmHorizontalDetector`.
5. `ContentView` receives the callback and calls `AudioManager.playBeep()`.

## Detection Boundaries

### Pose

- Implemented with `VNDetectHumanBodyPoseRequest`.
- Current tracked joints are focused on arm motion rather than full serve semantics.
- `detectedPose` is shared UI/runtime state for overlays and cue logic.

### Ball

- Backend is selected by `AppConfig.ballDetectionMethod`.
- Default path is `gridTrackNet`.
- `GridTrackNetDetector` keeps a 5-frame temporal window and emits one decoded sample per frame index.
- `BallDetectionManager.onBallTrack` is the seam intended for higher-level detectors such as serve toss-apex logic.

## Architectural Boundaries

The codebase is small, so the main boundary to preserve is responsibility separation rather than heavy layering:
- `*Manager` types own runtime services, I/O, and state.
- detector types own inference or signal-processing logic.
- `ContentView` wires dependencies and presents UI, but should avoid accumulating domain logic.
- product/cue-specific heuristics should live in dedicated detector types rather than inside camera/video managers.

## Documentation Pointers

- `docs/README.md` for the documentation map
- `README.md` for the user-facing product framing
- `PRD.MD` for current product behavior/spec
- `SERVE_PIVOT_IMPL.md` for the active serve migration plan
- `GRIDTRACKNET_COREML.md` for model conversion and decode details
