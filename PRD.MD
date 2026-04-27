# PRD — Tennis Trainer

## Summary
SwiftUI iOS app that provides on-device pose and ball detection for tennis. Two modes: live camera analysis and offline video playback with overlays and audio cues. The product is framed as a tennis trainer; the **current focus is the serve**, and the active feedback cue is **a beep at the apex of the player's toss**.

## Modes & Flows
- **Live Camera**
  - Uses back camera (tries 120 fps) with `AVCaptureSession` and preview layer.
  - Overlays right-shoulder/elbow/wrist joints and a predicted tennis-ball position.
  - HUD shows FPS, frame count, recording status; controls: `Start/Stop`, `Test Beep`.
  - Requires camera permission (a "Request Permission" button is shown but does not trigger a request; permission is handled at init).
- **Video Playback**
  - Pick video via Photos picker; file is copied to a temp URL; video audio is muted.
  - Displays 16:9 player with joint and ball overlays, time slider, `Play/Pause`, `Choose New Video`.
  - Handles orientation via track transform; periodic time observer updates current time.
  - **Primary use case**: testing the detector against downloaded pro serve footage from YouTube. Keep clips short (a few serves) for fast iteration.

## Detection & Feedback

### Pose (Vision)
- `VNDetectHumanBodyPoseRequest` (rev 1). Joints currently collected with confidence > 0.3: nose, neck, right shoulder, right elbow, right wrist.
- Computes upper-arm and forearm angles relative to horizontal; values currently shown in the HUD.
- `nose` and `neck` provide the pose-relative height gate used by the toss-apex detector.

### Ball — GridTrackNet (default)
- 5-frame model. Inputs: RGB 768×432 (resized aspect-fill, no letterbox), frames ordered oldest → newest.
- Outputs: `conf`, `x_off`, `y_off` shaped `[5, 48 (W), 27 (H)]`; FP16.
- Decoding (per `t`): argmax on `conf[t,:,:]` → `(row, col)`; pixel `x = (col + x_off) * 16`, `y = (row + y_off) * 16`; normalized to 768×432; threshold 0.5.
- Live mode renders the freshest frame index (`t = 4`); video mode renders the middle (`t = 2`) for lower jitter.
- All five samples per inference are emitted with timestamps via `BallDetectionManager.onBallTrack` for downstream consumers (e.g., the toss-apex detector).
- See `GRIDTRACKNET_COREML.md` for full model I/O and conversion details.

### Ball — Color + Kalman (fallback)
- Heuristic green-pixel threshold gated by right-shoulder x and a predicted Kalman center; 2-state position+velocity Kalman per axis.
- Toggled via `AppConfig.ballDetectionMethod`.

### Serve Toss Apex Detector (current cue)
- **Input**: stream of `(timestamp, ball_y_normalized, confidence)` from `BallDetectionManager.onBallTrack` (5 samples per inference, deduplicated by timestamp across overlapping inference windows).
- **Buffer**: rolling window of the most recent ~1.5 s of samples.
- **Apex condition** (all must hold):
  1. A sample `s` exists in the buffer such that `s.y` is greater than both its immediate-prior and immediate-next sample (local max in time).
  2. `s.y` exceeds a height threshold:
     - **Pose-relative (preferred)**: `s.y > nose.y + 0.05` in normalized space; if `nose` confidence is too low, try `neck`; if both fail, fall back to:
     - **Frame-relative**: `s.y > 0.70` (top ~30% of the frame).
  3. `s.confidence ≥ 0.5` (matches the GridTrackNet decoder threshold).
  4. Cooldown of 4 s elapsed since last beep.
- **Trigger time**: beep fires as soon as the local-max condition can be confirmed (i.e., the moment the next sample arrives lower). At 60 fps this is ~16–33 ms after the true apex; acceptable as "real-time."
- **No rally gating** in v1 — solo practice only.

## Audio
Synthesizes an ~800 Hz, ~0.2 s beep via `AVAudioEngine` / `AVAudioPlayerNode` (category `.playAndRecord`, defaults to speaker, Bluetooth allowed). Beep plays when the active cue fires.

## Camera placement
**Recommended**: side-on, on the toss-arm side of the player (i.e., for a right-handed server, the camera sits to the player's right). This view captures toss arc, trophy position, and contact in 2D.

Behind-the-player framing also works for the toss apex cue specifically (the ball still goes up and comes down) but loses depth/lateral information needed for trophy and contact cues, so it isn't recommended going forward. Per-stroke "camera modes" with different recommended placements are anticipated as future work.

## Performance & Threading
- Camera frames processed on a dedicated session queue; video frames pulled via `AVPlayerItemVideoOutput` + `CADisplayLink` on main. Late frames are discarded.
- GridTrackNet inference runs on a dedicated `ml.ball.gridtracknet` queue with a single-flight gate; if a previous inference is still running, the new frame is dropped (only the buffer is updated).

## Configuration
- `AppConfig.ballDetectionMethod` selects GridTrackNet (default) or ColorKalman.
- GridTrackNet model lives at `Tennis Trainer/Models/GridTrackNet5.mlpackage`; reconvert with `convert_gridtracknet.py`.

## Scope & Assumptions
- **Stroke**: serve only.
- **Handedness**: right-handed only.
- **Practice mode**: solo. No rally gating; the ball detector assumes the only ball motion of interest is the player's own toss.
- **Setup**: phone on a tripod, side-on framing as above, full body in frame, ball clearly visible against a non-busy background.

## Roadmap (future work)
- **Trophy position** cue: detect the loaded trophy moment (right elbow above shoulder, racket dropped behind back as a wrist-below-elbow proxy since the racket isn't tracked). Builds on the same pose seam as toss apex.
- **Contact-on-serve**: easier than forehand contact because the ball trajectory after the apex is constrained — heuristics like ball-y descending + wrist-y rising + minimum ball-wrist distance are tractable without racket detection.
- **Multi-stroke support** (forehand, etc.). Forehand revival starts from the parked code documented in `Tennis Trainer/Archived/Forehand/FOREHAND_ARCHIVE.md`.

## Implementation status
The toss-apex detector is implemented. The original forehand cue code is parked under `Tennis Trainer/Archived/Forehand/FOREHAND_ARCHIVE.md`.

## Testing (current state)
- Unit tests: `ServeTossApexDetectorTests` covers synthetic parabolic tosses, cooldown behavior, pose-relative suppression, and low-confidence peaks.
- CLI unit-test scheme: `Tennis Trainer`.
- UI tests: XCTest scaffolds present (launch and placeholder test).
- CLI UI-test scheme: `Tennis Trainer UI Tests`.
