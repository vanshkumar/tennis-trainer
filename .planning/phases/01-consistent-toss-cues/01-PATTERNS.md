# Phase 1: Consistent Toss Cues — Pattern Map

**Mapped:** 2026-09-25
**Files classified:** 17 proposed edit/addition targets; new names are recommendations, not decisions.
**Coverage:** 11 exact existing-file seams, 5 role matches, 1 without an implementation analog.

## File Classification

Paths below are repository-relative. `App/` means `Tennis Trainer/`; `Tests/` means `Tennis TrainerTests/`. These abbreviations are display shorthand only.

| New/Modified File | Role | Data flow | Closest analog | Quality |
|---|---|---|---|---|
| `App/BallDetectionManager.swift` | service | streaming/event-driven | same file, 21–30, 78–88 | exact seam |
| `App/Detectors/GridTrackNetDetector.swift` | service | batch/transform | same file, 10–49, 175–203 | exact seam |
| `App/Detectors/ServeTossApexDetector.swift` | service | streaming | same file, 13–27, 71–103 | exact seam |
| `App/PoseDetectionManager.swift` | service | transform | same file, 17–52, 109–118 | exact seam |
| `App/CameraManager.swift` | service | streaming | same file, 12–15, 163–194 | exact seam |
| `App/VideoPlayerManager.swift` | service | streaming/event-driven | same file, 87–110, 206–213 | exact seam |
| `App/PixelBufferScaler.swift` | utility | transform | same file, 66–119 | exact seam |
| `App/ContentView.swift` | component | event-driven | same file, 83–88 | exact seam; verify wiring |
| `App/AudioManager.swift` | service | event-driven | same file, 9–12, 64–74 | exact seam; verify wiring |
| `App/AppRuntime.swift` | config | transform | same file, 3–6 | exact seam; preserve |
| `Tests/ServeTossApexDetectorTests.swift` | test | batch | same file, 6–40, 43–119 | exact seam |
| `App/AnalysisFrame.swift` (suggested) | model | streaming/batch | `App/Detectors/GridTrackNetDetector.swift`, 16–49 | role match |
| `App/Detectors/GridTrackNetDecoder.swift` (optional extraction) | utility | transform | `App/Detectors/GridTrackNetDetector.swift`, 326–382 | role match |
| `Tests/BallDetectionManagerTests.swift` (suggested) | test | streaming/event-driven | `Tests/ServeTossApexDetectorTests.swift`, 6–40 | role match |
| `Tests/AnalysisAssociationTests.swift` (suggested) | test | streaming/transform | `Tests/ServeTossApexDetectorTests.swift`, 14–40 | role match |
| `Tests/GridTrackNetDecoderTests.swift` (suggested) | test | transform | `Tests/ServeTossApexDetectorTests.swift`, 1–21 | role match |
| `docs/references/toss-cue-validation.md` (suggested) | documentation | batch evidence | none; placement follows `docs/README.md` | none |

Use existing files unless extraction creates a useful ownership/test boundary. Association tests can include source ingress, pose and scaler fixtures; no separate manager for each value type is needed. Audio/AppRuntime may need verification only. Keep native Swift and iOS 18.5, existing model/preprocessing, and both media paths. No CONTEXT.md exists; research recommendations are not discussion decisions.

## Pattern Assignments

### BallDetectionManager and live/playback ingress

Keep `Tennis Trainer/BallDetectionManager.swift` as the ball/cue integration seam. Existing callback declarations (21–23):
```swift
// Optional: structured track callback (five samples per inference)
var onBallTrack: (([GridTrackNetDetector.Sample]) -> Void)?
var onApex: (() -> Void)?
```
Use the short lock discipline from `Tennis Trainer/CameraManager.swift`, 163–167, for admission state; this is a synchronization building block, not an existing bounded scheduler:
```swift
private func setFrameProcessingEnabled(_ enabled: Bool) {
    frameProcessingLock.lock()
    defer { frameProcessingLock.unlock() }
    frameProcessingEnabled = enabled
}
```
Replace the busy check inside `BallDetectionManager`'s queued closure (72–76). Gate before queue submission, hold a job lease through publication, and release it on every exit. Do not hold the lock during Vision/Core ML. Preserve separate session/video queues (`CameraManager`, 12–13). Replace post-pose wall-clock timing at live ingress (177–194) with source PTS captured from the sample buffer before work.

`Tennis Trainer/VideoPlayerManager.swift`, 87–110, is the playback edit seam: preserve orientation forwarding but use new-frame detection and returned display time instead of requested player time. Move pose work behind admission. Its callback forwarding (208–212) is reusable:
```swift
let manager = BallDetectionManager(poseDetectionManager: pose, overlayTIndex: 4)
manager.onApex = { [weak self] in
    self?.onApex?()
}
self.ballDetectionManager = manager
```
The equivalent live forwarding is `CameraManager`, 206–210. Inject construction for tests; do not initialize a real model merely to attach a fake callback. Preserve freshest overlay selection. Full stop/seek/replacement lifecycle acceptance belongs to Phase 2.

### Frame/window values, model adapter and decoder

Use `Tennis Trainer/Detectors/GridTrackNetDetector.swift`, 16–21, as the value-style starting point:
```swift
struct Sample {
    let tIndex: Int          // 0 (oldest) ... 4 (newest)
    let timestamp: CFTimeInterval
    let position: CGPoint?   // normalized Vision space; nil if below threshold
    let confidence: Float    // best grid confidence at t
}
```
Extend the contract with source/generation/sample identity and associated pose. Replace parallel mutable arrays (60–62) with owned records and an immutable five-record prediction window. `FrameMapping` (23–49) is the existing geometry value analog. `let` does not make CVPixelBuffer bytes immutable: ensure preparation cannot mutate buffers retained by a prediction.

Preserve imports `Foundation`, `CoreML`, `CoreVideo`, `CoreGraphics`, `QuartzCore`, `ImageIO` as needed (1–6). Preserve adapter input names `f1`…`f5`, output names `conf/x_off/y_off`, and oldest→newest ordering (180–197). Keep model access serialized and inject a predictor for tests. Existing failure form (198–201):
```swift
} catch {
    print("GridTrackNetDetector: prediction error: \(error)")
    return nil
}
```
Decoder extraction should reuse FP16 conversion (362) and each tensor's strides (326–329), but replace heuristic malformed-shape fallback with explicit validation. Do not copy separate post-prediction metadata reads (389–391).
```swift
let shape = conf.shape.map { Int(truncating: $0) }
let strides = conf.strides.map { Int(truncating: $0) }
let xStrides = xOff.strides.map { Int(truncating: $0) }
let yStrides = yOff.strides.map { Int(truncating: $0) }
```
Use the original window for all decoded timestamps and mappings; validate rank, dimensions, dtype and finite values before raw access.

### Pose, candidate association and preprocessing

`Tennis Trainer/PoseDetectionManager.swift`, 44–49, provides recognized-point filtering; 109–118 selects nose then neck above confidence 0.3. Return these values for the exact admitted frame; serialize perform-and-extract across the shared Vision request. Replace the absent-observation early return that leaves old published pose (24), and never consult current UI pose for a historical candidate.

`Tennis Trainer/Detectors/ServeTossApexDetector.swift`, 13–17, defines preserved policy:
```swift
private let cooldownSeconds: CFTimeInterval = 4.0
private let bufferHorizonSeconds: CFTimeInterval = 1.5
private let confidenceThreshold: Float = 0.5
private let poseHeightMargin: CGFloat = 0.05
private let frameRelativeFallback: CGFloat = 0.70
```
Retain strict local maximum (77), candidate-time cooldown (95–99), and explicit fallback. Store pose baseline with the candidate; replace the live provider read (81). Add an identity/watermark independent of valid-history pruning and an explicit history count bound. Time horizon alone is not a finite memory bound for arbitrarily dense timestamps.

`Tennis Trainer/PixelBufferScaler.swift`, 95–97, provides destination ownership:
```swift
guard let outPB = makePixelBuffer(width: width, height: height) else { return nil }
ciContext.render(composited, to: outPB)
return outPB
```
Reuse buffer creation (122–132), orientation translation (107–119), and fit/fill transforms. Close the `.up` identity return ownership gap (105) for retained input. Preserve detector portrait-fit/nonportrait-fill (127–144), 768×432 canvas, out-of-source rejection and bottom-left conversion (30–48). Display transforms remain Phase 3.

## Shared Patterns

### Tests and service suppression

Use `Tennis TrainerTests/ServeTossApexDetectorTests.swift`, 1–12:
```swift
import XCTest
import CoreGraphics
@testable import Tennis_Trainer

final class ServeTossApexDetectorTests: XCTestCase {
    private final class StubHeightGateProvider: ServeTossApexHeightGateProviding {
        let serveTossApexGateBaselineY: CGFloat?
        init(baselineY: CGFloat?) {
            self.serveTossApexGateBaselineY = baselineY
        }
    }
```
Adapt the sample factory (14–21) and batched runner (23–40) to associated values. Preserve all six behavior checks (43–119). For new manager/association tests, use manually held predictor and publication completions, injected pose values and callback spies; no sleeps or real camera/audio/model are needed. Test malformed tensors, distinct offset strides, all five indices, ownership, repeated/overlapping input, absent/delayed pose, and work bounds while worker/publication are held.

`Tennis Trainer/AppRuntime.swift`, 3–6, identifies tests via `ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil`. Existing `guard !AppRuntime.isRunningTests else { return }` suppresses camera permission/start/stop (`CameraManager`, 25, 128, 142) and audio setup (`AudioManager`, 10). Camera setup also skips the ball manager (201–204). **Suppression is incomplete:** directly creating BallDetectionManager eagerly creates GridTrackNetDetector; playback setup (206–213) has no test guard. Inject dependencies before any eager construction. Tests must still exercise the manager pipeline with fakes rather than globally skipping it.

### Publication, automatic sound and errors

Preserve `Tennis Trainer/ContentView.swift`, 83–88: both media managers' `onApex` call `audioManager.playBeep()`. Manual Test Beep (187–189) stays independent. `AudioManager`, 64–74, guards engine/buffer availability then schedules sound. Verify automatic callback counts with a spy; software scheduling is not physical-audio evidence. Consolidate manager publication into one generation-checked effect batch. Use existing optional-result/guard and error-only logging styles, while ensuring failure paths release their own lease. No authentication, server, database or migration pattern applies.

## No Analog Found

The validation document has a documentation home (`docs/README.md`) but no existing labeled-clip/scoring protocol analog. Follow RESEARCH.md for baseline revision, permitted-clip/device inventory, settings, denominators, ambiguity, and pending evidence. Do not fabricate numeric acceptance or measurement results. Likewise, the repo has no complete bounded end-to-end scheduler, immutable prediction-window contract, or held-worker fixture; the role matches above supply style and seams, not a proven implementation.

## Metadata

**Search scope:** live app managers/detectors/scaler/view, unit tests, docs map, phase research and approved requirements/roadmap. Eleven source/test files were read for extraction; all existing source analogs and `docs/README.md` were confirmed by `git ls-files`. No local `.codex/skills/` or `.agents/skills/` entries or root implementation brief were found. No source edits, builds or tests performed. New app/test files use synchronized Xcode groups; no routine `.pbxproj` membership edits. Source citations describe the pre-implementation tree and must be rechecked after edits.
