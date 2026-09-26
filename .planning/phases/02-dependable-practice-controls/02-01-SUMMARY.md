---
phase: 02-dependable-practice-controls
plan: "01"
subsystem: media-lifecycle
tags: [swift, avfoundation, xctest, admission, lifecycle]
requires:
  - phase: 01-consistent-toss-cues
    provides: Bounded analysis lease, owned five-frame windows and exact pose association
provides:
  - Atomic expected-generation admission and capture stop/detach/drain restart boundary
  - Immediate Stop/Pause/context invalidation through production adapter controls
  - Separate mode-owned pose presentation and directly observed ball overlays
  - Sixteen lifecycle regressions with real preparation/decoder and injected AV effects
affects: [02-02, 02-03, 02-04, overlay-alignment, device-verification]
tech-stack:
  added: []
  patterns: [captured admission generation, serial capture drain boundary, mode-owned presentation]
key-files:
  created: [Tennis TrainerTests/PracticeLifecycleTests.swift]
  modified:
    - Tennis Trainer/BallDetectionManager.swift
    - Tennis Trainer/CameraManager.swift
    - Tennis Trainer/VideoPlayerManager.swift
    - Tennis Trainer/ContentView.swift
    - Tennis TrainerTests/BallDetectionManagerTests.swift
    - LEARNINGS.md
key-decisions:
  - Capture restart stops and detaches on the session queue before draining the callback queue and reopening only the current successful operation.
  - Scene/context return restores eligibility only; explicit Start or Play is required after suspension, while explicit live-mode entry retains its Start behavior.
  - Each mode owns its pose presenter; a nested observed ball view redraws clearing independently of frame counters.
requirements-completed: [LIFE-01, LIFE-02]
coverage:
  - id: D1
    description: Stop and restart reject acquired, queued, worker-held and publication-held old capture work
    requirement: LIFE-01
    verification:
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testAcquiredCaptureCallbackCannotEnterRestartedGeneration
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testQueuedCaptureCallbackIsDrainedBeforeRestartOpensIngress
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testStopInvalidatesHeldWorker_BeforePhysicalTeardown
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testStopInvalidatesHeldPublication_BeforePhysicalTeardown
        status: pass
    human_judgment: false
  - id: D2
    description: Pause and context exits invalidate old playback effects and preserve acquired display-time identity
    requirement: LIFE-01
    verification:
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testAcquiredPlaybackFrameCannotCrossPauseAndResume
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testSceneSuspensionClosesBothAdaptersAndReturnDoesNotResume
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testReentrantStopAndPauseDuringTrackPublicationSuppressCueAndFrame
        status: pass
    human_judgment: false
  - id: D3
    description: Fresh five-frame windows and synthetic toss cues after reset, with existing bounds and cue policy retained
    requirement: LIFE-02
    verification:
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testFreshCaptureTossCanCueInsideRetiredSessionsCooldown
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testRepeatedPlayOwnsOneLoopAndFreshCueAfterPause
        status: pass
      - kind: unit
        ref: /tmp/tennis-02-01-task2-final.xcresult
        status: pass
    human_judgment: false
  - id: D4
    description: Separate mode-owned overlays and Stop/Pause/mode-return visible clearing
    requirement: LIFE-01
    verification:
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testCurrentModePoseSurvivesRetiredModesDelayedClear_InBothDirections
        status: pass
    human_judgment: true
    rationale: Ownership is deterministically tested; visible clearing and physical camera/audio behavior still need end-of-phase review.
actuals:
  tokens: 12010
  tasks: 2
  commits: 4
commits: 4
plan_head_before: 5c8b507a28d302e71d6313ec3be7c73c704ac336
measurement_head: 16d088d
duration: 14min
completed: 2026-09-26
status: complete
---

# Phase 2 Plan 1: Current-Session Practice Controls Summary

**Synchronous control invalidation, a drained capture restart boundary, and acquired-frame generation checks prevent retired work from reaching current overlays or the automatic cue sink.**

## Performance and Task Commits

Execution timestamp recorded at 2026-09-26T14:46:33Z; verified implementation and actuals measured at 2026-09-26T14:59:53Z. Two tasks, seven implementation/test/learnings files. Actual tokens are ceiling of 48,038 scoped realized-diff characters divided by four. Four commits are measured from the persisted `.git/gsd-plan-head-before-02-01` ledger to measurement_head, before metadata commits.

1. `e811670` — Task 1 RED: expose stale publication after camera Stop.
2. `057c353` — Task 1 GREEN: guard capture restart and analysis admission.
3. `1357cd7` — Task 2 RED: expose stale playback effects after Pause.
4. `16d088d` — Task 2 GREEN: invalidate playback and isolate mode presentation.

Root-pin and protected-branch guards ran before commits; project config explicitly permits the existing sequential main strategy. Hooks were not bypassed. No tracked files were deleted. Parent-owned orchestration files were left alone.

## Accomplishments and Interfaces

- `BallDetectionManager.admissionGeneration: UUID` reads the current generation under the scheduler lock. `process(input:expectedGeneration: UUID? = nil) -> Bool` validates it inside that same lock before lease reservation, pose extraction or worker dispatch. Lower-level Phase 1 call sites remain compatible. One lease through the effect batch, zero pending inputs, deferred worker reset and all post-effect checks remain intact.
- `CameraManager.Dependencies` injects `session`, `drain`, `state`, `stop`, `attach`, `start` and an acquired-frame boundary hook before real effects. Default tests suppress AV effects, not transitions. `captureRequested` distinguishes requested startup from `isRecording`; Stop is available while startup is pending. Public Start establishes a new operation and analysis identity. Public Stop closes ingress and invalidates analysis synchronously before scheduling teardown. `receiveSampleBuffer(_:)` is the shared production callback ingress, preserving capture PTS and `.right`; `submitSampleBuffer(_:expectedGeneration:)` retains the lower-level timestamp seam.
- Restart orders physical stop and delegate detach on the session queue, drains the serial video callback queue, then reattaches/starts on the session queue only for the current operation. Ingress opens only after a successful start and a current state-executor completion. No ingress lock spans AV start/stop, Vision, or prediction. The session and video queues remain separate.
- `VideoPlayerManager.Dependencies` injects play/pause and loop effects. `processPlaybackFrame(output:requestedTime:orientation:)` is the active production ingress used by `processDisplayLinkFrame`; `processCurrentFrame(..., requiresActiveContext: Bool = false)` retains the original lower-level fixture seam. Source, item, frame-run and analysis generation are captured before frame acquisition and checked afterward. The copied display time remains authoritative. Pause invalidates before AV pause/link cleanup. Repeated Play maintains one loop.
- Both adapters expose `setContextActive(_:)`. ContentView unconditionally retires outgoing contexts, suspends both on scene inactivity/disappearance, and restores selected-context eligibility without automatic resume. Explicit live-mode entry still creates a new Start intent. Repeated analysis setup is idempotent.
- ContentView owns separate `cameraPoseManager` and `playbackPoseManager`. `BallOverlayView` directly observes its nested BallDetectionManager, so clearing redraws without an FPS tick. Current-mode/context checks guard frame-count and automatic cue forwarding. Existing coordinate formulas and manual Test Beep are preserved.

## Verification

Environment: Xcode 27.0, iPhone 17 Pro simulator, iOS 26.5 (23F77); simulator availability was rechecked before tests. App deployment target remains iOS 18.5. No real camera, model inference, or audio construction occurs in lifecycle fixtures; the bundled-model smoke remains part of the inherited full suite.

All commands begin with:

`xcodebuild test -scheme 'Tennis Trainer' -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

| Run | Additional selector/options | Passed | Failed | Skipped | Result bundle under /tmp |
|---|---|---:|---:|---:|---|
| Task 1 RED | `'-only-testing:Tennis TrainerTests/PracticeLifecycleTests'` | 0 | 1 | 0 | tennis-02-01-task1-red.xcresult |
| Task 1 GREEN | lifecycle + manager selectors below | 29 | 0 | 0 | tennis-02-01-task1-green.xcresult |
| Task 1 final | lifecycle + manager selectors below | 29 | 0 | 0 | tennis-02-01-task1-final.xcresult |
| Committed tracer feedback gate | lifecycle + manager selectors below | 29 | 0 | 0 | tennis-02-01-tracer-gate.xcresult |
| Task 2 RED | `'-only-testing:Tennis TrainerTests/PracticeLifecycleTests/testPauseInvalidatesHeldPlaybackPublication'` | 0 | 1 | 0 | tennis-02-01-task2-red.xcresult |
| Task 2 final full target | `'-only-testing:Tennis TrainerTests' -parallel-testing-enabled NO` | 82 | 0 | 0 | tennis-02-01-task2-final.xcresult |

Focused selectors: `'-only-testing:Tennis TrainerTests/PracticeLifecycleTests' '-only-testing:Tennis TrainerTests/BallDetectionManagerTests'`. Each run also passed `-resultBundlePath /tmp/<basename>` and redirected its raw log to the matching `.log`. Exit codes were 65 for intentional RED and 0 for the successful runs. Required named classes executed; no required test was skipped.

Final counts: PracticeLifecycleTests 16, BallDetectionManagerTests 22, AnalysisAssociationTests 10, GridTrackNetDecoderTests 6, PoseDetectionManagerTests 4, ServeTossApexDetectorTests 23, existing Swift Testing scaffold 1. The inherited exact rational cooldown, strict fallback above 0.70, frame/pose association, owned-window/tensor tests and eight-buffer bound all pass. `git diff --check` passes.

The first parallel full-target attempt (`tennis-02-01-task2-green`) passed all sixteen lifecycle cases, then Xcode failed to launch its second simulator clone. That owned test process was interrupted; its partial result is not counted as a passing regression. The full target was rerun serially and passed all 82. The pre-existing controlled-semaphore Thread Performance Checker warning remains recorded as WINDOWS entry 1; it is not production timing evidence.

## Race Schedules and Positive Recovery

- Acquired camera race: enter production receive, capture the old generation, Stop/Start and drain the new clearing lease inside the acquisition hook, then resume the old offer. No job or pose is admitted; a subsequent fresh nine-frame toss cues.
- Queued camera race: enqueue an old callback ahead of the callback-queue drain sentinel, request Stop/Start, execute session stop/detach, deliver the old queued callback while ingress is closed, then finish drain/start. Only fresh frames build the new window.
- Hold worker and hold publication independently after four frames, then Stop/Pause/context exit. Old ball/pose/track/frame/cue effects are suppressed, capacity releases exactly once, four new frames remain warmup and a fifth fresh frame permits prediction. A subsequent valid fresh toss cues even at timestamps within the retired cooldown.
- Playback acquisition race: hold the copied frame across Pause and a new Play; resume acquisition with its old run/source/generation. Reject it without admission and retain the subsequent frames' copied display times rather than requested time.
- Both mode directions publish a valid current pose/ball before releasing the retired mode's empty clear. Current values survive; a same-mode reset clears its own presentation.
- Scene suspension exercises both adapters and both held stages. Active return stays stopped/paused; explicit fresh Start/Play recovers. Track publication reentrantly calls the public Stop/Pause methods and prevents the rest of the old cue/frame effect batch. One hundred repeated Plays retain one loop, and repeated Pause retires it once.

## TDD Gate Compliance

Both tasks have intentional assertion RED followed by GREEN commits. Initial RED characterization used the inherited lower-level admission seam to place a held job; final tests were expanded to injected AV effects, public controls and the production ingress path. No final lifecycle test depends on the old test-only Start/Stop early return. The real BallDetectionManager, frame preparation, decoder and cue detector run in these tests.

`check tdd-red-evidence` returned `RED_EVIDENCE_OK` for `/tmp/tennis-02-01-task1-red.json` and `/tmp/tennis-02-01-task2-red.json`. Each record explicitly normalizes the named XCTest assertion failure to TAP for the runtime checker and retains the raw log/xcresult. Task 1 observed non-nil ball and one frame after Stop; Task 2 observed nonempty pose and one frame after Pause. No syntax, discovery or fixture crash was used as RED. Refactoring did not need a separate commit.

## Deviations from Plan

**[Rule 3 - Blocking] Serial full-target verification after parallel simulator launch failure.** Xcode's second parallel clone failed to launch the app. Interrupted only that owned test process and reran the same complete target with `-parallel-testing-enabled NO`; all 82 passed. No source workaround or test exclusion was used. Recorded the project-specific recovery in LEARNINGS.md as part of `16d088d`.

No implementation scope expansion. `apply_patch` was used for file creation because this runtime exposes no separate Write tool.

## Known Stubs

- `Tennis Trainer/ContentView.swift:209`: Inherited Request Permission action is empty; scheduled for plan 02-02. Recorded as WINDOWS entry 2. This does not block this plan's injected control/analysis contract; camera permission recovery is explicitly the next plan's scope.

No new placeholders, skipped tests, unrun final automated verifies, network endpoints, external file access or new schema/auth boundaries were introduced.

## Next Phase Readiness and Pending Evidence

Ready for 02-02 camera authorization/actual-state expansion. Preserve the operation/drain and expected-generation boundaries; do not replace them with Boolean reopening. Next plan should close WINDOWS entry 2 when it wires the permission action. Seek/end/replay and transactional replacement/owned-file cleanup remain 02-03/02-04.

LIFE-01/LIFE-02 are shared with the unfinished sibling plans, so their project requirement checkboxes must remain pending. This summary's required frontmatter copies the plan IDs; it does not declare whole-phase acceptance.

End-of-phase review still owes visible Stop/Pause/mode-return overlay clearing, physical camera permission/Settings/start/interruption behavior, and physical audio evidence. EDGE-LIFE-01 and EDGE-LIFE-02 remain unclassified/unresolved in 02-COVERAGE.md; these tests do not resolve the undefined rows. No deterministic callback result is a physical sound-onset, live cue accuracy or clip/device-performance claim. No external setup was needed for these tests.

## Self-Check: PASSED

Created test and summary files exist; all four task commits resolve; final automated verification and required class counts pass; no task-file changes remain uncommitted and no tracked deletion occurred.
