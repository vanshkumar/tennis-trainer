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
- The opt-in Backhand drill uses `BackhandCueManager` for a calibrated, projected hand-travel/top-arm-extension marker. It does not detect impact or grade a stroke.
- The older forehand heuristic is parked under `Tennis Trainer/Archived/Forehand/FOREHAND_ARCHIVE.md` for future revival.

## Code Layout

- `Tennis Trainer/ContentView.swift`
  Wires the app together, selects mode, renders overlays and controls.
- `Tennis Trainer/CameraManager.swift`
  Owns camera authorization, capture intent and actual session state, and admits current frames into pose + ball detection.
- `Tennis Trainer/VideoPlayerManager.swift`
  Owns AVPlayer playback, candidate validation, seek/timeline identity and frame extraction for offline analysis.
- `Tennis Trainer/VideoImportManager.swift`
  Copies temporary picker representations into uniquely named app-owned files and tracks their consumer leases.
- `Tennis Trainer/AppRuntime.swift`
  Constructs production services or explicit DEBUG UI scenarios with injected effects before camera, model or audio setup.
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
- `Tennis Trainer/BackhandCueManager.swift` and `BackhandCueView.swift`
  Own two-pose calibration, the C3 movement state machine, and its setup/status diagram. Live and playback have separate managers and in-memory references.
- `Tennis Trainer/BackhandGuideView.swift` and `BackhandPoseIllustration.swift`
  Provide the visual quick start for camera placement, reference poses, swing order and sound-off comparison trials. The guide adapts to live/video mode; opening it stops capture and pauses playback until explicit Start/Play.
- `Tennis TrainerTests/`
  Unit test target.
- `Tennis TrainerUITests/`
  UI test target.

## Runtime Flow

### Live Camera

1. `ContentView` creates a camera service, a camera-owned pose presenter, and `AudioManager`. Playback has its own pose presenter.
2. `CameraManager` constructs one immutable production capture backend before preview or session queues can access it; injected managers omit that backend. It checks current authorization, then reconciles explicit capture intent with actual session state. Starting is distinct from running; Stop remains available during startup and recovery. Denied access offers Settings, restricted access explains the restriction, and active return requeries permission without creating new capture intent.
3. Before a new capture run opens, the session queue stops capture and detaches delivery, then drains the separate callback queue. Received frames carry their captured analysis generation and sample-buffer presentation timestamp into `BallDetectionManager`.
4. Admission compares the expected generation under the scheduler lock and admits at most one job through publication. New frames are dropped while that lease is held.
5. Pose extraction and ball preparation use the same admitted image. GridTrackNet predicts from an owned five-frame window, whose decoded samples retain their original metadata.
6. Current publication feeds `ServeTossApexDetector` and emits `onApex` for an eligible peak; `ContentView` calls `AudioManager.playBeep()`.

### Video Playback

1. The picker copies its temporary representation inside the provider callback through `VideoImportManager`. Each import uses a unique owned path; external files never acquire deletion authority.
2. `VideoPlayerManager` pauses the committed session while a replacement candidate loads. Only the current request with playable video, finite positive duration and a ready item may replace it. Failure or cancellation preserves the prior paused clip.
3. `AVPlayerItemVideoOutput` exposes a frame on each display-link tick. Analysis uses the acquired frame's returned display time, rather than the requested player time.
4. `VideoPlayerManager` submits the image, media time, and orientation to the same bounded `BallDetectionManager` pipeline used for live capture.
5. The manager rejects invalid or repeated media times before expensive work, extracts matching pose, and analyzes an owned prediction window.
6. Current publication feeds `ServeTossApexDetector` and emits `onApex` for an eligible peak; `ContentView` calls `AudioManager.playBeep()`.
7. Retiring a playback session removes its original observer, output, layer and loop. Outstanding asynchronous consumers keep media leases until they finish; an owned file is removed only after its last lease is released.

### Practice Controls

- Stop, Pause, mode exit and scene suspension close frame admission and invalidate analysis before asynchronous framework teardown. Scene return restores eligibility; it does not recreate cleared Start/Play intent. Explicit live-mode entry retains its Start behavior.
- Each mode owns its pose presentation, and the ball overlay observes its analysis manager directly. An old mode's clearing publication cannot erase the active mode's pose.
- Camera session events retain their originating operation and reconcile current permission, intent and backend state after delivery. Recovery is limited to one automatic attempt per explicit Start; failure exposes Retry.
- Seeking closes analysis immediately. Only the latest successful seek on the current item may reopen it, and only while Play remains requested. Invalid targets fail closed; a failed seek requires an explicit retry.
- Playback event registrations retain their load and timeline identity. Native end/error notifications are reconciled against fresh backend state; an old event cannot stop a newer seek or Replay on the same item.
- Ended stops processing. Replay seeks to zero through the completion gate and starts a fresh analysis window and cue cooldown. A weak display-link target and explicit retirement keep one intended extraction loop.
- These implemented control contracts have deterministic and UI regression coverage. Physical permission, capture, local-media inspection and audio timing remain separate acceptance evidence.

### Backhand Prototype

- Selecting Backhand stops ingress, selects pose-only analysis inside the existing bounded `BallDetectionManager`, and resumes the selected source if it was running. Serve retains its existing ball/apex path.
- Guarded per-frame observations include pose identity, oriented dimensions and ingress time. The backhand manager uses equal-scale, shoulder-relative coordinates and a fixed reference arm scale, not the existing normalized segment headings.
- Ready and checkpoint references define forward direction, travel and top-arm extension. The detector requires ready, backward hand travel, forward travel and a confirmed checkpoint, then rearms at ready. Missing/late pose, gaps and lifecycle changes retire attempts.
- Live setup captures the latest fresh pose after a countdown. Paused-video setup independently extracts an oriented image at the selected time, holds its media lease through Vision, and rejects results after timeline/source changes. It never enters the automatic cue stream.
- Setup is retained across Stop/Pause/Replay; a new clip or changed image aspect clears it. Physical camera movement requires Recalibrate. The arm diagram is separate from the unfinished preview overlay geometry.
- Sound-off trials still count markers. Stop/Pause/seek/drill changes cancel pending node buffers; sound already buffered by an output route may finish. Physical event-to-ear latency and stroke accuracy are unmeasured.

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
- Current tracked joints cover both shoulders, elbows and wrists, plus `nose`/`neck` for the toss height gate.
- The shared Vision request is serialized. Extraction returns a frame-tagged value; missing or invalid pose is explicit.
- `detectedPose` is presentation state for overlays. Cue eligibility uses the candidate frame's own pose metadata, not the latest overlay pose. Missing or mismatched pose uses the existing strict height fallback.

### Ball

- Backend is selected by `AppConfig.ballDetectionMethod`.
- Default path is `gridTrackNet`.
- `GridTrackNetDetector` prepares app-owned pixels, applies caller-provided frame orientation, and predicts from an immutable five-frame window. Each decoded sample carries its originating frame's metadata.
- `BallDetectionManager.onBallTrack` remains an optional observation callback; the manager also feeds its built-in `ServeTossApexDetector` during guarded publication.
- `ServeTossApexDetector` consumes each source identity once, retains three samples for peak evaluation, and keeps its rational-time watermark after history eviction. The four-second cue cooldown is a separate rule.
- Manager-authorized source/generation resets invalidate old publication and reset the cue identity domain. The single lease remains held until obsolete work and its publication finish; resetting does not reopen scheduler capacity early.

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
- `docs/references/practice-controls-validation.md` for control/import evidence and pending device and human acceptance checks
