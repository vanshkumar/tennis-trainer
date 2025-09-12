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
- Ball Detection (color + Kalman)
  - Scans BGRA pixels with stride 4; tennis‑ball heuristic: g≥150, b≤100, r≥105, r+g+b≥380, (g−r)≥20, (g−b)≥60.
  - Gating: search to the right of right shoulder (+0.02) and within radius 0.06 of the Kalman prediction.
  - 1D Kalman on x/y (q=30, r=0.0003), predictive overlay lead ≈1/60 s; clears after 3 misses.

## Audio
- Synthesizes an ~800 Hz, ~0.2 s beep via `AVAudioEngine`/`AVAudioPlayerNode` (category `.playAndRecord`, defaults to speaker, Bluetooth allowed). Beep plays when detector signals.

## Performance & Threading
- Camera frames processed on a session queue; video frames via `AVPlayerItemVideoOutput` + `CADisplayLink`. Late frames discarded.

## Testing (Current State)
- Unit tests: Swift “Testing” framework scaffold present but empty.
- UI tests: XCTest scaffolds present (launch and placeholder test).

