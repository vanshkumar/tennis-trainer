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

The repository is now aligned around the serve-training product:
- `ServeTossApexDetector` drives the beep from the GridTrackNet sample stream.
- The older forehand heuristic is parked under `Tennis Trainer/Archived/Forehand/FOREHAND_ARCHIVE.md` for future revival.

## Code Layout

- `Tennis Trainer/ContentView.swift`
  Wires the app together, selects mode, renders overlays and controls.
- `Tennis Trainer/CameraManager.swift`
  Owns the live camera capture session and sends frames into pose + ball detection.
- `Tennis Trainer/VideoPlayerManager.swift`
  Owns AVPlayer playback and frame extraction for offline analysis.
- `Tennis Trainer/PoseDetectionManager.swift`
  Runs Vision pose detection and exposes tracked joints plus retained arm-angle helpers for future stroke work.
- `Tennis Trainer/BallDetectionManager.swift`
  Chooses the active ball detector backend, admits one analysis job through publication, and exposes ball tracking plus the automatic toss cue.
- `Tennis Trainer/AnalysisFrame.swift`
  Owns prepared frame pixels and immutable source identity, rational media time, orientation, geometry, and pose metadata for a five-frame prediction window.
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

1. `ContentView` creates `CameraManager`, `PoseDetectionManager`, and `AudioManager`.
2. `CameraManager` receives frames from `AVCaptureVideoDataOutput` and supplies the sample buffer's presentation timestamp to `BallDetectionManager`.
3. The manager admits at most one job before scheduling pose extraction and ball analysis. New frames are dropped while that job or its publication is pending.
4. Pose extraction and ball preparation use the same admitted image. GridTrackNet predicts from an owned five-frame window, whose decoded samples retain their original metadata.
5. The manager publishes current results, feeds `ServeTossApexDetector`, and emits `onApex` when an eligible toss peak is confirmed. Its admission lease remains held through publication.
6. `ContentView` receives the apex callback and calls `AudioManager.playBeep()`.

### Video Playback

1. `VideoPlayerManager` loads a local video into `AVPlayer`.
2. `AVPlayerItemVideoOutput` exposes a frame on each display-link tick. Analysis uses the acquired frame's returned display time, rather than the requested player time.
3. `VideoPlayerManager` submits the image, media time, and orientation to the same bounded `BallDetectionManager` pipeline used for live capture.
4. The manager rejects invalid or repeated media times before expensive work, extracts matching pose, and analyzes an owned prediction window.
5. Current publication feeds `ServeTossApexDetector` and emits `onApex` for an eligible peak.
6. `ContentView` receives the apex callback and calls `AudioManager.playBeep()`.

## Detection Boundaries

### Orientation

- The app is portrait-only for the current v1 capture/playback experience.
- Portrait capture makes it easier to keep the full serve toss in frame.
- Pose and ball detection should consume the same oriented frame space in playback.
- Portrait frames are fit into the GridTrackNet model canvas to preserve the toss arc, and decoded ball positions are mapped back to the oriented source frame.
- `CameraPreview` keeps the live preview layer aligned to the active interface orientation.
- Re-enabling landscape should include crop-aware overlay mapping and explicit playback fill/framing validation.

### Pose

- Implemented with `VNDetectHumanBodyPoseRequest`.
- Current tracked joints cover the right arm plus `nose`/`neck` for the toss height gate.
- The shared Vision request is serialized. Extraction returns a frame-tagged value; missing or invalid pose is explicit.
- `detectedPose` is presentation state for overlays. Cue eligibility uses the candidate frame's own pose metadata, not the latest overlay pose. Missing or mismatched pose uses the existing strict height fallback.

### Ball

- Backend is selected by `AppConfig.ballDetectionMethod`.
- Default path is `gridTrackNet`.
- `GridTrackNetDetector` prepares app-owned pixels, applies caller-provided frame orientation, and predicts from an immutable five-frame window. Each decoded sample carries its originating frame's metadata.
- `BallDetectionManager.onBallTrack` remains an optional observation callback; the manager also feeds its built-in `ServeTossApexDetector` during guarded publication.
- `ServeTossApexDetector` consumes each source identity once, retains three samples for peak evaluation, and keeps its rational-time watermark after history eviction. The four-second cue cooldown is a separate rule.
- Manager-authorized source/generation resets invalidate old publication and reset the cue identity domain. Complete camera and playback control-transition acceptance belongs to Phase 2 of the reliability roadmap.

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
- `GRIDTRACKNET_COREML.md` for model conversion and decode details
- `docs/references/toss-cue-validation.md` for the preserved baseline, deterministic evidence, resource bounds, and outstanding clip/device/audio measurements
