---
last_mapped_commit: 23b280cf14465d0418d5447422e949b1591f9024
last_mapped_at: 2026-09-19
---
# Codebase Concerns

**Analysis Date:** 2026-09-19

This map comes from static source inspection. No build, tests, profiling, or device reproduction was performed; runtime impacts below require verification.

## Tech Debt

**Detector lifecycle and concurrency boundary:**

- Issue: `BallDetectionManager.process` appends a new five-frame window before dispatching inference, while `GridTrackNetDetector.detectAllSamplesIfReady` snapshots model outputs and then separately reads `frameMappings` and timestamps. A frame can be pushed between those two synchronized sections, so positions and timestamps can be mapped with metadata from a newer window than the pixels used for inference.
- Files: `Tennis Trainer/BallDetectionManager.swift:63-89`, `Tennis Trainer/Detectors/GridTrackNetDetector.swift:176-203`, `Tennis Trainer/Detectors/GridTrackNetDetector.swift:312-315`, `Tennis Trainer/Detectors/GridTrackNetDetector.swift:392-414`
- Impact: Static race window can produce incorrectly mapped ball coordinates or non-corresponding sample times, directly affecting overlays and toss-apex timing under live capture.
- Fix approach: Snapshot frames, timestamps, and mappings as one immutable inference input/result under the detector’s synchronization boundary, or return metadata from the same synchronized operation as prediction.

**Mode switching leaves detector work in flight:**

- Issue: Switching modes stops capture or pauses video, but `BallDetectionManager.resetTrackingState()` clears state while an already queued GridTrackNet inference may still complete and invoke `onBallTrack`/`onApex` afterward.
- Files: `Tennis Trainer/ContentView.swift:368-387`, `Tennis Trainer/CameraManager.swift:141-151`, `Tennis Trainer/VideoPlayerManager.swift:157-161`, `Tennis Trainer/BallDetectionManager.swift:72-100`
- Impact: A stale sample from the previous mode can update the new mode’s ball overlay or emit an unexpected beep after reset.
- Fix approach: Add a generation/token to detector requests and discard results whose generation no longer matches, including already queued main-thread callbacks; serialize reset with detector state changes.

**Temporary imported videos accumulate:**

- Issue: `VideoPickerView` copies every selected movie into the shared temporary directory, and `VideoPlayerManager.cleanup()` releases the player but never deletes the copied file.
- Files: `Tennis Trainer/VideoPickerView.swift:50-61`, `Tennis Trainer/VideoPlayerManager.swift:215-245`
- Impact: Repeated clip selection can consume temporary storage until the OS purges it; the app has no ownership record for cleanup.
- Fix approach: Track the currently copied URL and remove it when replacing or disposing of a video, while preserving externally owned URLs if that API is later reused.

**Placeholder permission action:**

- Issue: The visible “Request Permission” button has an empty action. Permission is requested only during `CameraManager` initialization, so a denied user cannot retry or be directed to Settings from the displayed control.
- Files: `Tennis Trainer/ContentView.swift:197-209`, `Tennis Trainer/CameraManager.swift:29-49`
- Impact: The primary recovery path shown to users does nothing after denial or when initialization occurs before the user expects the prompt.
- Fix approach: Expose an explicit permission request/recheck operation from `CameraManager`, and make the button call it or open the app’s Settings page for `.denied`.

## Known Bugs

**Video playback display link does not observe end-of-item:**

- Symptoms: `isPlaying` remains true and the display link continues to be scheduled after the player reaches the end because playback completion is never observed.
- Files: `Tennis Trainer/VideoPlayerManager.swift:77-85`, `Tennis Trainer/VideoPlayerManager.swift:144-160`
- Trigger: Play a selected video through its natural end without pressing Pause.
- Workaround: Press Pause manually or choose another video.

**Overlay coordinates are not crop-aware for the rendered video/preview:**

- Symptoms: Ball and pose points are multiplied directly by the full `GeometryReader` bounds, while the camera preview uses `.resizeAspectFill` and video uses a 16:9 `.aspectRatio(..., .fit)` container with an `AVPlayerLayer` using `.resizeAspect`.
- Files: `Tennis Trainer/ContentView.swift:100-135`, `Tennis Trainer/ContentView.swift:214-265`, `Tennis Trainer/CameraPreview.swift:26-28`, `Tennis Trainer/VideoPlayerManager.swift:192-196`
- Trigger: Use portrait source frames or any source/container aspect ratio that differs from the display region.
- Workaround: Keep the capture framing and video canvas at matching aspect ratios; this does not correct portrait fit/crop offsets.

## Security Considerations

**Camera permission recovery and user intent:**

- Risk: The UI implies that tapping the button requests camera access, but no request or Settings handoff occurs.
- Files: `Tennis Trainer/ContentView.swift:197-209`, `Tennis Trainer/CameraManager.swift:29-49`
- Current mitigation: The system authorization request is made for `.notDetermined` during manager initialization.
- Recommendations: Make authorization state transitions explicit and provide the correct system recovery path for denied/restricted states.

## Performance Bottlenecks

**Synchronous Core Image preprocessing on the capture callback queue:**

- Problem: Every live frame is oriented and, once the five-frame window is ready, resized through Core Image before the callback returns.
- Files: `Tennis Trainer/CameraManager.swift:177-195`, `Tennis Trainer/BallDetectionManager.swift:63-70`, `Tennis Trainer/Detectors/GridTrackNetDetector.swift:90-168`
- Cause: `CameraManager` uses `videoProcessingQueue` for frame callbacks and `pushFrame` performs `sync.sync` plus orientation/resizing work on that same queue.
- Improvement path: Measure callback latency and move expensive preprocessing to a bounded worker stage, preserving ordering and a generation-safe reset; keep the existing late-frame discard behavior.

## Fragile Areas

**GridTrackNet tensor shape and coordinate decoding:**

- Files: `Tennis Trainer/Detectors/GridTrackNetDetector.swift:214-315`, `Tennis Trainer/Detectors/GridTrackNetDetector.swift:326-414`
- Why fragile: Dimension discovery is heuristic, but `idxWithStrides` builds its index vector from `conf.shape` and applies `xOff`/`yOff` strides without validating that all three arrays have identical rank and dimension ordering. The two decode paths duplicate this logic.
- Safe modification: Keep tensor shape/stride validation in one decoder, test representative `[5,27,48]` and `[1,5,27,48]` layouts, and retain per-array strides when indexing.
- Test coverage: No tests exercise Core ML tensor decoding, orientation, aspect-fit/fill mapping, or stride/layout variants.

**Shared mutable UI/runtime state from asynchronous callbacks:**

- Files: `Tennis Trainer/PoseDetectionManager.swift:17-31`, `Tennis Trainer/BallDetectionManager.swift:80-88`, `Tennis Trainer/ContentView.swift:59-88`
- Why fragile: Pose and ball callbacks independently dispatch to the main queue; delayed results can arrive out of frame order, and mode changes do not invalidate queued callbacks.
- Safe modification: Associate detections with frame/timestamp generations and drop stale main-queue updates during pause, reset, or mode changes.
- Test coverage: No lifecycle, ordering, or mode-switch tests exist.

## Scaling Limits

**Serial inference does not bound queued requests:**

- Current capacity: `Tennis Trainer/BallDetectionManager.swift:72-90` submits one closure per processed frame to a serial `detectionQueue`. The `isInFlight` check, assignment, and deferred reset all occur inside that closure, so the next closure normally sees `false`; the flag does not reject pending requests.
- Limit: Prediction holds the detector's synchronization queue, and `pushFrame` synchronously waits on that same queue (`Tennis Trainer/Detectors/GridTrackNetDetector.swift`). Capture/playback callers can therefore stall, while queued requests can later predict against the current buffer rather than the frame that triggered them. Actual backlog and frame loss need measurement.
- Scaling path: Define admission/coalescing before enqueueing work, couple each prediction with its input metadata, and measure both preprocessing wait time and inference latency. Preserve timestamps and reset generations when choosing a bounded scheduling policy.

## Dependencies at Risk

**Generated Core ML model contract:**

- Risk: Runtime decoding depends on the packaged model exposing `conf`, `x_off`, and `y_off` as FP16 arrays with expected temporal/grid dimensions; there is no automated contract check.
- Impact: A regenerated model can compile while silently producing wrong coordinates or no detections.
- Migration plan: Add a converter/model validation step that asserts feature names, shapes, element types, and known decode fixtures before packaging.

## Missing Critical Features

**Lifecycle and reset observability:**

- Problem: There is no explicit completion, reset, or dropped-frame status exposed for camera/video analysis; UI only displays a frame counter and inferred FPS.
- Blocks: Reliable diagnosis of stale detections, end-of-video behavior, and inference backlog on real devices.

## Test Coverage Gaps

**Camera/video lifecycle:**

- What's not tested: Permission transitions, start/stop gating, mode switching, video replacement, end-of-item cleanup, and queued callback invalidation.
- Files: `Tennis Trainer/CameraManager.swift`, `Tennis Trainer/VideoPlayerManager.swift`, `Tennis Trainer/BallDetectionManager.swift`
- Risk: Timing-dependent regressions can produce stale beeps, leaked temporary files, or a display link that runs indefinitely.
- Priority: High

**Coordinate mapping and model decode:**

- What's not tested: Portrait orientation, aspect-fit padding, aspect-fill cropping, preview/video overlay transforms, tensor stride layouts, and FP16 output decoding.
- Files: `Tennis Trainer/Detectors/GridTrackNetDetector.swift`, `Tennis Trainer/PixelBufferScaler.swift`, `Tennis Trainer/ContentView.swift`
- Risk: A detector can appear to work while overlays are spatially wrong or the toss gate receives distorted coordinates.
- Priority: High

**UI tests are scaffolds only:**

- What's not tested: The UI tests launch the app and take a screenshot, but assert no controls, permission state, playback state, overlay alignment, or beep behavior.
- Files: `Tennis TrainerUITests/Tennis_TrainerUITests.swift:25-38`, `Tennis TrainerUITests/Tennis_TrainerUITestsLaunchTests.swift:20-32`
- Risk: User-visible regressions in both primary flows pass CI unnoticed.
- Priority: Medium

**Placeholder unit test target:**

- What's not tested: `Tennis_TrainerTests` contains an empty Swift Testing example; only `ServeTossApexDetectorTests` covers domain logic.
- Files: `Tennis TrainerTests/Tennis_TrainerTests.swift:11-16`, `Tennis TrainerTests/ServeTossApexDetectorTests.swift:5-120`
- Risk: Managers, pixel-buffer transforms, audio setup, and detector integration have no executable regression coverage.
- Priority: Medium

---

*Concerns audit: 2026-09-19*
