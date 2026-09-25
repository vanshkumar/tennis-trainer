# Architecture Research

**Domain:** On-device tennis toss-apex reliability, live camera and saved video
**Researched:** 2026-09-24
**Confidence:** MEDIUM — `query classify-confidence --provider websearch --verified`; source inspection plus Apple documentation, without runtime validation.

## Standard Architecture

### System Overview

Retain SwiftUI, the iOS 18.5 deployment target, current managers, and bundled GridTrackNet5. Strengthen contracts at existing boundaries; no replacement framework, database, service bus, or cloud component is needed. The following is a **recommended design**, not a description of completed implementation.

```text
ContentView: mode and presentation; serial main-thread lifecycle/publication
  ├─ CameraManager: permission, session queue, capture timestamps
  └─ VideoPlayerManager: player/item, display link, playback timestamps
          ↓ FrameEnvelope(source, generation, sequence, mediaTime, geometry)
  bounded preparation lane → PoseDetectionManager + frame preprocessing
          ↓ prepared frame with matching pose value
  BallDetectionManager → five-frame ring → immutable InferenceWindow
          ↓ bounded prediction lane
  GridTrackNetDetector → validated decoder → timestamped sample batch
          ↓ generation check on main thread
  ServeTossApexDetector → current-session apex event → AudioManager
          └─ shared rendered-image transform → ball/pose overlays
```

### Component Responsibilities

| Component | Owns | Contract change |
|-----------|------|-----------------|
| `CameraManager` | Authorization, capture configuration/start/stop, frame delivery | Keep session queue separate; stamp source time at callback ingress; invalidate before stopping |
| `VideoPlayerManager` | Item identity, loading, seeking, player, observers, display link, imported-file ownership | Gate every asynchronous completion by item/request identity; expose truthful state |
| `PoseDetectionManager` | Vision request and joint extraction | Serialize access to its shared request; return timestamped pose values, including explicit missing pose |
| `BallDetectionManager` | Admission, current generation, window scheduling, ball/cue integration | Remain the single ball/cue seam; accept immutable frame context and publish validated batches |
| `GridTrackNetDetector` | Model invocation, preprocessing mapping, tensor decode | Predict from a supplied window; never fetch mutable timestamps/mappings after prediction |
| `ServeTossApexDetector` | Ordered sample consumption, deduplication, peak/cooldown state | Receive sample-associated pose baseline; reset on temporal discontinuities |
| Preview/player adapters | Layer geometry and display orientation | Export a tested conversion into the exact overlay coordinate space |
| `ContentView` / `AudioManager` | Composition / actual feedback | Check current-session eligibility immediately before beep scheduling |

## Recommended Project Structure

Keep existing files and add only small value types/helpers where independently testable:

```text
Tennis Trainer/
├── FrameContext.swift                 # Source/generation/time/geometry values
├── OverlayTransform.swift             # Pure source-to-display geometry
├── BallDetectionManager.swift         # Admission and publication owner
├── PoseDetectionManager.swift         # Value-producing Vision boundary
├── CameraManager.swift                # Capture/authorization owner
├── VideoPlayerManager.swift           # Playback/resource owner
└── Detectors/GridTrackNetDetector.swift # Window input + shared tensor decoder
```

These names are proposals; nesting small types in existing files is acceptable. Preserve `*Manager` and `*View` conventions and the current automatically synchronized Xcode groups.

## Architectural Patterns

### Pattern 1: Immutable inference window with explicit ownership

**Recommendation:** Represent each prepared frame as one record containing its owned model buffer, source timestamp, sequence, generation, oriented dimensions, model-to-source mapping, and matching pose baseline. Capture exactly five ordered records as one window. Return decoded samples carrying the same metadata. Keep model execution serialized and outside any short admission lock.

Swift `let` does not make `CVPixelBuffer` storage immutable. Establish ownership: retain immutable buffers for the window lifetime or copy into app-owned buffers; never overwrite pooled storage while an inference still references it. Bound retained capture buffers and release promptly. Apple documents capture-buffer starvation when consumers retain buffers too long. [S1]

Preserve the existing 768×432, five-frame, FP16 model contract and per-output strides. Unify duplicate decoding paths. The current source uses portrait aspect-fit and nonportrait aspect-fill, despite the older blanket aspect-fill instruction in `AGENTS.md`; preserve current behavior while testing this discrepancy explicitly before changing preprocessing.

### Pattern 2: Bounded admission before enqueueing

**Recommendation:** Maintain one preparation job plus at most one replaceable newest pending frame, then one active prediction plus at most one replaceable newest ready window. Acquire admission before scheduling expensive work; an actor or serial queue alone does not bound its mailbox. Keep short gate operations independent of prediction.

The five-frame ring contains admitted, prepared frames, not five copies of the latest frame. A pending window is replaced atomically with its matching metadata. Account for overlapping windows in deduplication. Never reset the busy flag while an old worker still owns its slot; completion must release the matching request identity, not a newer generation's work.

This policy favors freshness over exhaustive processing. It can change temporal spacing and miss an apex under overload: preserve actual timestamps, record gaps/drop counts, and establish acceptable sampling through clips/device measurements. Start without a pending slot if that simpler policy meets measurements; do not silently promise accuracy at 120 FPS. Apple's late-frame discard applies to capture delivery, not arbitrary application queues. [S1, S2]

### Pattern 3: Generation invalidation at every publication boundary

**Recommendation:** Lifecycle transitions are serialized on the main thread. A small synchronized admission state exposes active source/generation to workers. Stop, pause, seek, replacement, end-of-item, and mode change first close admission/increment generation and clear visible/cue state; media teardown follows asynchronously.

Tag work before it can wait. Check the token before expensive processing, before accepting results, and inside the final main-thread closure before changing pose/ball state, consuming apex samples, or scheduling sound. A result that was valid before dispatch can become stale while its publication waits. Keep apex mutation and UI/audio publication on the same serial owner so reset cannot interleave between validation and consumption.

An already-running synchronous prediction may finish; ignore its output rather than depending on cancellation. Clear worker-owned rings in worker order, without blocking the UI behind inference. Invalidation prevents future scheduling; it cannot retract sound already emitted. If audio work is delayed internally, carry/check eligibility at that scheduling boundary too.

### Pattern 4: Pose pairing by frame identity

**Recommendation:** Produce pose and prepared ball input from the same admitted frame envelope. Retain the pose value with that frame across the five-frame window; the height gate for sample `t` uses pose `t`, not the latest published `detectedPose`. Refactor the cue input/provider accordingly without moving cue logic into views.

Represent missing or low-confidence pose explicitly and use the existing documented fallback gate. Do not reuse old nose/neck values indefinitely. If pose sampling is later reduced for performance, use a bounded timestamped cache and an experimentally chosen maximum age; that optimization is not needed for the initial contract. Serialize the shared Vision request even while an invalidated camera job drains and video starts.

## Data Flow

1. **Capture:** take `CMSampleBuffer` presentation time at ingress, along with generation and orientation; keep arrival monotonic time separately for latency. Current code timestamps after pose work via `CACurrentMediaTime`, so it does not currently preserve capture time.
2. **Playback:** query `hasNewPixelBuffer`, retain the copied buffer and returned `itemTimeForDisplay`, and preserve item identity. The output's returned display time is a better frame association than assuming requested `player.currentTime()` was the copied frame's timestamp. The SDK documents it as the true display deadline; validate clip deduplication using it. [S3]
3. **Analysis:** preparation produces paired pose/frame records; snapshot five; predict/decode; publish the complete generation-tagged sample batch. Keep media time for cue ordering/cooldown and a separate monotonic clock for execution latency; never compare playback time directly to host uptime.
4. **Feedback:** accepted ordered samples update apex state once; freshest valid sample drives the marker. Preserve current `t=4` overlays and all-five cue consumption until evidence supports changing them. A current-generation result may still be too old: define a measured maximum age/gap policy before claiming bounded cue latency.
5. **Reset:** lifecycle invalidation clears ring, dedupe, cooldown, pose, ball, and pending work for the old generation. Restart/replay begins with a fresh five-frame warmup; generations make repeated media times distinguishable.

### Rendered-image geometry

Use one documented coordinate chain: model canvas → oriented source normalized bottom-left → displayed image top-left → overlay-local points. Ball and pose share the final stages. Do not apply the model crop twice.

For playback `.resizeAspect`, observe/read `AVPlayerLayer.videoRect` after layout/readiness; convert its origin from layer to overlay coordinates. For a verified oriented source point `(x,y)`, place at `(rect.minX + x*rect.width, rect.minY + (1-y)*rect.height)`. Hide points while geometry is invalid; recompute after bounds/item changes. Apple defines `videoRect` using media aspect ratio, bounds, and gravity. [S4]

For camera `.resizeAspectFill`, use preview-layer conversion after explicitly adapting oriented Vision coordinates to unrotated capture-device coordinates, or a tested fill transform from the actual oriented source dimensions. The capture-device space is not identical to Vision's bottom-left oriented space. Clip cropped points; test orientation/mirroring exactly once and convert layer-local points into the SwiftUI overlay's space. [S5]

### Permission and player lifecycle ownership

`CameraManager` should model not-determined/authorized/denied/restricted plus configuring/ready/running/interrupted/failed states. Request access explicitly when appropriate; denied access exposes Settings recovery, restricted access explains its state, and foreground return rechecks authorization. Make configuration idempotent. Publish running state from actual session outcome, not merely the start button. Apple documents blocking startup and requires returning to main before permission-related UI changes. [S6, S7]

`VideoPlayerManager` should own a cancellable load task, item/load identity, seek identity, periodic observer's originating player, end observer token, video output, display link, and optional owned temporary URL. Reject outdated metadata-load completions. Seek closes analysis and only reopens it on a successful latest seek completion if playback is still intended; an interrupted seek reports `finished=false`. [S8]

Observe completion for the current item, marshal to main, invalidate analysis, stop the display link, and publish ended state. Replay performs a completed seek and fresh generation before starting analysis. End notifications may arrive on another thread. Make repeated play/pause/dispose idempotent; remove observers/output, invalidate display link, detach layer/player, then delete only app-owned copies. Do not rely solely on `deinit` for display-link teardown. [S9]

## Scaling Considerations

| Pressure | Architectural response | Measurement needed |
|----------|------------------------|--------------------|
| Slow model or thermal throttling | Fixed admission capacity; newest work replaces pending work | Queue age, inference duration, sampled-frame gaps |
| Main-thread stalls | Move pose/preprocessing out of playback display-link callback | UI responsiveness and capture-to-audio latency |
| Retained pixel buffers | Bounded frame/window ownership, early release | Peak memory and capture drop reasons |
| Rapid mode/seek/clip changes | Generation/item/request identities | Zero stale published events in adversarial tests |

This app scales with frame rate, device performance, and clip duration, not concurrent server users. Do not introduce multi-device coordination or a new concurrency framework for this milestone.

## Integration Points and Test Seams

| Boundary | Deterministic test seam | Required regression |
|----------|-------------------------|---------------------|
| Admission → inference | Inject a blocked fake predictor/executor | Many submitted frames keep fixed capacity; eventual output retains its own window metadata |
| Worker → publication | Hold/release scheduled completions | Stop/reset/mode switch between completion and publication emits no stale pose/ball/beep |
| Pose → cue | Value-based pose baseline per sample | Newer or missing pose cannot change the historical sample's gate |
| Tensor → source point | Fixture arrays with explicit strides/types/shapes | FP16 decoding, output validation, portrait padding and fill-crop inversion |
| Source → overlay | Pure transform fixtures plus layer integration checks | Corners/center across portrait, landscape media, padding, crop, rotation |
| Permission/player → state | Inject authorization, item loader, seek completions, audio event sink | Denial/recovery, canceled load/seek, end/replay, cleanup exactly once |

Keep fakes small and local; no generic dependency-injection container. Deterministic tests establish ordering/contracts; representative annotated clips and real devices establish detection quality, temporal spacing tolerance, and perceived beep delay.

## Implementation Order and Anti-Patterns

1. Define frame/source/generation/time/geometry contracts and fake prediction/publication seams; consolidate decoder validation.
2. Implement immutable windows and bounded lanes together; then pair pose values and serialize cue consumption. This establishes trustworthy result identity.
3. Wire invalidation into every camera/player/mode transition, including load/seek/end observers; finish permission/resource ownership. These paths depend on the shared generation contract.
4. Connect common overlay transforms to actual layer geometry. Pure geometry tests can run alongside lifecycle implementation after the coordinate contract is fixed.
5. Run clip/device acceptance measurements; tune pending capacity, frame-gap policy, and freshness limits from evidence. Do not tune the apex heuristic against incorrectly paired samples.

Avoid checking `isInFlight` only inside the queued closure, holding the model lock while stopping/resetting on main, reading timestamps after prediction, publishing before the final token check, treating cancellation as invalidation, or mapping points against full view bounds. Avoid adopting iOS 26/27 sample architecture/APIs wholesale for an iOS 18.5 app.

## Sources

All external findings are **MEDIUM** under the configured confidence seam; recommendations are engineering inferences. Retrieved 2026-09-24 local time. Current API pages generally do not expose publication dates; TN2445 is dated 2017-07-12 and was cross-checked with current property documentation.

- **S1:** [Apple TN2445: frame drops and buffer retention](https://developer.apple.com/library/archive/technotes/tn2445/_index.html).
- **S2:** [Apple: alwaysDiscardsLateVideoFrames](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput/alwaysdiscardslatevideoframes).
- **S3:** [Apple: AVPlayerItemVideoOutput](https://developer.apple.com/documentation/avfoundation/avplayeritemvideooutput), cross-checked with local iPhoneOS SDK `AVPlayerItemOutput.h` lines 219–236. Its newer deprecation annotation starts at iOS 27; retain the existing iOS 18.5-compatible API.
- **S4:** [Apple: AVPlayerLayer.videoRect](https://developer.apple.com/documentation/avfoundation/avplayerlayer/videorect).
- **S5:** [Apple: captureDevicePointConverted](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer/capturedevicepointconverted(fromlayerpoint:)); establishes unrotated capture coordinates and gravity-sensitive conversion.
- **S6:** [Apple: AVCaptureSession.startRunning](https://developer.apple.com/documentation/avfoundation/avcapturesession/startrunning()).
- **S7:** [Apple: camera requestAccess](https://developer.apple.com/documentation/avfoundation/avcapturedevice/requestaccess(for:completionhandler:)).
- **S8:** [Apple: seek completion and interruption](https://developer.apple.com/documentation/avfoundation/avplayer/seek(to:tolerancebefore:toleranceafter:completionhandler:)).
- **S9:** [Apple: end-of-item notification](https://developer.apple.com/documentation/avfoundation/avplayeritem/didplaytoendtimenotification).
- Local evidence: `.planning/PROJECT.md`, `.planning/codebase/{ARCHITECTURE,CONCERNS}.md`, and inspected `CameraManager.swift`, `VideoPlayerManager.swift`, `PoseDetectionManager.swift`, `BallDetectionManager.swift`, `Detectors/GridTrackNetDetector.swift`.

**Open validation questions:** safe admitted-frame gaps, maximum cue/overlay age, clip/device acceptance thresholds, exact preview orientation adaptation, and actual measured memory/latency. No framework guarantee establishes these app-specific values.
