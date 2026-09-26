---
phase: 02-dependable-practice-controls
plan: "02"
status: implementation-complete-hardware-pending
completed_tasks: 2
total_tasks: 2
resume_task: none
updated: 2026-09-26
---

# Camera permission tracer checkpoint

## User disposition — 2026-09-26

The user answered **Yes** to continuing Phase 2 implementation while deferring the remaining physical-device checks to the end of the phase. Resume Task 2, then execute plans 02-03 and 02-04. This explicitly changes checkpoint timing only: hardware results, six unresolved edge dispositions and the evidence-limit review remain pending. Do not change global auto-advance preferences or record a human test pass.

Both implementation tasks are now committed and their automated checks pass. Task 2 RED is `61b90e8`, GREEN is `e26cf38`; final evidence and interfaces are in `02-02-SUMMARY.md`. This checkpoint preserves the original timing decision and pending hardware procedure. Plan 02-03 can proceed; no hardware pass is recorded.

## Commits and execution evidence

- `3d0e6ec` — Task 1 RED: Start invoked the capture backend once and reported recording while permission was false. Named XCTest assertion failure; no build/discovery error.
- `3b30ce3` — Task 1 GREEN: authorization state, request ownership, Settings/return, real rendered controls and DEBUG effect injection; LEARNINGS updated and WINDOWS entry 2 fixed.
- RED evidence: `/tmp/tennis-02-02-task1-red.json`, `RED_EVIDENCE_OK`. The characterization test now injects denied authorization explicitly through the new seam; it preserves the same unauthorized-start assertion.
- Plan ledger: `.git/gsd-plan-head-before-02-02` remains the authoritative base for final measured actuals. Do not overwrite it on continuation.

All test commands use `-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled NO`. Xcode 27.0; simulator iOS build 23F77, UDID 75781558-668B-412B-A9BD-5DBB1CE13CF4. Each result has a matching `.log` under `/tmp`.

| Result bundle | Command selectors/scheme | Passed | Failed | Skipped |
|---|---|---:|---:|---:|
| tennis-02-02-task1-red.xcresult | Tennis Trainer / CameraManagerTests | 0 | 1 | 0 |
| tennis-02-02-task1-green.xcresult | Tennis Trainer / CameraManagerTests + PracticeLifecycleTests | 26 | 0 | 0 |
| tennis-02-02-permission-ui.xcresult | Tennis Trainer UI Tests / Tennis_TrainerUITests/testCameraPermissionControls | 1 | 0 | 0 |
| tennis-02-02-task1-full.xcresult | Tennis Trainer / Tennis TrainerTests | 92 | 0 | 0 |

Focused classes executed 10 camera tests and all 16 lifecycle tests. Full target includes 91 XCTest cases plus the Swift Testing scaffold. Counts and zero skips were read with `xcrun xcresulttool get test-results summary`. Result-tool access initially needed sandbox escalation; the escalated reads succeeded. No test or build repair was required. The pre-existing controlled-semaphore priority warning remains WINDOWS entry 1; no production timing inference.

`xcodebuild build -scheme 'Tennis Trainer' -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO` passed (`/tmp/tennis-02-02-release.log`). `git diff --check` passed. Usage descriptions, target identity, model/geometry and cue contracts remain unchanged. Root-pin/protected-branch checks ran before both commits; config permits sequential main commits. No hooks bypassed or tracked files deleted.

## Implemented interfaces and behavior

- `CameraManager.AccessState`: undetermined, requesting, authorized, denied, restricted, unavailable. `hasPermission` derives from it. Unknown OS status fails closed.
- Dependencies add `authorization`, `requestAuthorization`, `openSettings`. Injected dependencies default to authorized for existing analysis fixtures; production explicitly supplies AVCaptureDevice queries/request and UIApplication's system Settings URL. Normal test construction still substitutes AV effects while executing production transitions.
- `requestAccess()` coalesces an outstanding request using request identity. Callback Boolean is not authority: after state dispatch, only a current request may requery OS status. Duplicate old callbacks cannot clear a newer request.
- `refreshAuthorization()` and `setContextActive(true)` requery current authorization. Permission-only grant and Settings return leave capture idle. A still-active explicit Start awaiting permission may continue; Stop/context exit clears that waiting intent immediately. Revocation uses the existing synchronous analysis reset and ingress close.
- Session-start and publication boundaries query authorization again. Camera configuration moves into the first authorized production Start, under the existing session queue. The full actual-state, configuration-error and notification implementation remains Task 2.
- `AppRuntime.practiceUIScenario` recognizes explicit DEBUG scenarios `permission-undetermined`, `permission-denied-return`, `permission-restricted`; Release returns nil. `makeCameraManager()` constructs injected effects before AV defaults. The existing test-runtime suppression also applies to these explicit scenarios, preventing model/audio defaults; fake preview avoids real capture setup. The scripted Settings opener drives real `setContextActive` transitions and authorization queries.
- ContentView renders Request Permission/disabled Requesting access…, Open Settings, restricted explanation, and authorized Start/Stop. Identifiers: `practice.mode`, `camera.permissionStatus`, `camera.permissionAction`, `camera.captureStatus`, `camera.captureAction`. UI tests tap actual buttons; fake effects do not replace state logic.

## Acceptance and remaining work

Task 1's automated acceptance passes: undetermined/denied/restricted, Settings return grant/revocation, exact request/open/start counts, delayed grant through Stop/context exit, fresh Start, duplicate request/result ownership, and current OS snapshot at delivery. Existing acquired/queued frame, held analysis/publication and fresh-toss lifecycle tests remain green.

Task 2 is complete: explicit CaptureState and backend snapshots, balanced/idempotent configuration with errors, owned notification reconciliation and observer cleanup, bounded recovery and explicit Retry, obsolete physical-start cleanup, and startup/recovery Stop UI. Final unit suite: 104/104; camera UI selectors: 2/2 across six scenarios; Release build passed. All tests have zero skips. See the SUMMARY for exact commands and artifacts.

No new packages, network endpoints or media storage changes. New platform authorization and DEBUG injection boundaries are covered by T-02-05 and T-02-08; Task 2 owns T-02-06/07 completion. No new stubs or skipped tests were introduced. Physical capture/permission/audio claims are not established by injected tests.

## Original tracer gate and deferred physical procedure

Both `workflow.auto_advance` and `_auto_chain_active` are false. `human_verify_mode` is end-of-phase, but Task 1's tracer verify contains a genuine human-check. The canonical [tracer rule](/Users/vanshkumar/.codex/gsd-core/references/checkpoints.md) says the automated-only exception applies only when verify has no human-check; otherwise this tracer stops before expansion. Do not silently change auto flags or count synthetic Settings return as physical proof.

On a supported physical iPhone, record device, OS and build and observe:

1. Undetermined access: tap Request Permission, verify one OS prompt and grant. Return to an idle Start control; permission alone must not start capture.
2. Denied access: verify Open Settings; grant in system Settings and return. Confirm authorized idle state and explicit Start works.
3. Revoke access in Settings and return. Confirm denied state, stopped capture and Open Settings again.
4. If restriction testing is available, confirm the restriction explanation and no misleading request/Settings action. Record unavailable hardware or unsupported setup explicitly.

The user explicitly deferred these checks to end-of-phase, as recorded above. Physical startup, Stop, interruption and return/retry also remain pending. Record unsupported interruption/restriction scenarios explicitly. Six unknown edge rows and the evidence-limit review remain pending. This timing disposition is not human acceptance of any physical behavior.

## Self-check: PASSED

Both task commits resolve; the new CameraManagerTests file exists; automated results and class counts are recorded; all Task 1 implementation changes are committed. Parent-owned `.gsd/` and `.planning/milestone.lock` were left untouched.
