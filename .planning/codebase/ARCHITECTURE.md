---
last_mapped_commit: 23b280cf14465d0418d5447422e949b1591f9024
last_mapped_at: 2026-09-19
---
<!-- refreshed: 2026-09-19 -->

# Architecture

**Analysis Date:** 2026-09-19

## System Overview

```text
Tennis_TrainerApp (`Tennis Trainer/Tennis_TrainerApp.swift`)
  -> ContentView (`Tennis Trainer/ContentView.swift`)
       -> Live: CameraManager -> PoseDetectionManager + BallDetectionManager
       -> Video: VideoPlayerManager -> PoseDetectionManager + BallDetectionManager
       -> BallDetectionManager -> GridTrackNetDetector or ColorKalmanBallDetector
       -> ServeTossApexDetector -> AudioManager
       -> SwiftUI overlays (`ContentView.swift`), AV preview/player adapters
```

`ContentView` is the composition root. It owns four `@StateObject` managers, wires the shared `PoseDetectionManager` into both capture modes, and connects apex callbacks to `AudioManager.playBeep()` (`Tennis Trainer/ContentView.swift:16-97`). The app has no repository, networking, or persistence layer; runtime state is held in observable managers and AVFoundation/Vision/Core ML objects.

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| App entry | Creates the SwiftUI window and root view | `Tennis Trainer/Tennis_TrainerApp.swift` |
| Composition/UI | Selects live/video mode, presents controls and normalized-coordinate overlays | `Tennis Trainer/ContentView.swift` |
| Live capture | Configures camera permission, session, 120 FPS output, lifecycle, and frame dispatch | `Tennis Trainer/CameraManager.swift` |
| Video playback | Owns `AVPlayer`, video output, display link, playback state, and extracted-frame analysis | `Tennis Trainer/VideoPlayerManager.swift` |
| Pose analysis | Runs `VNDetectHumanBodyPoseRequest`; publishes recognized joints and toss-height baseline | `Tennis Trainer/PoseDetectionManager.swift` |
| Ball orchestration | Selects configured backend, publishes ball position, serializes ML inference, and emits apex events | `Tennis Trainer/BallDetectionManager.swift` |
| Grid inference | Maintains five-frame temporal input, runs Core ML, decodes FP16 heads, and maps positions to source coordinates | `Tennis Trainer/Detectors/GridTrackNetDetector.swift` |
| Color fallback | Thresholds BGRA pixels and smooths a normalized position with a 1D-per-axis Kalman filter | `Tennis Trainer/Detectors/ColorKalmanBallDetector.swift` |
| Cue detection | Finds high-confidence local vertical maxima with pose/frame-relative height gates and cooldown | `Tennis Trainer/Detectors/ServeTossApexDetector.swift` |
| Audio output | Builds a short generated beep using `AVAudioEngine` | `Tennis Trainer/AudioManager.swift` |
| Frame geometry | Applies orientation and aspect-fit/fill scaling with Core Image | `Tennis Trainer/PixelBufferScaler.swift` |

## Pattern Overview

**Overall:** SwiftUI MVVM-style composition around manager-owned AVFoundation/Vision/Core ML services, with callback seams for frame completion and apex events.

**Key Characteristics:**

- `ContentView` owns long-lived managers with `@StateObject`; managers publish UI state through `ObservableObject`/`@Published`.
- Camera and video managers perform media I/O, while detector types own inference and signal processing.
- `BallDetectionManager` is the stable boundary between frame sources and ball/cue algorithms; choose the backend through `AppConfig.ballDetectionMethod` (`Tennis Trainer/Config.swift:3-13`).
- Normalized Vision coordinates use bottom-left origin internally; SwiftUI overlays flip Y when positioning circles (`Tennis Trainer/ContentView.swift:118-133`, `Tennis Trainer/ContentView.swift:246-261`).

## Layers

**Presentation and composition:**

- Purpose: Render controls, previews, loading states, and detection overlays; connect user actions to managers.
- Location: `Tennis Trainer/ContentView.swift`, `Tennis Trainer/CameraPreview.swift`, `Tennis Trainer/VideoPlayerView.swift`, `Tennis Trainer/VideoPickerView.swift`.
- Contains: SwiftUI views and UIKit representables for AV layers.
- Depends on: Observable manager state and callbacks.
- Used by: `Tennis Trainer/Tennis_TrainerApp.swift`.

**Media sources:**

- Purpose: Produce oriented pixel buffers and manage playback/capture lifecycle.
- Location: `Tennis Trainer/CameraManager.swift`, `Tennis Trainer/VideoPlayerManager.swift`.
- Contains: AVCapture session delegate and AVPlayer display-link extraction.
- Depends on: pose and ball managers; `AVFoundation`; `PixelBufferScaler` indirectly through detectors.
- Used by: `ContentView`.

**Analysis services:**

- Purpose: Convert frames into pose, ball, and toss-cue state.
- Location: `Tennis Trainer/PoseDetectionManager.swift`, `Tennis Trainer/BallDetectionManager.swift`, `Tennis Trainer/Detectors/`.
- Contains: Vision request handling, Core ML temporal buffering, color/Kalman fallback, and apex state machine.
- Depends on: Core ML/Vision/Core Video and shared normalized-coordinate contracts.
- Used by: media sources and presentation callbacks.

**Platform output:**

- Purpose: Emit user feedback and display AV content.
- Location: `Tennis Trainer/AudioManager.swift`, `Tennis Trainer/CameraPreview.swift`, `Tennis Trainer/VideoPlayerView.swift`.
- Contains: AVAudioEngine beep and layer-hosting representables.
- Depends on: AVFoundation/UIKit/SwiftUI.
- Used by: `ContentView` and the two media managers.

## Data Flow

### Live Camera Request Path

1. `ContentView` wires dependencies in `.onAppear` and starts capture from the mode/action handlers (`Tennis Trainer/ContentView.swift:53-89`, `Tennis Trainer/ContentView.swift:368-387`).
2. `CameraManager` configures `AVCaptureVideoDataOutput` on `sessionQueue` and receives buffers on `videoProcessingQueue` (`Tennis Trainer/CameraManager.swift:11-20`, `Tennis Trainer/CameraManager.swift:63-82`).
3. `captureOutput` gates stopped frames, runs pose detection with `.right`, then submits the same buffer to `BallDetectionManager` (`Tennis Trainer/CameraManager.swift:177-195`).
4. `BallDetectionManager` either runs the color detector immediately or appends a frame to GridTrackNet’s five-frame buffer and schedules one inference on `ml.ball.gridtracknet` (`Tennis Trainer/BallDetectionManager.swift:45-90`).
5. The ball position, track samples, and apex callback return to the main queue; `ContentView` updates overlays and calls `AudioManager.playBeep()` (`Tennis Trainer/BallDetectionManager.swift:80-87`, `Tennis Trainer/ContentView.swift:83-88`).

### Video Playback Request Path

1. `VideoPickerView` copies the selected `public.movie` representation into the temporary directory and publishes its URL on the main queue (`Tennis Trainer/VideoPickerView.swift:31-65`).
2. `ContentView` observes the URL and calls `VideoPlayerManager.loadVideo` (`Tennis Trainer/ContentView.swift:90-93`).
3. `VideoPlayerManager` creates a muted `AVPlayer`, adds `AVPlayerItemVideoOutput`, loads duration asynchronously, and starts a `CADisplayLink` when playback begins (`Tennis Trainer/VideoPlayerManager.swift:23-63`, `Tennis Trainer/VideoPlayerManager.swift:77-85`, `Tennis Trainer/VideoPlayerManager.swift:144-155`).
4. Each display-link tick extracts the current pixel buffer, derives `preferredTransform` orientation, runs pose and ball analysis, and reports a processed frame (`Tennis Trainer/VideoPlayerManager.swift:87-110`).
5. The same `BallDetectionManager` apex seam drives the shared audio callback; seek/reset/cleanup clear detector temporal state (`Tennis Trainer/VideoPlayerManager.swift:172-183`, `Tennis Trainer/VideoPlayerManager.swift:215-245`).

### GridTrackNet Decode and Coordinate Flow

1. `GridTrackNetDetector.pushFrame` applies display orientation and stores five frames, timestamps, and a per-frame source mapping (`Tennis Trainer/Detectors/GridTrackNetDetector.swift:66-168`).
2. Portrait sources use aspect-fit into 768×432 with padding; non-portrait sources use aspect-fill and center crop. The mapping reverses that scale/offset.
3. `predictIfReady` supplies `f1`…`f5` to `GridTrackNet5` and reads `conf`, `x_off`, and `y_off` (`Tennis Trainer/Detectors/GridTrackNetDetector.swift:176-207`).
4. The decoder identifies tensor dimensions and uses each output’s own strides, argmaxes each frame on the confidence grid, maps offsets to 768×432 pixels, then normalizes to Vision space with bottom-left origin (`Tennis Trainer/Detectors/GridTrackNetDetector.swift:317-415`).
5. Camera and video setup explicitly construct `BallDetectionManager` with `overlayTIndex: 4` for the freshest visible marker; its initializer otherwise defaults to 2 (`Tennis Trainer/CameraManager.swift:206`, `Tennis Trainer/VideoPlayerManager.swift:208`). `ServeTossApexDetector` consumes all five timestamped samples (`Tennis Trainer/BallDetectionManager.swift:79-87`).

**State Management:**

- SwiftUI-visible state is published by managers and mutated on the main queue where callbacks affect UI (`Tennis Trainer/CameraManager.swift:126-132`, `Tennis Trainer/BallDetectionManager.swift:80-100`).
- `CameraManager` protects its stop/start frame gate with `NSLock`; session lifecycle and frame processing use separate serial queues (`Tennis Trainer/CameraManager.swift:11-15`).
- GridTrackNet’s frame arrays/model access are serialized by `ml.gridtracknet.detector`; `BallDetectionManager` runs inference on a serial queue. Its `isInFlight` flag is checked and reset inside queued work, so it does not bound pending requests (`Tennis Trainer/Detectors/GridTrackNetDetector.swift:62-64`, `Tennis Trainer/BallDetectionManager.swift:72-90`). Prediction and input metadata are read in separate synchronized operations; see `CONCERNS.md` for that consistency risk.
- Video playback/display-link and AVPlayer state are main-run-loop oriented; asynchronous asset loading returns through `MainActor.run` (`Tennis Trainer/VideoPlayerManager.swift:42-60`).

## Key Abstractions

**Normalized point contract:**

- Purpose: Share ball and pose locations between Vision analysis and SwiftUI overlays.
- Examples: `PoseDetectionManager.detectedPose`, `BallDetectionManager.ballPosition`, `GridTrackNetDetector.Sample.position`.
- Pattern: Store Vision-space coordinates with origin at bottom-left; flip Y only at SwiftUI placement.

**Ball detector seam:**

- Purpose: Allow active backend changes without changing camera/video callers.
- Examples: `BallDetectionManager.process`, `BallDetectionManager.onBallTrack`, `Tennis Trainer/Config.swift`.
- Pattern: Select the backend by enum; preserve `onBallTrack`/`onApex` for higher-level consumers.

**Five-frame sample stream:**

- Purpose: Separate temporal inference from visible overlay latency and toss-cue detection.
- Examples: `GridTrackNetDetector.Sample`, `GridTrackNetDetector.detectAllSamplesIfReady`, `ServeTossApexDetector.consume`.
- Pattern: Keep samples ordered oldest-to-newest with source timestamps and confidence.

## Entry Points

**Application:**

- Location: `Tennis Trainer/Tennis_TrainerApp.swift`.
- Triggers: iOS launches the SwiftUI `App`.
- Responsibilities: Creates `WindowGroup` containing `ContentView`.

**Composition root:**

- Location: `Tennis Trainer/ContentView.swift`.
- Triggers: App view lifecycle, mode picker, playback/capture buttons, video picker.
- Responsibilities: Dependency wiring, mode transitions, rendering, and user feedback callback wiring.

**Camera delegate:**

- Location: `Tennis Trainer/CameraManager.swift:177-195`.
- Triggers: `AVCaptureVideoDataOutput` callbacks.
- Responsibilities: Gate and route each camera frame to pose and ball processing.

**Playback display link:**

- Location: `Tennis Trainer/VideoPlayerManager.swift:87-110`.
- Triggers: `CADisplayLink` while `isPlaying`.
- Responsibilities: Extract and analyze the frame corresponding to the AVPlayer time.

## Architectural Constraints

- **Threading:** AV capture session lifecycle runs on `camera.session.queue`; capture analysis runs on `camera.video.processing.queue`; GridTrackNet inference runs on `ml.ball.gridtracknet`, with detector storage serialized by `ml.gridtracknet.detector` (`Tennis Trainer/CameraManager.swift:11-15`, `Tennis Trainer/BallDetectionManager.swift:16-18`).
- **UI mutation:** Published state and callbacks that drive SwiftUI are dispatched to the main queue (`Tennis Trainer/PoseDetectionManager.swift:26-28`, `Tennis Trainer/BallDetectionManager.swift:81-87`).
- **Coordinate spaces:** Keep Vision bottom-left normalized coordinates internally; use `PixelBufferScaler`/`FrameMapping` for orientation and model-canvas conversion; flip Y for SwiftUI (`Tennis Trainer/PixelBufferScaler.swift:100-120`, `Tennis Trainer/ContentView.swift:118-133`).
- **Temporal state:** Seeking, replacing a video, or switching tracking sessions must call `BallDetectionManager.resetTrackingState` to clear five-frame and apex buffers (`Tennis Trainer/VideoPlayerManager.swift:172-183`, `Tennis Trainer/BallDetectionManager.swift:94-100`).
- **Target integration:** The Xcode target uses `PBXFileSystemSynchronizedRootGroup`, so files under `Tennis Trainer/` are discovered without per-file project entries (`Tennis Trainer.xcodeproj/project.pbxproj:32-48`, `Tennis Trainer.xcodeproj/project.pbxproj:97-118`).

## Anti-Patterns

### Domain logic in `ContentView`

**What happens:** `ContentView` currently owns mode transitions, FPS bookkeeping, and direct callback wiring alongside layout (`Tennis Trainer/ContentView.swift:53-97`, `Tennis Trainer/ContentView.swift:368-408`).
**Why it's wrong:** New detection rules or lifecycle work here couple UI rendering to runtime services.
**Do this instead:** Put capture/video behavior in the relevant `*Manager` and cue algorithms in `Tennis Trainer/Detectors/`; keep `ContentView` as the composition and presentation boundary.

### Direct detector coupling from media sources

**What happens:** Camera and video callers pass frames to `BallDetectionManager`, which is the intended seam; bypassing it would expose GridTrackNet/color backend details to both sources.
**Why it's wrong:** Backend selection and apex state would be duplicated across live and playback paths.
**Do this instead:** Extend `BallDetectionManager` and preserve its normalized position and callback contracts (`Tennis Trainer/BallDetectionManager.swift:32-101`).

## Error Handling

**Strategy:** Guard invalid permissions, unavailable AV devices, malformed model outputs, missing pixel buffers, and failed asset/model operations; log failures with `print` and return/skip the affected frame.

**Patterns:**

- AV setup uses early `guard` exits and commits capture configuration before returning (`Tennis Trainer/CameraManager.swift:47-61`).
- Vision/Core ML failures are caught locally; detection continues on later frames (`Tennis Trainer/PoseDetectionManager.swift:21-31`, `Tennis Trainer/Detectors/GridTrackNetDetector.swift:178-207`).
- Detection thresholds yield `nil` positions rather than synthetic coordinates (`Tennis Trainer/Detectors/GridTrackNetDetector.swift:300-314`, `Tennis Trainer/Detectors/ColorKalmanBallDetector.swift:133-143`).

## Cross-Cutting Concerns

**Logging:** Error-only `print` statements are present in camera, audio, picker, pose, and Core ML paths; avoid adding per-frame diagnostics (`Tennis Trainer/CameraManager.swift`, `Tennis Trainer/AudioManager.swift`, `Tennis Trainer/Detectors/GridTrackNetDetector.swift`).
**Validation:** Vision joint confidence, ball confidence, model tensor shape, pixel-buffer dimensions, and model readiness are checked at boundaries (`Tennis Trainer/PoseDetectionManager.swift:44-49`, `Tennis Trainer/Detectors/GridTrackNetDetector.swift:331-355`).
**Authentication:** Not applicable; the app has no user identity or remote service.

---

*Architecture analysis: 2026-09-19*
