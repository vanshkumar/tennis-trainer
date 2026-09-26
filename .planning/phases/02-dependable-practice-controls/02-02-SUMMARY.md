---
phase: 02-dependable-practice-controls
plan: "02"
subsystem: camera
tags: [swift, avfoundation, permissions, lifecycle, swiftui, xctest]
requires:
  - phase: 02-01
    provides: Synchronous analysis invalidation and drained capture restart with acquired-frame generation checks
provides:
  - Actionable camera permission and Settings recovery without implicit capture intent
  - Actual capture state, current-operation session events, bounded recovery and explicit Retry
  - Rendered permission, startup, recovery, Stop and Retry regressions with DEBUG injected effects
affects: [02-03, 02-04, phase-4-device-validation]
tech-stack:
  added: []
  patterns: [operation-owned observers, backend reconciliation after state delivery, one automatic recovery per explicit intent]
key-files:
  created: [Tennis TrainerTests/CameraManagerTests.swift]
  modified:
    - Tennis Trainer/CameraManager.swift
    - Tennis Trainer/ContentView.swift
    - Tennis Trainer/AppRuntime.swift
    - Tennis TrainerTests/PracticeLifecycleTests.swift
    - Tennis TrainerUITests/Tennis_TrainerUITests.swift
    - LEARNINGS.md
key-decisions:
  - Permission request identity and capture operation identity remain separate; current OS authorization and explicit intent govern opening.
  - Session events retain originating operation ownership and inspect actual backend state after state-executor delivery.
  - Failed capture retires requested intent into Retry; automatic recovery is limited to one per explicit Start.
requirements-completed: [CAM-01, CAM-02, LIFE-01, LIFE-02]
coverage:
  - id: D1
    description: Permission request coalescing, denied Settings, restriction explanation and current authorization return
    requirement: CAM-01
    verification:
      - kind: unit
        ref: Tennis TrainerTests/CameraManagerTests.swift#testCallbackBooleanCannotOverrideRevocationBeforeStateDelivery
        status: pass
      - kind: automated_ui
        ref: Tennis TrainerUITests/Tennis_TrainerUITests.swift#testCameraPermissionControls
        status: pass
    human_judgment: false
  - id: D2
    description: Current operation and backend state govern capture status, Stop dominance, failure and bounded recovery
    requirement: CAM-02
    verification:
      - kind: unit
        ref: Tennis TrainerTests/CameraManagerTests.swift#testStopDuringConfigurationStartAndPublicationWinsAndFreshRetryWorks
        status: pass
      - kind: unit
        ref: Tennis TrainerTests/CameraManagerTests.swift#testStopDuringRecoveryAndOldEventsCannotOverrideNewSession
        status: pass
      - kind: automated_ui
        ref: Tennis TrainerUITests/Tennis_TrainerUITests.swift#testCameraStopDuringStartupAndRecovery
        status: pass
    human_judgment: false
  - id: D3
    description: Interruption rejects held analysis/publication and recovery requires fresh evidence before a cue
    requirement: LIFE-02
    verification:
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testInterruptionInvalidatesHeldWorkAndRecoveryRequiresFreshTossWindow
        status: pass
    human_judgment: false
  - id: D4
    description: Physical permission, Settings return, startup, interruption, Stop and recovery acceptance
    requirement: CAM-02
    human_judgment: true
    rationale: User explicitly deferred physical-device checks until end of Phase 2; no device behavior is inferred from injection.
actuals:
  tokens: 13542
  tasks: 2
  commits: 6
commits: 6
plan_head_before: e379a60dc371555a52590802b436685cc73e470e
measurement_head: e26cf384377c448c0b1d483f43d8b49da1a60e4e
duration: 36min
completed: 2026-09-26
status: complete
---

# Phase 2 Plan 2: Camera Permission and Capture Recovery Summary

**Camera access actions and actual capture state now honor current user intent through delayed authorization, startup, interruption and bounded recovery, with explicit Retry after failure.**

## Performance and Task Commits

Two implementation tasks completed across the permission tracer and its authorized continuation. Wall-clock span from Task 1 RED commit at 15:07Z to closeout around 15:43Z is 36 minutes, including the human checkpoint interval. Task 2 resumed around 15:27Z. Seven scoped source/test/learnings files changed across both tasks. Actuals are 54,168 realized diff characters / 4 = 13,542 tokens, not model usage.

Persisted `.git/gsd-plan-head-before-02-02` was preserved. `git rev-list --count` from that base through `measurement_head` returned 6: four task commits plus the checkpoint and parent timing/plan-metadata commit. Metadata closeout commits are outside this measurement.

1. `3d0e6ec` — Task 1 RED: reject camera starts without permission.
2. `3b30ce3` — Task 1 GREEN: wire camera permission recovery controls.
3. `92f5632` — Record permission tracer checkpoint.
4. `9bc340b` — Parent records user checkpoint timing and repairs plan key-link paths; no task behavior changed.
5. `61b90e8` — Task 2 RED: expose failed startup blocking explicit retry.
6. `e26cf38` — Task 2 GREEN: reconcile capture state and bound camera recovery.

Root-pin and protected-branch checks ran before task commits. Project config explicitly allows sequential main commits. Hooks ran normally; no tracked file deletions. Parent-owned `.gsd/` and `.planning/milestone.lock` remain untouched.

## Accomplishments and Interfaces

- `CameraManager.AccessState` exposes undetermined/requesting/authorized/denied/restricted/unavailable. `hasPermission` derives from it. `requestAccess()` coalesces request identity and requeries the OS after callback delivery; the callback Boolean cannot override current authorization. `openSettings()` uses the system Settings URL only for denied access. `refreshAuthorization()` and active-context return requery access. Permission-only grant creates no capture intent. Denial, restriction, unknown status and a reset to undetermined retire an existing session; an explicit pending permission request may continue only under current intent.
- `CaptureState` exposes stopped, configuring, starting, running, interrupted, recovering and failed(message), with `message` and `canRetry`. `isRecording` derives from confirmed running state plus requested capture, authorization and active context. `captureRequested` controls Stop even while configuring/starting/recovering. Failure clears intent and exposes Retry, which invokes a new explicit Start.
- Dependencies retain session/drain/state executors and start/stop/attach effects; add throwing `configure`, optional `snapshot: () -> SessionSnapshot` and optional `observe: (SessionEvent callback) -> removal closure`. Production supplies actual AV session getters; older no-notification fixtures can retain start-result fallback. `SessionSnapshot` reports running/interrupted. `SessionEvent` covers started/stopped/interrupted/interruptionEnded/runtimeError(recoverable:).
- Production configuration runs once after successful completion on the serial session queue, balances begin/commit with defer, and throws for missing camera, unusable input or unusable output. Output failure removes the partially added input. The high preset, BGRA/discard-late output and optional 120 FPS format policy remain unchanged. Delegate attachment occurs after successful configuration.
- Session notification registration is scoped to the actual capture session and captured operation, uses weak manager captures, and returns owned removable tokens. Every event checks operation and current authorization/context after delivery, then reads backend state. Historical notification names cannot overwrite a fresh backend or reopen capture. Stop/new Start retire old observers; owner exit removes observers, invalidates analysis and schedules real session/delegate teardown.
- Startup preserves stop/detach → callback-queue drain → configure/attach/start → current state completion. A start retired while the blocking AV call was running is physically stopped immediately on the session queue. Only current actual successful startup opens ingress. Interruption closes ingress and resets tracking immediately; its end or supported media-services reset may recover once per explicit Start. Additional recovery failure requires Retry. Old events never create intent.
- ContentView renders the actual status and Request Permission, Open Settings, restriction explanation, Start, Stop and Retry. Existing identifiers remain stable: `practice.mode`, `camera.permissionStatus`, `camera.permissionAction`, `camera.captureStatus`, `camera.captureAction`.
- `AppRuntime` DEBUG scenarios are permission-undetermined, permission-denied-return, permission-restricted, capture-startup, capture-recovery and capture-failure. Effects are injected before AV/Core ML/audio defaults. Scenarios drive production transitions and real SwiftUI buttons; Release excludes their parser/effects. Startup and recovery hold state completion; the UI tests Stop, wait beyond late delivery, then successfully Start again. Manual Test Beep is unchanged.

## Verification

Xcode 27.0; iPhone 17 Pro simulator, iOS 26.5 (23F77), UDID 75781558-668B-412B-A9BD-5DBB1CE13CF4. Deployment target remains iOS 18.5. All tests use `-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled NO` plus `-resultBundlePath /tmp/<name>.xcresult`; raw logs use the same basename with `.log`. Test results were read through `xcrun xcresulttool get test-results summary` with required simulator/result access escalation.

| Result basename under /tmp | Scheme and selector | Pass | Fail | Skip |
|---|---|---:|---:|---:|
| tennis-02-02-task1-red | Tennis Trainer / CameraManagerTests | 0 | 1 | 0 |
| tennis-02-02-task1-green | Tennis Trainer / CameraManagerTests + PracticeLifecycleTests | 26 | 0 | 0 |
| tennis-02-02-permission-ui | Tennis Trainer UI Tests / testCameraPermissionControls | 1 | 0 | 0 |
| tennis-02-02-task1-full | Tennis Trainer / Tennis TrainerTests | 92 | 0 | 0 |
| tennis-02-02-task2-red | Tennis Trainer / CameraManagerTests/testFailedStartRetiresIntentSoExplicitRetryCanStartAgain | 0 | 1 | 0 |
| tennis-02-02-task2-green | Tennis Trainer / CameraManagerTests + PracticeLifecycleTests | 36 | 0 | 0 |
| tennis-02-02-task2-full | Tennis Trainer / Tennis TrainerTests | 103 | 0 | 0 |
| tennis-02-02-task2-ui | Tennis Trainer UI Tests / both camera UI selectors | 2 | 0 | 0 |
| tennis-02-02-task2-final | Tennis Trainer / Tennis TrainerTests | 104 | 0 | 0 |

Unit commands are `xcodebuild test -scheme 'Tennis Trainer'` with `'-only-testing:Tennis TrainerTests'` or named class/method suffix. UI commands use `-scheme 'Tennis Trainer UI Tests'` and full selectors `'-only-testing:Tennis TrainerUITests/Tennis_TrainerUITests/testCameraPermissionControls'` and `'-only-testing:Tennis TrainerUITests/Tennis_TrainerUITests/testCameraStopDuringStartupAndRecovery'`.

Final full counts: CameraManagerTests 21, PracticeLifecycleTests 17, BallDetectionManagerTests 22, AnalysisAssociationTests 10, GridTrackNetDecoderTests 6, PoseDetectionManagerTests 4, ServeTossApexDetectorTests 23, Swift Testing scaffold 1. Both required classes executed. The final unit run added the authorization-reset-to-undetermined regression after the UI run; the rendered UI paths are unchanged. All commands exit 0 except intentional REDs (65).

`xcodebuild build -scheme 'Tennis Trainer' -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO` passed for both tasks; final log `/tmp/tennis-02-02-task2-release.log`. `git diff --check` passed. Camera and microphone descriptions remain in generated Info.plist build settings. No target/bundle/model/geometry/cue-policy changes.

Acceptance evidence includes held configure/start/publication Stop, stale/current notifications, backend changes and revocation after dispatch, configuration failures and idempotence, observer removal and weak ownership, bounded recovery and fresh Retry. Interruption lifecycle tests hold worker and publication separately, reject old effects, then prove four fresh frames remain warmup and a fresh synthetic toss cues. Existing ingress/drain, pose ownership, eight-buffer, tensor/association and strict fallback/cooldown regressions remain green.

## TDD Gate Compliance

Both tasks have intentional assertion RED before their own GREEN. `/tmp/tennis-02-02-task1-red.json` and `/tmp/tennis-02-02-task2-red.json` each pass `check tdd-red-evidence` with `RED_EVIDENCE_OK`. Records normalize the named XCTest assertions to TAP and retain raw logs/xcresults. Task 1 observed unauthorized backend startup. Task 2 observed requested intent remaining true, only one start attempt and false recording after a fresh Start. No build, discovery or fixture error was counted as RED. No separate refactor commit was needed.

## Deviations from Plan

The user explicitly answered Yes to continuing all remaining Phase 2 implementation with physical-device checks deferred until the end. This changes timing only; global auto flags remain false. The earlier tracer stop and exact disposition remain in `02-02-CHECKPOINT.md`.

Task 2 extended AppRuntime (already in plan-level files) for its required startup/recovery/failure scenarios, and extended PracticeLifecycleTests for required interruption-to-fresh-cue proof. Its older failed-start assertion changed from keeping Stop intent to requiring retired intent plus Retry; the closed-ingress assertion remains. These are direct acceptance coverage, not unrelated scope expansion. `apply_patch` created files because no separate Write tool is exposed. No package installation or architecture deviation.

## Known Stubs and Issues

No goal-blocking stubs, skipped automated tests or unrun automated verifies remain. Optional empty injected effects are intentional test seams; production supplies framework effects. The prior empty permission action is fixed (WINDOWS entry 2). The pre-existing controlled-semaphore test QoS warning remains WINDOWS entry 1; no production timing claim follows from it. No new uncovered network, external-file, schema or authentication surface was introduced; T-02-05 through T-02-08 are covered by the permission, ownership, recovery and DEBUG boundaries.

## Pending Hardware and Next Plan

Ready for 02-03 seek/end/replay. Preserve camera operation/drain/admission and mode-owned presentation contracts while extending ContentView and AppRuntime. LIFE-01/LIFE-02 remain shared with unfinished playback/import plans.

Physical permission request, deny → Settings → grant → return, revoke → return, available restriction, startup/Stop, interruption and return/retry remain **pending**. Both human-check obligations are appended as unrun-verify entries in WINDOWS.md. Record device/OS/build and unsupported setups; injection is not device evidence. Six unknown edge dispositions, including EDGE-CAM-02, and the Phase 2 evidence-limit review remain pending. No physical audio timing, clip accuracy, sustained performance or whole-phase acceptance is claimed.

## Self-Check: PASSED

Created CameraManagerTests and this SUMMARY exist. All four task commits and both intervening metadata commits resolve; final 104-unit/2-UI results and Release build passed; no implementation changes remain uncommitted and no tracked deletion occurred.
