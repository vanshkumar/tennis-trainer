---
phase: 02-dependable-practice-controls
verified: 2026-09-26T16:58:45Z
status: human_needed
score: 12/12 must-haves verified
behavior_unverified: 0
overrides_applied: 0
source_head: 212f17e923ea9228c142e03940153620d06b6cdd
evidence_head: d3d072e0be08dd1a5af86a53def0ed285a80e94e
covered_files:
  - ".planning/REQUIREMENTS.md"
  - ".planning/phases/01-consistent-toss-cues/01-VERIFICATION.md"
  - ".planning/phases/02-dependable-practice-controls/02-01-PLAN.md"
  - ".planning/phases/02-dependable-practice-controls/02-01-SUMMARY.md"
  - ".planning/phases/02-dependable-practice-controls/02-02-CHECKPOINT.md"
  - ".planning/phases/02-dependable-practice-controls/02-02-PLAN.md"
  - ".planning/phases/02-dependable-practice-controls/02-02-SUMMARY.md"
  - ".planning/phases/02-dependable-practice-controls/02-03-PLAN.md"
  - ".planning/phases/02-dependable-practice-controls/02-03-SUMMARY.md"
  - ".planning/phases/02-dependable-practice-controls/02-04-PLAN.md"
  - ".planning/phases/02-dependable-practice-controls/02-04-SUMMARY.md"
  - ".planning/phases/02-dependable-practice-controls/02-COVERAGE.md"
  - ".planning/phases/02-dependable-practice-controls/02-PATTERNS.md"
  - ".planning/phases/02-dependable-practice-controls/02-RESEARCH.md"
  - ".planning/phases/02-dependable-practice-controls/02-REVIEW-FIX.md"
  - ".planning/phases/02-dependable-practice-controls/02-REVIEW.md"
  - ".planning/phases/02-dependable-practice-controls/02-SECURITY.md"
  - ".planning/phases/02-dependable-practice-controls/02-UI-REVIEW.md"
  - "AGENTS.md"
  - "ARCHITECTURE.md"
  - "LEARNINGS.md"
  - "Tennis Trainer.xcodeproj/project.pbxproj"
  - "Tennis Trainer.xcodeproj/xcshareddata/xcschemes/Tennis Trainer UI Tests.xcscheme"
  - "Tennis Trainer.xcodeproj/xcshareddata/xcschemes/Tennis Trainer.xcscheme"
  - "Tennis Trainer/AnalysisFrame.swift"
  - "Tennis Trainer/AppRuntime.swift"
  - "Tennis Trainer/AudioManager.swift"
  - "Tennis Trainer/BallDetectionManager.swift"
  - "Tennis Trainer/CameraManager.swift"
  - "Tennis Trainer/ContentView.swift"
  - "Tennis Trainer/Detectors/GridTrackNetDetector.swift"
  - "Tennis Trainer/Detectors/ServeTossApexDetector.swift"
  - "Tennis Trainer/PoseDetectionManager.swift"
  - "Tennis Trainer/VideoImportManager.swift"
  - "Tennis Trainer/VideoPickerView.swift"
  - "Tennis Trainer/VideoPlayerManager.swift"
  - "Tennis Trainer/VideoPlayerView.swift"
  - "Tennis TrainerTests/AnalysisAssociationTests.swift"
  - "Tennis TrainerTests/BallDetectionManagerTests.swift"
  - "Tennis TrainerTests/CameraManagerTests.swift"
  - "Tennis TrainerTests/GridTrackNetDecoderTests.swift"
  - "Tennis TrainerTests/PoseDetectionManagerTests.swift"
  - "Tennis TrainerTests/PracticeLifecycleTests.swift"
  - "Tennis TrainerTests/ServeTossApexDetectorTests.swift"
  - "Tennis TrainerTests/VideoImportManagerTests.swift"
  - "Tennis TrainerTests/VideoPlayerManagerTests.swift"
  - "Tennis TrainerUITests/Tennis_TrainerUITests.swift"
  - "docs/RAMPUP.md"
  - "docs/README.md"
  - "docs/references/README.md"
  - "docs/references/practice-controls-validation.md"
  - "docs/references/toss-cue-validation.md"
covered_digest: "v1:sha256:4b2613e2e043b03467062cbb021544da0709435284f63484a700029e02bc262d"
decision_coverage:
  honored: 0
  total: 0
  not_honored: []
flagged_prohibitions:
  - statement: "MUST NOT present injected lifecycle tests or software cue callbacks as proof of real camera permission recovery, physical capture behavior, clip accuracy, or audible timing."
    status: unresolved
    flagged: true
    reason: "unverified-prohibition — human review recommended; descriptorless projection has no wired enforcement or accepted human disposition"
unresolved_edge_items:
  - id: EDGE-LIFE-01
    category: unclassified
    status: unresolved
    contract: "Human must classify the undefined edge or explicitly accept control-intent invalidation through both held stages and ingress races; deterministic tests do not resolve the unknown classifier row"
  - id: EDGE-LIFE-02
    category: unclassified
    status: unresolved
    contract: "Human must classify/accept fresh-window and no-retrospective-cue semantics, including partial toss loss across reset"
  - id: EDGE-CAM-02
    category: unclassified
    status: unresolved
    contract: "Human must classify/accept actual-state versus requested-intent and Stop dominance during startup/interruption/recovery; injected events alone do not establish hardware delivery"
  - id: EDGE-PLAY-01
    category: unclassified
    status: unresolved
    contract: "Human must classify/accept latest successful current seek plus current play intent, including latest false completion and retry"
  - id: EDGE-PLAY-02
    category: unclassified
    status: unresolved
    contract: "Human must classify/accept Ended, Replay zero-seek and fresh-window/cooldown semantics"
  - id: EDGE-PLAY-03
    category: unclassified
    status: unresolved
    contract: "Human must classify/accept prior usable selection paused after failed/cancelled replacement and current-ready-candidate commit"
resolved_edge_items:
  - id: EDGE-CAM-01
    category: concurrency
    status: verified_explicit_predicate
    evidence: "CameraManagerTests: coalesced request/current OS snapshot, held grant after Stop/context exit, new explicit Start and Settings-return/revocation."
  - id: EDGE-PLAY-04
    category: concurrency
    status: verified_explicit_predicate
    evidence: "VideoPlayerManagerTests: 100 replacement/control cycles, one loop/observer owner, delayed callbacks and 100 eventual owned-copy removals; VideoImportManagerTests preserve originals."
deferred:
  - truth: "Ball and pose overlays align with the actual visible capture/player image."
    addressed_in: "Phase 3"
    evidence: "Phase 3 success criteria 1–3 require source-to-display transforms, source orientation/cropping and actual AV-layer layout checks."
  - truth: "Representative labeled clip accuracy, sustained device/process memory and physical audible onset meet frozen empirical criteria."
    addressed_in: "Phase 4"
    evidence: "Phase 4 success criteria 2–5 require labeled corpus scoring, criteria fixed before scoring, sustained real-device trials and physical audio with uncertainty."
human_verification:
  - test: "Physical permission and Settings recovery: on a supported iPhone record device/OS/build, request undetermined access, deny then Open Settings, grant and return, revoke and return, and inspect available restriction cases."
    expected: "One OS request; denied access opens system Settings; grant alone stays stopped until explicit Start; revocation closes capture; restriction explains the limitation without a misleading action. Unsupported scenarios remain explicit."
    why_human: "DEBUG permission controls and injected authorization snapshots do not exercise the OS permission/Settings boundary."
  - test: "Physical capture and visible clearing: Start, Stop during startup, interrupt capture, Stop during recovery, foreground again, Retry, and switch modes; record actual preview/state and overlay outcomes."
    expected: "Status reflects actual hardware; Stop stays actionable and wins late completion; old overlays clear and do not replace active-mode presentation; return preserves stopped intent and explicit Retry can recover."
    why_human: "Injected startup/notification ordering and seeded UI clearing prove software transitions, not real capture delivery, interruption timing or physical preview behavior."
  - test: "Representative permitted-video review: select a real clip, play, scrub repeatedly, Pause while seeking, reach end, Replay, replace/cancel/fail an import, and leave/return to the mode."
    expected: "Only the current successful seek resumes under Play intent; Pause clears overlays; end stops processing; Replay begins at zero with fresh evidence; failed/cancelled replacement preserves the prior paused usable clip and originals survive."
    why_human: "A generated one-second 64×64 movie and injected picker/player effects do not establish representative local-media user-flow acceptance."
  - test: "EDGE-LIFE-01 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review."
    expected: "Human must classify the undefined edge or explicitly accept control-intent invalidation through both held stages and ingress races; deterministic tests do not resolve the unknown classifier row"
    why_human: "The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance."
  - test: "EDGE-LIFE-02 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review."
    expected: "Human must classify/accept fresh-window and no-retrospective-cue semantics, including partial toss loss across reset"
    why_human: "The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance."
  - test: "EDGE-CAM-02 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review."
    expected: "Human must classify/accept actual-state versus requested-intent and Stop dominance during startup/interruption/recovery; injected events alone do not establish hardware delivery"
    why_human: "The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance."
  - test: "EDGE-PLAY-01 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review."
    expected: "Human must classify/accept latest successful current seek plus current play intent, including latest false completion and retry"
    why_human: "The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance."
  - test: "EDGE-PLAY-02 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review."
    expected: "Human must classify/accept Ended, Replay zero-seek and fresh-window/cooldown semantics"
    why_human: "The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance."
  - test: "EDGE-PLAY-03 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review."
    expected: "Human must classify/accept prior usable selection paused after failed/cancelled replacement and current-ready-candidate commit"
    why_human: "The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance."
  - test: "Evidence-limit prohibition — review the phase verification and validation ledger, then explicitly resolve the retained transparency item."
    expected: "MUST NOT present injected lifecycle tests or software cue callbacks as proof of real camera permission recovery, physical capture behavior, clip accuracy, or audible timing."
    why_human: "The projected prohibition remains status unresolved with no verification or enforcement descriptor. This report's scoped wording is a non-authoritative judge assessment, not human acceptance."
  - test: "VoiceOver: traverse and adjust the playback position slider, inspect elapsed/total announcement and tracking-summary focus order, then clear tracking."
    expected: "Slider purpose/value and native adjustment are understandable; tracking is summarized once per active mode and disappears when cleared; controls remain reachable in a useful order."
    why_human: "UI-tree assertions verify labels, values and absence; they do not observe spoken delivery or focus navigation on hardware."
  - test: "Smallest supported portrait size and accessibility Dynamic Type: inspect Start/Stop/Retry, Play/Pause/Replay, Choose, Cancel and long failure messages."
    expected: "All essential controls and state text remain readable, operable and reachable without clipping or overlap."
    why_human: "UI-05 remains a structural layout warning in a code-only audit; rendered fit at these sizes was not measured."
  - test: "Light/dark and Increase Contrast: inspect enabled/disabled controls, slider/status text and overlays against bright and dark preview backgrounds; measure relevant contrast."
    expected: "Essential actions, status and disabled state remain distinguishable and legible under the inspected appearance settings."
    why_human: "No screenshots or measured contrast results exist; native semantic colors and source review do not establish a visual pass."
---

# Phase 2: Dependable Practice Controls Verification Report

**Phase Goal:** As a player, I want to control live practice and saved-video review, so that old work cannot produce feedback or take over my current session.
**Verified:** 2026-09-26T16:58:45Z
**Status:** human_needed
**Re-verification:** No — initial phase verification; no previous Phase 2 VERIFICATION.md existed.

The implemented software contracts have substantive source and passing behavioral evidence. No outstanding implementation blocker was established. **12/12 is a deterministic truth score, not whole-phase acceptance.** Thirteen human items remain: three physical/media flows, six original undefined edge dispositions, the evidence-limit prohibition, and three rendered/accessibility checks. The user's checkpoint decision changed timing only. Phase 2 must not be declared accepted until its required human items are resolved.

## User Flow Coverage

The canonical `user-story.validate` query returned `true`. This is a user-facing MVP phase; infrastructure auto-pass does not apply.

| Step | Expected | Evidence in codebase | Status |
|---|---|---|---|
| Open live practice and request/recover access | Request, Settings or restriction explanation reflects current access; permission alone does not start capture | `CameraManager.swift:169–203`; `ContentView.swift:239–264`; passing permission manager/UI tests | VERIFIED software flow; physical OS flow UNCERTAIN (WARNING, human item 1) |
| Start, Stop, interrupt or leave live practice | Current intent controls actual state; retired frames/results cannot affect current practice | `CameraManager.swift:271–436,491–508`; held worker/publication, queued/acquired ingress and camera Stop UI tests | VERIFIED software flow; hardware delivery UNCERTAIN (WARNING, item 2) |
| Choose a video | Current validated ready clip becomes a paused selection; failure/cancellation keeps previous selection usable | `ContentView.swift:439–447` → picker/importer → `VideoPlayerManager.swift:187–360`; import/candidate and rendered recovery tests | VERIFIED software flow; representative media UNCERTAIN (WARNING, item 3) |
| Play, scrub, Pause, finish and Replay | Latest successful current timeline governs extraction; end stops it; Replay starts at zero | `VideoPlayerManager.swift:484–656`; completion permutations, native generated-movie integration and UI controls | VERIFIED software flow; representative media inspection pending |
| Replace clips or leave/return | Retired callbacks/owners cannot take over, revive processing or delete originals | `VideoPlayerManager.swift:35–76,690–711`; `VideoImportManager.swift:6–99`; 100 cycles and consumer-lease tests | VERIFIED deterministic ownership; physical acceptance pending |
| Outcome: old work cannot produce feedback or take over my current session | All control boundaries close admission and retire publication authority before asynchronous work can resume | Both real adapters → locked expected-generation admission → guarded publication → active-mode cue forwarding | VERIFIED software outcome; human contracts and physical user-flow acceptance remain open |

Every user-flow step has implementation, caller and automated coverage. The following technical sections establish that code coverage; they do not claim the physical walk-through has passed.

## Goal Achievement

### Observable Truths

Rows 1–5 retain all roadmap success criteria verbatim. Distinct plan detail is retained in rows 6–12; the complete plan-truth mapping below prevents restatements from inflating the score. In tables, `App/` means `Tennis Trainer/`, `Tests/` means `Tennis TrainerTests/`. “VERIFIED” below is scoped to the software contract exercised by the cited tests; human acceptance is separately unresolved.

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Stop, Pause, seek, clip replacement, completion, and mode exit prevent invalidated worker results and already queued publication callbacks from updating overlays or scheduling a new automatic beep; a new session warms up from fresh samples without retrospective feedback. | VERIFIED | `BallDetectionManager.swift:179–291` guards generation before admission and after each publication effect. All six transitions plus scene suspension exercise both held stages in PracticeLifecycleTests, asserting ball/pose/track/frame/cue suppression, lease release and fresh positive cue recovery. |
| 2 | The camera access control requests undetermined access, offers Settings recovery when denied, explains restriction, and rechecks on return; capture state reflects actual startup/running/interruption/failure and honors Stop even when an earlier start or recovery finishes later. | VERIFIED | `CameraManager.swift:113–203,286–436` supplies real AVCapture authorization/Settings effects, immutable backend, operation-scoped startup/events and current snapshots; `ContentView.swift:182–264` renders state/actions. CameraManagerTests 23 and both camera UI methods pass. Physical acceptance remains human items 1–2. |
| 3 | Repeated seeks only resume analysis after the latest successful completion and only while playback remains requested; reaching the end stops processing, and Replay begins at the start with fresh tracking and cooldown state. | VERIFIED | `VideoPlayerManager.swift:544–656` replaces seek identity before cancellation, accepts only matching successful completion, scopes native events to timeline and reads current backend. Latest-seek permutations, held end/Replay lifecycle, real AV movie, and seek/end UI tests pass. |
| 4 | Rapid clip replacement, cancellation, and failed loads leave the current selection usable; late metadata, seek, notification, and detection completions from old items cannot change its state. | VERIFIED | `VideoPlayerManager.swift:187–360` separates candidate/current session, retires seek before Pause and retains retry target. `VideoImportManager.swift:40–96` accepts only current request. Candidate A/B/error/readiness, delayed owner callbacks, both held analysis stages and ten held-seek replacement-failure permutations pass. |
| 5 | Repeated play/pause/replacement cycles maintain only the intended active processing loop and release retired outputs, observers, display links, and app-owned video copies without deleting original or externally owned media. | VERIFIED | `VideoPlayerManager.swift:56–79,370–399,590–620,690–711` owns and retires loop/observer/item/layer pairs. 100-cycle test asserts high-water one, balanced removal, manager deallocation and all 100 copies removed after callback drain; generated AV test checks actual output/layer detachment and preserved external file. |
| 6 | Stop invalidates before physical teardown, and old acquired or already queued camera buffers cannot enter a restarted analysis generation. | VERIFIED | `CameraManager.swift:294–370,492–508` implements stop/detach/drain/current-start fence; expected generation is checked under the scheduler lock. Passing `testAcquiredCaptureCallbackCannotEnterRestartedGeneration`, `testQueuedCaptureCallbackIsDrainedBeforeRestartOpensIngress`, both Stop-held-stage tests and `testExpectedGenerationRejectsAcquiredInput_WithoutPoseOrLease`. |
| 7 | Pause, mode exit and scene suspension close ingress immediately; a retired mode cannot clear the current pose, update ball/frame display or cue, and return respects cleared intent. | VERIFIED | `ContentView.swift:19–20,65–99,106–110,449–472` owns separate presenters and active-context sinks; nested BallOverlayView observes resets directly. Both-direction pose-clear, reentrant Stop/Pause, scene-suspension and visible Stop/Pause UI clearing tests pass. Conditional pose-group construction at lines 150/289 removes empty accessibility state. |
| 8 | Fresh sessions require five fresh frames before prediction and retain the original strict pose fallback and four-second cooldown rules; resets/Replay create fresh evidence and cooldown domains. | VERIFIED | `AnalysisFrame.Window` requires five coherent frames; grid reset precedes next worker; `ServeTossApexDetector.swift:87–115` keeps strict >0.70 fallback, exact four-second comparison and resets by source/generation. Lifecycle tests assert four-frame warmup then a fresh cue inside retired cooldown. All five Phase 1 classes pass, including exact association, decoder, pose and cooldown tests. |
| 9 | Late authorization/recovery cannot open capture after Stop/context exit; recovery requires current intent, authorized access and live context, and reopens only fresh evidence. | VERIFIED | `CameraManager.swift:170–190,329–356,365–436` separates permission request from capture operation, requeries OS state, rejects retired completion and bounds automatic recovery. Held grant/Stop/new Start, revocation after dispatch, Stop during configure/start/recovery, current interruption fresh-cue and explicit Retry tests pass. |
| 10 | Cancelled/false/superseded seek results cannot resume or overwrite current position; obsolete same-item end/error events cannot retire a newer timeline. | VERIFIED | `VideoPlayerManager.swift:545–580,592–656` validates finite targets, load/seek/timeline identity after state dispatch and fresh stopped-at-end/failed state. `testOnlyLatestSuccessfulSeekMayResume_InEveryCompletionOrder`, failed retry, invalid backend position and `testSameItemHeldEndAndErrorCannotStopNewSeekOrReplayAndFreshCue` pass, including positive current-event checks. |
| 11 | Only the current playable, finite-positive-duration, video-bearing and ready candidate commits; every asynchronous metadata/readiness result remains request-owned. | VERIFIED | `VideoPlayerManager.swift:29–31,224–360` validates metadata, checks after each suspension/state hop and rereads item readiness before atomic commit. Tests cover each invalid metadata field, ready/metadata in both orders, A/B success/error, duplicate completion, state-hop supersession, first-load/replacement failures and context cancellation. |
| 12 | Imported media uses unique owned destinations copied during provider lifetime; partial/stale/retired results clean up only after their consumers release, preserving external originals. | VERIFIED | `VideoPickerView.swift:31–40` calls importer synchronously; `VideoImportManager.swift:6–28,45–73` uses UUID/allowlisted extension and private ARC deletion owner. Metadata, readiness, seek, event/time and frame-read leases retain ownership. Actual file preservation, copy-lifetime, duplicate-basename, collision, partial failure and held-consumer tests pass. |

**Score: 12/12 truths verified; 0 present-but-behavior-unverified truths.** Every listed transition/invariant has passing behavioral evidence; none is credited from symbol presence alone. Human items concern unperformed physical/visual acceptance and undefined contract disposition, not absent deterministic transition tests. No overrides or coincidental-reliance items: production establishes the ordering/identity preconditions; fixtures supply controlled framework inputs.

### Plan Truth Traceability

| Plan truth | Merged truth rows | Specific detail retained |
|---|---|---|
| 02-01.1 | 1, 6 | Immediate invalidation and both acquired/queued ingress races |
| 02-01.2 | 1, 7, 8 | Pause/mode/scene invalidation and fresh return |
| 02-01.3 | 7 | Retired mode cannot publish/clear/count/cue |
| 02-01.4 | 8 | Five fresh frames, strict fallback and four-second cooldown |
| 02-02.1 | 2 | Coalesced undetermined request, denied Settings, restriction, active recheck |
| 02-02.2 | 9 | Overlapping permission/recovery respects Stop and context |
| 02-02.3 | 2 | Actual starting/running/interrupted/failed and available Stop |
| 02-02.4 | 8, 9 | Current authorized recovery with fresh warmup |
| 02-03.1 | 3 | Seek closes immediately; latest success/current item/play intent only |
| 02-03.2 | 10 | False/cancelled/superseded seek cannot resume or overwrite |
| 02-03.3 | 3, 10 | Current end invalidates; obsolete same-item events rejected |
| 02-03.4 | 3, 8 | Successful zero-seek Replay and fresh window/cooldown |
| 02-03.5 | 5 | At most one display link through repeated controls |
| 02-04.1 | 4, 11 | Replacement invalidates; current valid ready candidate commits |
| 02-04.2 | 4 | Failure/cancellation preserves prior paused selection and current error/loading |
| 02-04.3 | 10, 11, 12 | Request/session ownership across all callbacks and stale owned cleanup |
| 02-04.4 | 5 | Original-owner retirement, eventual current-only media |
| 02-04.5 | 12 | Unique destinations, consumer lifetime and original preservation |

All **18** plan truths map to evidence above; all five roadmap criteria remain in scope.

### Required Artifacts

Canonical `verify.artifacts` returned **5/5, 4/4, 4/4, 5/5**. These are 18 declarations covering 12 unique paths. Manual whole-file inspection verified implementation and wiring as well as existence.

| Artifact | Expected | Status | Substantive and wiring evidence |
|---|---|---|---|
| App/BallDetectionManager.swift | Atomic admission and bounded publication lease | VERIFIED | Both adapters call expected-generation process; actual backend/pose pipeline and guarded effects are implemented. |
| App/CameraManager.swift | Immediate controls, queue fence and real access/capture effects | VERIFIED | ContentView controls/context call manager; AVCapture delegate calls guarded ingress; one immutable backend owns preview/start/stop. |
| App/VideoPlayerManager.swift | Controls, candidate commit and retirement | VERIFIED | UI buttons/slider/import outcomes call production state machine; real AV item/output/observers/seek callbacks wired. |
| App/ContentView.swift | Mode lifecycle, access/playback UI and separate pose observation | VERIFIED | Real StateObjects, buttons, scene/mode/disappear handlers, ball/pose render and audio sinks; seven phase UI methods pass. |
| Tests/PracticeLifecycleTests.swift | Control-to-cue held-stage proof | VERIFIED | 23 executed cases call production public controls/adapters, real preparation/decoder/apex, held schedulers and positive recovery. |
| Tests/CameraManagerTests.swift | Permission/start/event permutations | VERIFIED | 23 cases assert current state, backend counts, late outcomes, observer lifetime and initialized backend identity. |
| Tennis TrainerUITests/Tennis_TrainerUITests.swift | Rendered controls/recovery/clearing | VERIFIED | Seven phase methods drive actual buttons and assert state/actionability; full scheme executes them. |
| Tests/VideoPlayerManagerTests.swift | Seek/timeline/candidate/resource behavior | VERIFIED | 28 cases, including generated AV movie, delayed consumers, native teardown and ownership stress. |
| App/VideoImportManager.swift | Current import and explicit ownership | VERIFIED | Picker → synchronous unique copy → current outcome → player; private final owner deletes only its owned URL. |
| App/VideoPickerView.swift | Identity-bearing picker outcomes | VERIFIED | Videos-only/single selection; captured request/importer handoff; dismissal distinguishes selection/cancellation. |
| Tests/VideoImportManagerTests.swift | Provider/copy/removal ownership proof | VERIFIED | Nine cases cover real filesystem preservation, unique names, current handoff, collision/partial failure and delayed lease. |
| docs/references/practice-controls-validation.md | Evidence ledger and outstanding checks | VERIFIED | Final commands/counts match logs/xcresult; failed attempt preserved; linked from docs/architecture; human limits explicit. |

Supporting AppRuntime factories are DEBUG-gated; Release compiles production defaults. Empty initial pose/position, optional injected no-ops and test-only scripted files are populated production state or explicit fixtures, not stubs. Synchronized Xcode groups include these files; no orphan artifact was found.

### Key Link Verification

Canonical `verify.key-links` returned **4/4, 3/3, 3/3, 3/3**. All thirteen declarations were manually traced beyond pattern matches.

| Plan link | From → To | Via / source evidence | Status |
|---|---|---|---|
| 02-01.1 | Camera → analysis reset | Stop clears operation/ingress and resets before queued AV teardown (Camera 365–386) | WIRED |
| 02-01.2 | Capture callback → locked analysis admission | receiveSampleBuffer snapshots generation; process validates inside state lock (Camera 492–508; Ball 179–201) | WIRED |
| 02-01.3 | ContentView → camera context | mode/scene/disappear invalidates even when not recording (ContentView 106–110,449–472) | WIRED |
| 02-01.4 | ContentView → player context | outgoing/context suspension cancels candidate and Pauses (ContentView 468–472; Player 536–539) | WIRED |
| 02-02.1 | Access UI → real permission/Settings | Request/Settings buttons → dependencies → AVCaptureDevice/system Settings; active return refreshes | WIRED |
| 02-02.2 | Capture session events → current visible state | session-filtered observations capture operation; state hop checks current snapshot and updates published captureState | WIRED |
| 02-02.3 | Capture intent → analysis eligibility | successful current authorized startup after drain sets ingress generation; interruption/reset closes it | WIRED |
| 02-03.1 | Slider/Play/Pause/Replay → player intent | ContentView 347–389 invokes seek/play/pause; play on Ended routes replay | WIRED |
| 02-03.2 | Seek completion → frame-loop reopen | matching load/seek plus success/finite position and current play/context reach beginPlayback | WIRED |
| 02-03.3 | Item end/error → analysis reset/Ended | captured timeline/load after state hop + fresh backend → closePlayback and terminal state | WIRED |
| 02-04.1 | PHPicker provider → owned importer handle | provider callback copies before return; current request queues MediaHandle, not temporary provider URL | WIRED |
| 02-04.2 | Validated current candidate → committed session | metadata + ready + current identity → commitIfReady → retire old session, assign fresh source | WIRED |
| 02-04.3 | Retired player/candidate → owned-file release | async consumers capture leases; original AV owners detach before final MediaHandle release | WIRED |

Additional end-to-end link: current guarded onApex → camera/player forwarding → ContentView's active-mode/scene guard → AudioManager.playBeep → scheduleBuffer. Manual Test Beep is separate. Tests count the automatic callback boundary; physical onset is unmeasured.

### Data-Flow Trace (Level 4)

| Rendered value | Real data source | Flow | Status |
|---|---|---|---|
| Permission and capture status | AVCaptureDevice authorization and current AVCaptureSession snapshot/events | injected-or-production dependencies → published AccessState/CaptureState → text/buttons | FLOWING; hardware experience pending |
| Clip/current position/duration | PHPicker representation, AVAsset metadata/readiness, owned AVPlayer current time | owned candidate → committed session → published duration/currentTime/playbackState → layer/slider/status | FLOWING; real AV generated-movie check passes |
| Ball and pose overlays | Admitted camera CMSampleBuffer or AVPlayer output pixels; Vision/Core ML | captured identity → owned window → guarded publication → mode-owned pose and observed ball view | FLOWING; source-to-display geometry deferred to Phase 3 |
| Automatic feedback | Current unseen eligible candidate with its associated pose | apex detector → guarded manager/media callback → active UI sink → audio scheduling | FLOWING software path; physical sound unmeasured |
| Loading/recovery messages | Current import/provider/metadata/readiness outcome | request identity checks → manager state → actionable loading/error/previous selection UI | FLOWING |

Production outputs do not terminate in hardcoded fixture data. DEBUG UI scenarios are opt-in and do not replace the production path in Release.

### Behavioral Spot-Checks and Final Gate Evidence

The orchestrator independently ran the complete final gates at source **212f17e923ea9228c142e03940153620d06b6cdd**. This verifier inspected full relevant test bodies, raw log results, machine-readable exit records and freshly queried both finalized result summaries. `git diff 212f17e -- 'Tennis Trainer' 'Tennis TrainerTests' 'Tennis TrainerUITests' 'Tennis Trainer.xcodeproj'` is empty. Evidence documentation stabilized at `d3d072e`. No duplicate test suite or simulator service was launched by this verifier.

Exact commands recorded in the stable ledger and `/tmp/tennis-phase2-verified-checks/results.json`:

```sh
xcodebuild build -configuration Release -scheme 'Tennis Trainer' -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO
xcodebuild test -collect-test-diagnostics never -parallel-testing-enabled NO -scheme 'Tennis Trainer' -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' '-only-testing:Tennis TrainerTests' -resultBundlePath /tmp/tennis-phase2-verified-checks/unit-regression-745e9a37.xcresult
xcodebuild test -collect-test-diagnostics never -parallel-testing-enabled NO -scheme 'Tennis Trainer UI Tests' -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -resultBundlePath /tmp/tennis-phase2-verified-checks/ui-f45da81b.xcresult
xcrun xcresulttool get test-results summary --path /tmp/tennis-phase2-verified-checks/unit-regression-745e9a37.xcresult --compact
xcrun xcresulttool get test-results summary --path /tmp/tennis-phase2-verified-checks/ui-f45da81b.xcresult --compact
```

| Behavior / gate | Executed evidence inspected | Result | Status |
|---|---|---|---|
| Production build | build.log + exit record | BUILD SUCCEEDED, exit 0 | PASS |
| All software invariants and prior-phase regression | unit-regression.log + finalized xcresult | 149 passed; 0 failure/skip/expected failure; exit 0 | PASS |
| All actual rendered control scenarios | ui.log + finalized xcresult | 11 executions / 10 distinct tests; 0 failure/skip; exit 0 | PASS |
| Framework readiness/seek/end/Replay/retirement | `testGeneratedMovieReadinessSeekEndReplayAndRetirement` in final unit log | Passed, 0.709 s; actual AV item/output/layer and external original assertions | PASS — framework wiring only |
| Corrected visible Stop/Pause clearing | `testVisibleOverlayClearOnStopAndPause` in final UI log | Passed, 6.983 s | PASS — injected publishers/real UI |
| Repeated owner/copy lifetime | `testHundredReplacementCyclesBalanceOwnersAndReleaseAllCopies` and held-consumer tests | Passed; one maximum loop/time/event owner; all 100 final owned releases | PASS — deterministic ownership |
| Structural verification | canonical artifact/link/story/decision queries; git diff --check | 18 artifact / 13 link declarations; valid story; clean whitespace | PASS |

Unit inventory: AnalysisAssociationTests 10, BallDetectionManagerTests 22, CameraManagerTests 23, GridTrackNetDecoderTests 6, PoseDetectionManagerTests 4, PracticeLifecycleTests 23, ServeTossApexDetectorTests 23, VideoImportManagerTests 9, VideoPlayerManagerTests 28, Swift Testing scaffold 1 = **149**. UI main class runs nine methods, including seven Phase 2 behavior methods; the launch class has one distinct test with two parameter runs, producing **11 executions / 10 distinct tests**. Baseline launch/performance/scaffold cases are not substitutes for requirement evidence.

The earlier complete UI attempt `/tmp/tennis-phase2-post-review-checks/ui-46767432.xcresult` failed overlay absence after Stop. It is retained as **failed**, fixed by conditional group construction in `212f17e`, and superseded only by the complete final successful rerun. Earlier incomplete diagnostic-collection attempts are not passes. The source-review's “rerun pending” wording is historical; final behavior is established by these later finalized bundles.

### Probe Execution

No runnable shell probe is declared in the phase PLAN/SUMMARY files and this repo has no `scripts/` probe tree. Step 7c: **N/A — no executable probes**. The canonical edge coverage refers to planning classification, not an executable acceptance probe: six rows are explicitly unclassified and have no runnable descriptor. They remain human obligations below; none is marked “probe passed.”

### Requirements Coverage

| Requirement | Source plans | Description | Status | Evidence / remaining acceptance |
|---|---|---|---|---|
| LIFE-01 | 01, 02, 03, 04 | Every invalidating control rejects old overlays/new automatic cues | SATISFIED software; NEEDS HUMAN acceptance | Truths 1,6,7,9,10; both held stages and ingress races. Physical flows and EDGE-LIFE-01 pending; checkbox remains unchecked. |
| LIFE-02 | 01, 02, 03, 04 | Fresh temporal evidence and no retrospective cue | SATISFIED software; NEEDS HUMAN acceptance | Truths 1,3,8,9,11; positive fresh warmup/cue after resets. EDGE-LIFE-02/partial-toss semantics pending; checkbox unchecked. |
| CAM-01 | 02 | Request/Settings/restriction/active recheck | SATISFIED software; NEEDS HUMAN hardware acceptance | Truths 2,9; request/current snapshot and UI tests; defined EDGE-CAM-01 supported. Checked requirement explicitly means implementation only; physical OS flow pending. |
| CAM-02 | 02 | Actual capture state and Stop during startup/recovery | SATISFIED software; NEEDS HUMAN acceptance | Truths 2,9; backend/late-start/recovery tests. Checked implementation is not hardware acceptance; EDGE-CAM-02 and physical flow pending. |
| PLAY-01 | 03 | Latest successful seek resumes only under current Play | SATISFIED software; NEEDS HUMAN acceptance | Truths 3,10; all completion orders, false retry and UI tests. Checked implementation does not resolve EDGE-PLAY-01 or real-clip inspection. |
| PLAY-02 | 03 | Ended and Replay from zero with fresh state | SATISFIED software; NEEDS HUMAN acceptance | Truths 3,8,10; current/stale native event semantics, real generated movie, UI. EDGE-PLAY-02 and representative media remain pending despite checkbox. |
| PLAY-03 | 04 | Current candidate only; failed/cancelled import recovery | SATISFIED software; NEEDS HUMAN acceptance | Truths 4,11,12; cross-control held seek, candidate/provider failure, actual rendered recovery. EDGE-PLAY-03 and media inspection pending; checkbox unchecked. |
| PLAY-04 | 03, 04 | Single loop, owned cleanup and preserved originals | SATISFIED software; NEEDS HUMAN phase acceptance | Truths 5,12; 100 cycles, real files/AV teardown, held consumers. Defined EDGE-PLAY-04 verified; checkbox remains unchecked pending phase acceptance. Sustained process-memory scoring is Phase 4. |

All eight mapped requirement IDs are claimed by at least one plan; **0 orphaned requirements**. No completion inference was made from SUMMARY requirement arrays or mixed requirement checkboxes.

### Decision Coverage

Canonical result: **“No CONTEXT.md - nothing to check.”** Skipped, 0/0, nonblocking. The documented user decision to defer physical checks is timing authorization, not an accepted override or a human pass.

### Test Quality Audit

| Test file | Linked requirements | Active/passed | Skipped | Circular | Assertion level | Verdict |
|---|---|---:|---:|---|---|---|
| BallDetectionManagerTests | LIFE-01/02 and inherited CUE | 22 | 0 | No | Lock/admission counts, held lease/publication, identity and real buffer lifetime | Sufficient for software scope |
| PracticeLifecycleTests | LIFE-01/02, CAM-02, PLAY-01/02/03/04 | 23 | 0 | No | Public controls → actual preparation/decoder/apex; negative stale effects and positive fresh recovery | Sufficient |
| CameraManagerTests | CAM-01/02 | 23 | 0 | No | Held authorization/start/events, exact backend counts/state, weak lifetime | Sufficient software; hardware pending |
| VideoPlayerManagerTests | PLAY-01/02/03/04 | 28 | 0 | No | Completion permutations, current state, 100 owners/copies, actual AV assertions | Sufficient software/framework scope |
| VideoImportManagerTests | PLAY-03/04 | 9 | 0 | No | Actual bytes/original preservation, provider lifetime, delayed lease/removal | Sufficient |
| Tennis_TrainerUITests | CAM/PLAY/LIFE controls | 7 phase behavior methods | 0 | No | Actual button actions, labels/enablement, slider values and cleared UI tree | Sufficient injected-control scope |

Five prior-phase classes are retained in the 149-test run. No disabled requirement-linked test or circular expected-output generator was found. Generated movie bytes are input data, not expected answers generated by the player. Synthetic tensors have controlled independently specified trajectories; they test pipeline/lifecycle behavior, not tennis accuracy.

Disconfirmation pass: (1) CAM-01 physical Settings recovery is only partially evidenced and remains human-needed. (2) The launch-only `testExample` and injected import scenario's three-byte file can pass without proving real permission/media behavior; neither is used for those claims. (3) Actual OS restriction/interruption and physical recovery failures are not induced by the software tests, so their error experience remains pending. None establishes an uncovered deterministic implementation defect.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| Tests/BallDetectionManagerTests.swift | 32–36 | Deliberate held semaphores trigger existing QoS warning | INFO | Passing resource-bound fixture; no production timing inference |
| App/ContentView.swift | 209,371,423 | Fixed action rows/safe-area content without accessibility-size alternate | WARNING / human item 12 | UI-05 structural risk; no reproduced clipping/unreachable control defect |
| Tennis TrainerUITests/Tennis_TrainerUITests.swift | 262 onward | Baseline setup/launch/performance scaffold | INFO | Excluded as correctness evidence; seven actual Phase 2 methods cover controls |

No unreferenced TBD/FIXME/XXX debt marker, goal-blocking stub, orphan, swallowed user-facing operation or payload log was found in changed implementation/tests. Optional no-op injected effects and empty initial values have real production counterparts. `git diff --check` passes. Independent review's two blockers are resolved by `d1af3ea` and `792d728`; source and the corresponding final passing tests were independently inspected. All 16 planned L1 threat mitigations are present; the scoped SECURITY result does not certify physical behavior.

### Prohibitions and Edge Dispositions

**unverified-prohibition — human review recommended.**

> MUST NOT present injected lifecycle tests or software cue callbacks as proof of real camera permission recovery, physical capture behavior, clip accuracy, or audible timing.

The exact descriptorless `statement` + `status: unresolved` projection is preserved. No verification tier or enforcement descriptor was invented. The ledger/report currently respects the stated limitation, but that non-authoritative source judgment does not close the explicit human evidence review (item 10).

Defined concurrency predicates EDGE-CAM-01 and EDGE-PLAY-04 have tested implementation evidence. The six other original rows remain **unclassified / unresolved**, with the exact authored disposition preserved in frontmatter/human items. Eight surfaced edges = two explicit tested predicates + six human dispositions; zero silently dropped or auto-resolved. The six are not failed implementation tests and not accepted contracts.

### Deferred Items

| Item | Addressed in | Roadmap evidence |
|---|---|---|
| Displayed live/video marker placement | Phase 3 | SC1–3: transforms, cropping/orientation, rendered image rectangle and actual AV-layer layout |
| Final clip accuracy, sampling/gap bounds, sustained device/process memory and audible onset | Phase 4 | SC2–5: labeled corpus, criteria frozen before scoring, real device/audio trials and explicit missing evidence |

Only these specifically owned later-phase measurements are deferred. Physical permission/control/representative-media checks already promised by Phase 2 remain in this phase's human list. No observed implementation gap was moved to a future phase.

### Human Verification Required

All thirteen items are **UNCERTAIN (WARNING)** pending explicit human evidence/disposition. The five deferred PLAN human-check blocks were harvested and deduplicated into these items. No physical or visual pass is inferred from the final simulator gates.

#### 1. Physical permission and Settings

**Test:** Physical permission and Settings recovery: on a supported iPhone record device/OS/build, request undetermined access, deny then Open Settings, grant and return, revoke and return, and inspect available restriction cases.

**Expected:** One OS request; denied access opens system Settings; grant alone stays stopped until explicit Start; revocation closes capture; restriction explains the limitation without a misleading action. Unsupported scenarios remain explicit.

**Why human:** DEBUG permission controls and injected authorization snapshots do not exercise the OS permission/Settings boundary.

#### 2. Physical capture and visible clearing

**Test:** Physical capture and visible clearing: Start, Stop during startup, interrupt capture, Stop during recovery, foreground again, Retry, and switch modes; record actual preview/state and overlay outcomes.

**Expected:** Status reflects actual hardware; Stop stays actionable and wins late completion; old overlays clear and do not replace active-mode presentation; return preserves stopped intent and explicit Retry can recover.

**Why human:** Injected startup/notification ordering and seeded UI clearing prove software transitions, not real capture delivery, interruption timing or physical preview behavior.

#### 3. Representative permitted-video controls

**Test:** Representative permitted-video review: select a real clip, play, scrub repeatedly, Pause while seeking, reach end, Replay, replace/cancel/fail an import, and leave/return to the mode.

**Expected:** Only the current successful seek resumes under Play intent; Pause clears overlays; end stops processing; Replay begins at zero with fresh evidence; failed/cancelled replacement preserves the prior paused usable clip and originals survive.

**Why human:** A generated one-second 64×64 movie and injected picker/player effects do not establish representative local-media user-flow acceptance.

#### 4. EDGE-LIFE-01

**Test:** EDGE-LIFE-01 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review.

**Expected:** Human must classify the undefined edge or explicitly accept control-intent invalidation through both held stages and ingress races; deterministic tests do not resolve the unknown classifier row

**Why human:** The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance.

#### 5. EDGE-LIFE-02

**Test:** EDGE-LIFE-02 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review.

**Expected:** Human must classify/accept fresh-window and no-retrospective-cue semantics, including partial toss loss across reset

**Why human:** The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance.

#### 6. EDGE-CAM-02

**Test:** EDGE-CAM-02 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review.

**Expected:** Human must classify/accept actual-state versus requested-intent and Stop dominance during startup/interruption/recovery; injected events alone do not establish hardware delivery

**Why human:** The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance.

#### 7. EDGE-PLAY-01

**Test:** EDGE-PLAY-01 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review.

**Expected:** Human must classify/accept latest successful current seek plus current play intent, including latest false completion and retry

**Why human:** The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance.

#### 8. EDGE-PLAY-02

**Test:** EDGE-PLAY-02 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review.

**Expected:** Human must classify/accept Ended, Replay zero-seek and fresh-window/cooldown semantics

**Why human:** The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance.

#### 9. EDGE-PLAY-03

**Test:** EDGE-PLAY-03 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review.

**Expected:** Human must classify/accept prior usable selection paused after failed/cancelled replacement and current-ready-candidate commit

**Why human:** The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance.

#### 10. Evidence-limit prohibition

**Test:** Evidence-limit prohibition — review the phase verification and validation ledger, then explicitly resolve the retained transparency item.

**Expected:** MUST NOT present injected lifecycle tests or software cue callbacks as proof of real camera permission recovery, physical capture behavior, clip accuracy, or audible timing.

**Why human:** The projected prohibition remains status unresolved with no verification or enforcement descriptor. This report's scoped wording is a non-authoritative judge assessment, not human acceptance.

#### 11. VoiceOver

**Test:** VoiceOver: traverse and adjust the playback position slider, inspect elapsed/total announcement and tracking-summary focus order, then clear tracking.

**Expected:** Slider purpose/value and native adjustment are understandable; tracking is summarized once per active mode and disappears when cleared; controls remain reachable in a useful order.

**Why human:** UI-tree assertions verify labels, values and absence; they do not observe spoken delivery or focus navigation on hardware.

#### 12. Portrait/large-text fit

**Test:** Smallest supported portrait size and accessibility Dynamic Type: inspect Start/Stop/Retry, Play/Pause/Replay, Choose, Cancel and long failure messages.

**Expected:** All essential controls and state text remain readable, operable and reachable without clipping or overlap.

**Why human:** UI-05 remains a structural layout warning in a code-only audit; rendered fit at these sizes was not measured.

#### 13. Appearance and contrast

**Test:** Light/dark and Increase Contrast: inspect enabled/disabled controls, slider/status text and overlays against bright and dark preview backgrounds; measure relevant contrast.

**Expected:** Essential actions, status and disabled state remain distinguishable and legible under the inspected appearance settings.

**Why human:** No screenshots or measured contrast results exist; native semantic colors and source review do not establish a visual pass.

### Gaps Summary

No outstanding software BLOCKER or failed must-have was established. The tested software goal is implemented: 12 merged truths, 18 plan-truth declarations, 12 unique artifacts, 13 key links and eight requirements have specific source and behavioral evidence. Overall status remains **human_needed** because thirteen required human items are unresolved; the phase is not ready to be described as fully accepted.

The canonical fingerprint covers every phase PLAN/SUMMARY (no nested or superseded plans found), mapped requirements, all changed implementation/tests and stable supporting evidence. Its values were copied from `verification.fingerprint`, not calculated by hand. Operational STATE, pending UAT and roadmap progress are excluded because orchestration updates them after this report; the exact reviewed roadmap goal and all five success criteria are captured above. No source edits or commits were made by this verifier.

---

_Verified: 2026-09-26T16:58:45Z_
_Verifier: gsd-verifier_

