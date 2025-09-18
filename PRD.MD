# PRD — Current Implementation (Tennis Trainer)

## Summary
SwiftUI iOS app that provides on-device pose and ball detection for tennis. Two modes: live camera analysis and offline video playback with overlays and audio cues.

## Modes & Flows
- Live Camera
  - Uses back camera (tries 120 fps) with `AVCaptureSession` and preview layer.
  - Overlays right-shoulder/elbow/wrist joints and a predicted tennis-ball position.
  - HUD shows FPS, frame count, recording status; controls: `Start/Stop`, `Test Beep`.
  - Requires camera permission (a “Request Permission” button is shown but does not trigger a request; permission handled at init).
- Video Playback
  - Pick video via Photos picker; file is copied to a temp URL; video audio is muted.
  - Displays 16:9 player with joint and ball overlays, time slider, `Play/Pause`, `Choose New Video`.
  - Handles orientation via track transform; periodic time observer updates current time.

## Detection & Feedback
- Pose (Vision)
  - `VNDetectHumanBodyPoseRequest` (rev 1). Tracks right shoulder/elbow/wrist when confidence > 0.3.
  - Computes upper‑arm and forearm angles relative to horizontal; values shown in UI.
- Forearm Horizontal Detector
  - Zones: below 270–355°, dead‑zone 355–5°, above 5–90°.
  - Triggers a beep only on upward crossing (below → above) with a 0.5 s cooldown.
- Ball Detection (GridTrackNet; default)
  - 5-frame model, inputs: RGB 768×432 (resized), frames ordered oldest→newest.
  - Outputs: `conf`, `x_off`, `y_off` shaped [5, 48 (W), 27 (H)]; FP16 tensors.
  - Decoding (per t): argmax on `conf[t,:,:]` → (row,col); pixel: `x=(col+x_off)*16`, `y=(row+y_off)*16`; normalized to 768×432.
  - Target frame `t=2` (middle) for accuracy. Config in `GridTrackNetDetector`.
- Ball Detection (color + Kalman; fallback)
  - Heuristic color thresholding + small Kalman filter; can be toggled via `AppConfig.ballDetectionMethod`.

## Audio
- Synthesizes an ~800 Hz, ~0.2 s beep via `AVAudioEngine`/`AVAudioPlayerNode` (category `.playAndRecord`, defaults to speaker, Bluetooth allowed). Beep plays when detector signals.

## Performance & Threading
- Camera frames processed on a session queue; video frames via `AVPlayerItemVideoOutput` + `CADisplayLink`. Late frames discarded.

## Configuration
- `AppConfig.ballDetectionMethod` selects GridTrackNet (default) or ColorKalman.
- GridTrackNet model lives at `Tennis Trainer/Models/GridTrackNet5.mlpackage`; reconvert with `convert_gridtracknet.py`.

## Testing (Current State)
- Unit tests: Swift “Testing” framework scaffold present but empty.
- UI tests: XCTest scaffolds present (launch and placeholder test).

## Contact Point Detection (Design Notes)
Assumptions and scope for first implementation:
- Training context: camera placement ensures the player’s body does not occlude racket–ball contact.
- Scope: right‑handed forehands only for the initial version.
- Goal: determine whether the player’s forearm is roughly horizontal at the exact moment of ball–racket contact.
