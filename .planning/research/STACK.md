# Stack Research

**Domain:** On-device iPhone tennis toss-apex reliability; existing application milestone
**Researched:** 2026-09-24
**Confidence:** MEDIUM

Keep the existing Apple frameworks and bundled GridTrackNet model. Reliability depends on frame ownership, bounded work, lifecycle invalidation, and coordinate contracts; no new runtime dependency is justified by the inspected problems.

**Evidence convention:** “Apple fact” denotes documented behavior; “Recommendation” denotes a project inference requiring implementation validation. Web findings and recommendations are MEDIUM confidence, using `gsd-tools query classify-confidence --provider websearch --verified`. Repository facts below come from the project/map and focused source inspection; no build, tests, or device measurements were performed for this research.

## Recommended Stack

### Core Technologies

| Technology | Version / baseline | Purpose | Why Recommended |
|------------|--------------------|---------|-----------------|
| Swift + SwiftUI | Existing Swift 5 language mode; iOS 18.5 target | Managers, controls, overlays | Preserve composition and published state; publish user-visible state on main. Swift language mode is not the installed compiler version. |
| AVFoundation | System framework on iOS 18.5 | Camera session, selected-video playback, audio | Existing framework already exposes permission, session, end-of-item, seek, and presentation APIs needed for reliability. [A1–A7] |
| Core ML + GridTrackNet5 | System runtime; existing bundled `.mlpackage` | Five-frame ball prediction | Keep model behavior stable while fixing ownership and decoding contracts. Synchronous prediction requires serialized model access. [A8] |
| Vision | Existing `VNDetectHumanBodyPoseRequest` | Body joints and toss-height reference | Retain the current request and pose gate; associate pose results with source time and generation rather than adding another estimator. Project recommendation. |
| Core Video / Core Media / Core Image | System frameworks on iOS 18.5 | Pixel buffers, media timestamps, model preprocessing | Preserve source timestamps and existing fit/fill transforms in immutable inference records; keep preprocessing off UI and session-control paths. Project recommendation. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Dispatch + Foundation synchronization | System | Serial session owner, separate inference worker, short admission gate | Retain existing queues; synchronize admission before enqueueing and never hold the gate during prediction. |
| QuartzCore `CADisplayLink` | System | Playback-paced frame acquisition | Use host-time conversion and new-frame detection; expensive pose/model work belongs downstream. [A5] |
| PhotosUI + Foundation file APIs | Existing system picker | Import and ownership of copied video | Record whether the app owns a copied URL and remove only owned files after their use ends. Project recommendation. |
| XCTest | Existing target | Deterministic pipeline/lifecycle regression fixtures | Extend the established test target without introducing a second test framework for this work. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Installed Xcode 27.0, build 27A266a | Compile and inspect SDK availability | Root agent verified `xcodebuild -version`; the project’s `CreatedOnToolsVersion = 16.4` is creation metadata, not installed tooling. |
| Instruments | Diagnose inference time, allocations, and contention | Apple recommends profiling concurrent Core ML workloads and memory. Instrument actual devices before changing compute-unit or concurrency policy. [A8] |
| Existing model converter | Reproduce the packaged model only if necessary | Leave `requirements-convert.txt` and model assets unchanged for this milestone; conversion is not a prerequisite to pipeline fixes. |

## Installation

No package installation or project format migration is required. Keep the current targets, bundle identity, bundled model, and iOS 18.5 deployment target. Check each added API against that deployment target even when the local SDK is newer.

## Implementation Choices

### Capture permissions and session ownership

**Apple facts:** `startRunning()` blocks until startup or failure; session documentation recommends a serial queue to avoid blocking main. Authorization must be checked before configuration; the system remembers the permission response and users can change it in Settings. Session running, interruption, and runtime-error notifications are available. [A1–A3]

**Recommendation:** Keep `CameraManager.sessionQueue` as the single configuration/start/stop owner and keep analysis on its separate worker. Make configuration idempotent. Model authorization, requested activity, and actual running/error state separately; setting `isRecording = true` before startup is not proof of capture. Close admission and invalidate the analysis generation immediately on stop, independently of when `stopRunning()` completes.

**Recommendation:** Expose an explicit permission operation: request for `.notDetermined`, configure for `.authorized`, link to the app’s Settings for `.denied`, and explain `.restricted` without promising that another prompt fixes it. Recheck authorization on foreground return. Only request capture permissions for inputs actually used; an output beep is not a reason to add microphone capture. `UIApplication.openSettingsURLString` supplies the Settings destination. [A2, A3]

**Apple fact:** `alwaysDiscardsLateVideoFrames` discards late delivery at the capture output; TN2445 explains dropped-frame diagnostics and capture-buffer starvation. **Recommendation:** Retain it, but add an application admission policy: it does not constrain closures already submitted to the detector queue. Keep retained source buffers bounded, and inspect `captureOutput(_:didDrop:from:)` during device validation. [A4]

### Core ML concurrency and immutable work

**Apple facts:** Apple’s WWDC23 guidance distinguishes synchronous prediction, which needs serial access to a model instance, from thread-safe asynchronous prediction. Async cancellation is best effort, and concurrent work increases memory consumption; actual performance benefits depend on model and hardware. [A8]

**Recommendation:** Keep synchronous prediction on the current serial inference worker for the first reliability implementation. Admit at most one running prediction and one explicitly replaceable pending window, or initially drop new requests while busy; choose and test one policy before enqueueing. An actor or serial queue alone does not bound its mailbox. Preserve the five-frame cadence contract when deciding which frames can be skipped; timestamp gaps need explicit detector handling.

**Recommendation:** Snapshot `{generation, frame IDs, ordered timestamps, oriented image geometry, model mappings, owned model inputs}` together. Prediction and decoding consume only that snapshot. Do not mutate/reuse input storage while it is in flight. Return results with the same identity; reject old generations both when inference finishes and immediately before publishing overlays or triggering audio. Preserve the `BallDetectionManager` integration boundary.

**Recommendation:** Validate model feature names, FP16 element type, temporal/grid dimensions, and each tensor’s strides at one decoder boundary. Preserve all five cue samples and the current overlay index separately. Model preprocessing and display transforms are different steps: `.planning/PROJECT.md` records portrait fit/nonportrait fill in current code, while older repository notes prescribe fill universally. Resolve through source fixtures; do not silently standardize it during concurrency work.

### AVPlayer ownership, timing, and transitions

**Apple facts:** `itemTime(forHostTime:)` converts display-link/host time into the player item’s timebase. `hasNewPixelBuffer(forItemTime:)` and `copyPixelBuffer(forItemTime:itemTimeForDisplay:)` support display-driven acquisition; a successful copy marks that image acquired. [A5]

**Recommendation:** Give each loaded clip an identity/generation, cached track geometry, output, observer tokens, display link, load task, and owned URL. Use output timing with the returned frame, retaining the returned display time when valid; do not infer source frame time solely from a separate `player.currentTime()` read. Preserve media time for cue logic and a separate monotonic clock for processing-latency measurements.

**Apple facts:** End-of-item notifications identify the finished item and may arrive off the registration thread. Seek completions can be interrupted; time observers must be explicitly removed. Asset/track synchronous property loading is deprecated for Swift clients from iOS 16; asynchronous loading is the supported path. [A6, A7, A9]

**Recommendation:** Serialize playback UI/lifecycle ownership on main and generation-check every load, seek, observer, and inference completion. Load video tracks and `preferredTransform`/`naturalSize` asynchronously once per clip instead of doing synchronous track reads each frame. Confirm playability/readiness before enabling playback. Observe the current item’s end and failure; end processing and expose replay, which seeks successfully before restarting.

**Recommendation:** Pause, seek, replacement, mode exit, and cleanup close analysis admission and invalidate pending feedback immediately. After a successful current-generation seek, clear/rebuild the temporal window before resuming analysis. Make play idempotent so repeated taps cannot create multiple display links. Teardown must invalidate the display link, detach item output, remove observers from their owning objects, cancel/obsolete load tasks, and finally remove app-owned temporary media. Do not rely on `deinit` to break a display-link ownership cycle.

### Display geometry

**Apple facts:** `AVPlayerLayer.videoRect` reports the displayed image’s position/size inside its bounds and varies with media aspect, bounds, and gravity. Preview-layer conversion APIs connect layer points and capture-device coordinates; the latter describe an unrotated image with top-left origin, and conversion accounts for layer size/gravity. [A10, A11]

**Recommendation:** Keep one explicit transform chain: model canvas → oriented source-normalized bottom-left coordinates → displayed-image rectangle → overlay space. For playback, use the actual `videoRect`, convert layer coordinates into the overlay container, and recompute after geometry/readiness changes. Avoid fixed 16:9 assumptions for imported portrait clips.

**Recommendation:** For live preview, either convert the oriented analysis point back to the capture-device coordinate convention before `layerPointConverted(fromCaptureDevicePoint:)`, or use a tested equivalent crop transform driven by preview geometry. Passing Vision/model bottom-left points directly to that API is incorrect. Apply orientation, mirroring, and origin inversion exactly once; share this projection between pose and ball.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Existing Dispatch owners and bounded serial prediction | Actor-owned runtime services | Useful if a focused refactor makes ownership clearer; preserve immediate invalidation and avoid adding a language-mode migration. |
| Serial Core ML prediction first | Async prediction with bounded concurrency | Consider only after measured evidence shows inference scheduling limits reliability and results remain ordered/generation-safe. [A8] |
| Display-paced `AVPlayerItemVideoOutput` for user playback | Sequential `AVAssetReader` clip harness | A separate validation harness can be considered if every encoded frame must be evaluated; that would need phase-specific API research. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Unbounded queue submissions or detached tasks per frame | Serial execution and task cancellation do not establish freshness or finite backlog | Explicit admission, immutable work identities, generation checks |
| Blind adoption of the latest AVCam sample | Current sample requires iOS 26; this project targets iOS 18.5 | Reuse documented lifecycle principles with baseline-compatible APIs [A12] |
| Replacing GridTrackNet / adding cloud inference | Introduces model/product variables before pipeline correctness is measured | Existing bundled model and on-device processing |
| PRD frame-rate estimates as latency evidence | Requested capture rate does not measure capture-to-beep delay | Clip/device traces with separate source and processing timestamps |

## Version Compatibility

| Component | Compatible baseline | Notes |
|-----------|---------------------|-------|
| Existing Apple runtime stack | iOS 18.5 retained | No OS upgrade proposed; validate overload availability in the installed SDK when implementing. |
| Async asset/track loading | Available before iOS 18.5 | Apple documents the synchronous-access deprecation from iOS 16. Avoid copying newer signatures requiring language changes. [A9] |
| Optional async Core ML prediction | Introduced in WWDC23 guidance | Optional optimization, not prerequisite; generated wrapper availability must be checked in this project. [A8] |
| Current AVCam sample | iOS 26 or later | Architectural reference only; not a drop-in baseline for this app. [A12] |
| Xcode 27 vs project creation 16.4 | Installed toolchain vs historical metadata | Keep Swift 5 language mode unless a separately scoped change requires migration. |

## Sources

All Apple sources accessed 2026-09-24. Current reference pages generally lack publication dates; archival items and session dates are identified. Confidence is MEDIUM under the configured research seam; project-specific choices remain recommendations until tested.

- **A1:** [AVCaptureSession](https://developer.apple.com/documentation/avfoundation/avcapturesession), [startRunning](https://developer.apple.com/documentation/avfoundation/avcapturesession/startrunning()) — blocking behavior, session queue, runtime notifications.
- **A2:** [Authorization](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media), [requestAccess](https://developer.apple.com/documentation/avfoundation/avcapturedevice/requestaccess(for:completionhandler:)) — preconfiguration checks, retained decision, main-thread UI updates.
- **A3:** [openSettingsURLString](https://developer.apple.com/documentation/uikit/uiapplication/opensettingsurlstring) — app Settings destination.
- **A4:** [Late-frame discard](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput/alwaysdiscardslatevideoframes), [TN2445](https://developer.apple.com/library/archive/technotes/tn2445/_index.html) — current API plus 2017-07-12 capture diagnostics reference.
- **A5:** [Host-time conversion](https://developer.apple.com/documentation/avfoundation/avplayeritemoutput/itemtime(forhosttime:)), [Frame acquisition](https://developer.apple.com/documentation/avfoundation/avplayeritemvideooutput/copypixelbuffer(foritemtime:itemtimefordisplay:)) — output timing and acquisition.
- **A6:** [End notification](https://developer.apple.com/documentation/avfoundation/avplayeritem/didplaytoendtimenotification), [Seek completion](https://developer.apple.com/documentation/avfoundation/avplayeritem/seek(to:tolerancebefore:toleranceafter:completionhandler:)) — item identity, thread caveat, seeks.
- **A7:** [Playback progress](https://developer.apple.com/documentation/avfoundation/monitoring-playback-progress-in-your-app) — explicit time-observer removal.
- **A8:** [Improve Core ML integration with async prediction](https://developer.apple.com/videos/play/wwdc2023/10049/) — WWDC23 synchronous/async safety, cancellation, bounded concurrency, profiling.
- **A9:** [Loading media asynchronously](https://developer.apple.com/documentation/avfoundation/loading-media-data-asynchronously), [Load tracks](https://developer.apple.com/documentation/avfoundation/avasset/loadtracks(withmediatype:completionhandler:)) — current loading patterns and deprecation boundary.
- **A10:** [videoRect](https://developer.apple.com/documentation/avfoundation/avplayerlayer/videorect) — rendered-image rectangle and observation.
- **A11:** [Preview layer](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer), [Capture coordinate conversion](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer/capturedevicepointconverted(fromlayerpoint:)) — coordinate conventions and gravity-aware conversion.
- **A12:** [AVCam](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app) — current actor ownership example and iOS 26 sample requirement.

**Remaining validation:** Representative clips, device matrix, admission-policy effect on five-frame cadence, actual preprocessing/inference costs, and measured cue accuracy/latency. No numeric acceptance threshold or performance improvement is established by this research.
