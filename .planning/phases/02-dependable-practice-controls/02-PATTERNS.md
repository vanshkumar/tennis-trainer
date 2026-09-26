# Phase 2: Dependable Practice Controls — Pattern Map

**Mapped:** 2026-09-26
**Files classified:** 13 proposed implementation/test targets (including conditional targets)
**Analog coverage:** 12 / 13; file ownership has no existing complete analog

Scope comes from `02-RESEARCH.md`; no CONTEXT.md exists, by explicit planning authorization. New names below are proposals, not existing symbols or mandatory architecture. Preserve LIFE-01/02, CAM-01/02 and PLAY-01/02/03/04. This map supplies code patterns rather than repeating platform research.

## File Classification

All paths below are relative to repository root. Existing analog paths were verified with `git ls-files`; none are installed/runtime mirrors.

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `Tennis Trainer/CameraManager.swift` — modify | service | streaming, event-driven | Same file; dependency injection from `Tennis Trainer/BallDetectionManager.swift` | exact adapter; role-match injection |
| `Tennis Trainer/VideoPlayerManager.swift` — modify | service | streaming, event-driven | Same file; identity checks from `Tennis Trainer/BallDetectionManager.swift` | exact adapter; new completion state |
| `Tennis Trainer/BallDetectionManager.swift` — conditional admission extension | service | streaming | Same file | exact |
| `Tennis Trainer/ContentView.swift` — modify | component | event-driven | Same file | exact |
| `Tennis Trainer/PoseDetectionManager.swift` — conditional; separate instances may need no edit | service | transform, streaming | Same file | exact |
| `Tennis Trainer/VideoPickerView.swift` — modify | component | file-I/O, event-driven | Same file | exact bridge; unsafe copy policy must change |
| `Tennis Trainer/VideoImportManager.swift` — **new proposed name** | service | file-I/O, event-driven | `Tennis Trainer/VideoPickerView.swift` provider bridge plus `Tennis Trainer/BallDetectionManager.swift` injected effects | partial |
| `Tennis Trainer/OwnedVideoFile.swift` — **new proposed name**, may remain internal to importer | model | file-I/O | None for explicit copy ownership | none |
| `Tennis TrainerTests/PracticeLifecycleTests.swift` — **new proposed name**, or extend existing association tests | test | streaming, event-driven | `Tennis TrainerTests/AnalysisAssociationTests.swift` | exact tracer |
| `Tennis TrainerTests/CameraManagerTests.swift` — **new proposed name** | test | event-driven | `Tennis TrainerTests/BallDetectionManagerTests.swift` | role-match; new AV fake |
| `Tennis TrainerTests/VideoPlayerManagerTests.swift` — **new proposed name** | test | event-driven | `Tennis TrainerTests/BallDetectionManagerTests.swift` | role-match; new seek/load fake |
| `Tennis TrainerTests/VideoImportManagerTests.swift` — **new proposed name** | test | file-I/O, event-driven | `Tennis TrainerTests/BallDetectionManagerTests.swift` | role-match; new ownership ledger |
| `Tennis TrainerUITests/Tennis_TrainerUITests.swift` — extend for narrow controls smoke | test | event-driven | Same file | role-match; currently scaffold only |

`VideoPlayerView.swift` was inspected as a compatibility boundary, not a planned geometry change. Its existing layer replacement should remain usable. If extracting new control/overlay views, use ContentView's existing branches as the exact component analog; do not introduce another view framework.

## Pattern Assignments

### CameraManager.swift and proposed CameraManagerTests.swift

**Existing adapter:** `Tennis Trainer/CameraManager.swift` imports AVFoundation, SwiftUI and Vision (1–3). Preserve separate session and video queues (11–15), BGRA/discard-late setup (96–103), capture PTS and `.right` orientation (184–189), and injected ball factory (195–207).

```swift
// CameraManager.swift:195–202
func setupBallDetection(with pose: PoseDetectionManager,
                        factory: ((PoseDetectionManager) -> BallDetectionManager)? = nil) {
    guard factory != nil || !AppRuntime.isRunningTests else {
        self.ballDetectionManager = nil
        return
    }
    // Live overlay prefers the freshest frame index (t=4)
    let manager = factory?(pose) ?? BallDetectionManager(poseDetectionManager: pose, overlayTIndex: 4)
```

Use the BallDetectionManager dependency-value pattern below for **new** authorization/session/executor effects. Inject before production hardware construction. Existing `startCapture` and `stopCapture` return immediately during tests (128–144); these guards cannot continue bypassing the transition logic being tested. Retain suppression only for real effects.

**Race to replace, not copy:** `captureOutput` separately calls `canProcessFrame()` and `submitSampleBuffer()` (179–189). A Stop/Start between these calls lets an old buffer receive a new generation. Admission must atomically validate a captured ingress epoch or execute a short synchronized gate+offer transaction, with a verified queued-callback drain/reopen boundary. A Boolean recheck alone after restart is insufficient. Never hold that lock through Vision or AV start/stop.

**New coverage:** Hold permission/configure/start completions and ingress between acquisition and admission; Stop or exit mode, then release. Verify both published state and backend start/stop counts. Inject current backend state and old events, not only notification names. Exercise undetermined, denied, restricted, Settings return, interruption and failure/retry. Late grant/start/recovery cannot restore intent. Current optimistic `isRecording` assignment (128–139) and print-only setup failure (59–94) are replacement sites, not reference behavior.

### VideoPlayerManager.swift and proposed VideoPlayerManagerTests.swift

**Preserve exact streaming seam:** `Tennis Trainer/VideoPlayerManager.swift:5–21,120–127`.

```swift
protocol FrameOutputReading {
    func hasNewPixelBuffer(forItemTime time: CMTime) -> Bool
    func copyFrame(forItemTime time: CMTime) -> (CVPixelBuffer, CMTime)?
}
// Existing processCurrentFrame body, lines 122–126:
guard output.hasNewPixelBuffer(forItemTime: requestedTime),
      let (pixels, time) = output.copyFrame(forItemTime: requestedTime) else { return }
ballDetectionManager?.process(input: .init(
    pixelBuffer: pixels, sourceTime: time, orientation: orientation, sourceID: sourceID
))
```

Keep acquired display time, not requested player time; keep unambiguous Objective-C `processDisplayLinkFrame` (109). New lifecycle tests must enter the enabled production path, because direct `processCurrentFrame` currently bypasses `isPlaying`.

**Existing cleanup shape:** stop loop (104–107), remove time observer (234–238), remove output from item (245–249), disconnect layer (251–255). Preserve explicit retirement but pair token/output with their original player/item. `deinit` alone is insufficient. `VideoPlayerView.swift:23–36` already removes a replaced layer and adds a new one only when identity differs; preserve that compatibility and `.resizeAspect`.

**Do not copy current unsafe behavior:** load immediately destroys the old player before validation (43–83), ignores `isPlayable`, and mutates `self.player` after suspension; seek (188–199) neither suspends extraction nor waits for completion; `startFrameProcessing` (99–102) has no existing-link guard. These are exact replacement sites.

New injected effects should hold metadata, readiness, seek, item end/error, observer callbacks and display-link registration. Reuse source/generation-style captured equality checks on the state executor, but use distinct load/item/seek identities. Test A→B seek with A success/failure late; Pause before B success; stale item-end after replacement; Replay waiting for zero seek; repeated Play; original-owner observer removal. Keep a committed usable session until current candidate validation/readiness succeeds. Candidate failure/cancellation leaves prior selection paused.

### BallDetectionManager.swift (conditional change)

**Strongest reusable service pattern:** `Tennis Trainer/BallDetectionManager.swift:29–38`.

```swift
struct Dependencies {
  var analyze: (Input, FrameIdentity, PoseDetectionManager.FramePose) throws -> Analysis
  var extractPose: (Input, FrameIdentity) -> PoseDetectionManager.FramePose = { _, identity in
    .init(identity: identity, joints: [:])
  }
  var publishPose: (PoseDetectionManager.FramePose) -> Void = { _ in }
  var reset: () -> Void = {}
  var bufferDiagnostics: () -> GridTrackNetDetector.Diagnostics = { .init(ringCount: 0, uniquePreparedBufferCount: 0) }
  var worker: (@escaping () -> Void) -> Void
  var publication: (@escaping () -> Void) -> Void
}
```

Keep production construction lazy behind injected dependencies (144–176). `process(input:)` validates times/source and reserves its lease under the lock **before dispatch** (179–202). An ingress extension belongs at this atomic boundary if the adapter cannot prove the boundary itself. Do not introduce another inference queue or release lease during reset.

**Publication and reset excerpts:**

```swift
// BallDetectionManager.swift:221–225
dependencies.publication { [weak self, state] in
  defer { state.release(owned) }
  guard let self else { return }
  self.publish(completedResult, pose: completedPose, lease: owned)
}
// BallDetectionManager.swift:243–251
if let samples = result?.samples {
  onBallTrack?(samples)
  guard state.isCurrent(lease.identity) else { clearPublishedValues(); return }
  if apexDetector.consume(samples: samples) {
    onApex?()
  }
}
guard state.isCurrent(lease.identity) else { clearPublishedValues(); return }
onFrameProcessed?()
```

`resetTrackingState(sourceID:)` (261–284) changes generation synchronously, clears sequence/time, defers model clearing to its worker and coalesces idle clearing into one lease. Preserve checks after observable pose/ball/track effects (237–250). Add admission regression assertions to existing BallDetectionManagerTests only if this file changes; its test role is already covered by the scheduler analog below.

### ContentView.swift and PoseDetectionManager.swift

**Existing component pattern:** ContentView imports SwiftUI/Vision (8–9), owns managers via `@StateObject` (17–20), uses `onChange` for mode and selection (39–41,90–97), and routes automatic cues through manager callbacks (83–88). Keep manual Test Beep (187–188).

```swift
// ContentView.swift:83–88
cameraManager.onApex = {
    audioManager.playBeep()
}
videoPlayerManager.onApex = {
    audioManager.playBeep()
}
```

Apply lifecycle invalidation in managers before these automatic sinks can execute. Count calls to the same adapter `onApex` boundary in deterministic tests; do not instantiate audio just to test invalidation.

**Pose ownership coupling:** lines 53–57 inject one shared presenter into both adapters; overlays read it in both branches (114,242). Prefer two mode-owned instances and observe the corresponding presenter. This can avoid modifying PoseDetectionManager entirely. If using a source gate instead, gate empty clearing as well as nonempty results.

```swift
// PoseDetectionManager.swift:72–78
func publish(_ pose: FramePose) {
  detectedPose = pose.joints
  guard let shoulder = detectedPose[.rightShoulder],
        let elbow = detectedPose[.rightElbow], let wrist = detectedPose[.rightWrist] else {
    forearmAngle = 0
    upperArmAngle = 0
    return
```

This method has no active-source guard. BallDetectionManager stale/idle clearing (254–258,276–281) calls it with empty joints. Test old mode's delayed clear **after** the new mode has published valid pose; also test same-mode reset clearing. Preserve frame-associated pose extraction (55–69), its whole request lock and missing-pose behavior. Do not substitute overlay pose into cue eligibility.

ContentView must update both mode switching (368–387) and control presentation (147–204,289–335). Stop must work while starting/recovering; mode exit cannot depend on `isRecording`. Forward scene-active permission recheck and scene suspension. Wire distinct request/Settings/restricted messages, ended/Replay and visible load failure. Ball state is a nested ObservableObject (126,254): observe/forward actual ball publication so clearing renders without relying on a later FPS update. Preserve all overlay coordinate math for Phase 3.

### VideoPickerView.swift, proposed VideoImportManager.swift and OwnedVideoFile.swift

**Existing bridge/import excerpt:** `Tennis Trainer/VideoPickerView.swift:8–15,31–39`.

```swift
func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let result = results.first else {
        parent.dismiss()
        return
    }
    result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
```

Keep SwiftUI/PhotosUI imports, videos-only single selection and coordinator boundary. Replace raw URL binding with an explicit outcome/current import handoff if needed. Dismissal after selection precedes file completion; a generic sheet dismissal must not cancel every successful selection.

Use injected dependency closures from BallDetectionManager for the new importer; there is **no existing owned-file model** to copy. New owner must distinguish externally supplied URLs from app copies, use unique generated destinations, and transfer lifetime from import→candidate→committed session. Copy during the provider callback; marshal the owned result afterward. Preserve original files on every exit. Hold ownership while cancelled tasks still consume a file; release after consumers retire.

**Anti-pattern:** lines 50–57 create a basename-derived destination, delete existing destination and copy. Do not retain that policy. Existing catch blocks (40–47,63–65) only print; instead produce recoverable error state scoped to the current request and clean only operation-owned partial/stale copies. Proposed import tests need a copy/remove ledger and held provider callback; test identical basenames, copy failure, stale success, cancellation and transfer exactly once.

### Proposed lifecycle tests and manager test files

**Imports:** `Tennis TrainerTests/AnalysisAssociationTests.swift:1–5` uses XCTest, AVFoundation, `@testable import Tennis_Trainer`, and a final XCTestCase. Add CoreML only where tensor fixtures require it. Tests use two-space indentation and behavior-based method names.

**Held scheduler:** `Tennis TrainerTests/BallDetectionManagerTests.swift:323–327`.

```swift
private final class Scheduler {
  var jobs: [() -> Void] = []
  func enqueue(_ job: @escaping () -> Void) { jobs.append(job) }
  func run() { jobs.removeFirst()() }
}
```

Follow tests 334–370 and 401–425: inject separate worker/publication schedulers, assert lease and queue counts while held, reset, deliver stale work, then prove a fresh input succeeds. `testNoCue_WhenTrackCallbackResetsGeneration` (387–399) is the exact reentrant-publication test analog. No sleeps are needed. Those helpers are private; factor into a test fixture or locally copy deliberately rather than assuming accessibility.

**Complete adapter tracer:** `Tennis TrainerTests/AnalysisAssociationTests.swift:14–35`.

```swift
let grid = GridTrackNetDetector(predictor: { window in
  windows.append(window.frames.map(\.metadata))
  return try DecoderFixture.tossOutputs(window)
})
let manager = BallDetectionManager(dependencies: .init(analyze: { input, identity, pose in
  guard grid.pushFrame(input: input, identity: identity, pose: pose) else { return .init(samples: nil, position: nil) }
  return .init(samples: grid.detectAllSamplesIfReady(), position: nil)
}, extractPose: { _, identity in
  .init(identity: identity, joints: [.nose: .init(location: CGPoint(x: 0.5,
    y: identity.sequence == 3 ? 0.6 : 0.95), confidence: 0.9)])
}, reset: grid.clear, bufferDiagnostics: { grid.diagnostics }, worker: { $0() }, publication: { $0() }))
```

Retain real preparation, immutable window and decoder with synthetic predictor. Replace immediate schedulers with held ones for lifecycle tests. Sample-buffer/output builders (74–89) preserve capture PTS/copied display time. Current tests call adapter submission directly (39–45); extend with real controls and injected AV effects rather than counting them as lifecycle coverage already.

Parameterize Stop, Pause, seek, replacement, completion and mode exit at both worker-held and publication-held points. Assert no old ball/pose/track/frame-counter/automatic-beep effects, lease release once, and subsequent fresh five-frame warmup plus valid synthetic cue. Follow warmup/reset assertions (161–192). Rational fixtures use `CMTime(value:timescale:)`, not floating seconds at exact boundaries.

### Existing UI test file

`Tennis TrainerUITests/Tennis_TrainerUITests.swift:12–18,25–31` provides only setup and launch structure:

```swift
@MainActor
func testExample() throws {
    let app = XCUIApplication()
    app.launch()
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}
```

No existing launch-injected permission/media harness exists in this inspected scaffold. Treat such wiring as new if chosen. Add focused visible-state/control assertions; keep actual Settings/interruption/device acceptance separate from injected evidence. Avoid adopting launch-performance scaffolding as a correctness test.

## Shared Patterns

- **Injection before effects:** BallDetectionManager's dependency value and lazy production factory (29–38,144–176) are the main service analog. New capture/player/import seams should fake framework effects while exercising real transition logic.
- **Identity after executor hop:** BallDetectionManager `State.isCurrent` (72–74) compares source and generation; publication repeats the check after effects. Apply the principle to distinct permission/capture/load/item/seek operations, including failures and clearing.
- **No authentication middleware:** this app has platform camera permission, not account auth. Use authorization state in CameraManager; do not introduce login/session infrastructure.
- **Errors/validation:** preserve no-result pose/analysis handling in the pipeline; lifecycle failures need visible recoverable state rather than copying print-only or swallowed player errors. Validate current candidate, finite duration/seek and playable video before commit; keep errors owned by the operation.
- **SwiftUI observation:** `@StateObject` owns services; conditional branch reads active-mode state. Nested ball publishers need explicit observation/forwarding. Do not depend on frame counter updates to repaint cleared overlays.
- **Resource retention:** scheduler jobs capture small state and weak manager (BallDetectionManager 60–61,202,221); never capture raw pixels in publication. Apply explicit owner/weak callback discipline to new AV/resource wrappers without changing Phase 1 buffer bounds.

## Files That Must Change Together

1. Camera admission/control + optional BallDetectionManager admission parameter + held-ingress tests. Changing only reset calls does not close the check/admission or queued-old-frame gap.
2. Both media adapter invalidation paths + ContentView mode exit/scene handling + mode-owned pose wiring/observation + complete control-to-cue regression. A camera-only fix leaves playback stale effects; a nonempty-pose guard leaves delayed clearing.
3. VideoPlayerManager seek/end/replay state + ContentView Play/Pause/Replay labels and enablement + completion-order tests. Current control state must reflect requested intent while a seek is pending.
4. VideoPickerView outcome + proposed importer/file owner + VideoPlayerManager candidate commit/retirement + ContentView selection/error presentation + import/resource tests. Keeping the old raw URL binding as a second source of truth risks restoring a stale selection.
5. Player observer/output/display-link ownership + retirement tests + existing VideoPlayerView layer handoff. New app files are automatically included by the synchronized Xcode group; no target renames or routine project-file edits.

## No Analog Found

| File / new behavior | Role | Data Flow | Reason |
|---|---|---|---|
| Proposed `OwnedVideoFile.swift` | model | file-I/O | Existing code has only a raw URL and unsafe basename copy; no ownership/deletion handle |
| New camera permission/session fake, player seek/load/readiness fake | test utility | event-driven | Existing scheduler/output reader supplies style, not these AV lifecycle effects |
| New import copy/remove ledger | test utility | file-I/O | No resource-ownership test pattern found in scoped lifecycle sources/tests |

Use `02-RESEARCH.md` for those contracts; do not imply the proposed helper symbols already exist. Keep helpers internal to owning files unless extracting one primary type improves plan ownership.

## Metadata

**Analog search scope:** live top-level managers/views, unit lifecycle/association tests and UI scaffold; tracked inventory verified before assignment. No archive/runtime mirror analogs used.
**Source files inspected:** 10 (CameraManager, VideoPlayerManager, BallDetectionManager, PoseDetectionManager, ContentView, VideoPickerView, VideoPlayerView, AnalysisAssociationTests, targeted BallDetectionManagerTests ranges, UI test scaffold).
**Primary reusable anchors:** BallDetectionManager, CameraManager, VideoPlayerManager, AnalysisAssociationTests, BallDetectionManagerTests; other reads establish necessary existing wiring boundaries.
**Project context:** AGENTS.md, full root LEARNINGS.md, docs/README.md, ARCHITECTURE.md and full Phase 2 research; project skill directories and root execution briefs absent in scoped discovery.
**Validation performed:** read-only code inspection and tracked-path checks. No build/test/device claim made. Parent owns other planning artifacts, learnings and commits.
