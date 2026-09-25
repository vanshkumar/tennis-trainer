---
phase: 01-consistent-toss-cues
plan: "01"
subsystem: inference
tags: [swift, avfoundation, vision, xctest, admission]
requires: []
provides:
  - Rational source-time ingress through camera and playback adapters
  - One job lease through value publication with zero pending input
  - Serialized same-image pose extraction and explicit missing pose
  - Pre-change source reference and versioned evidence protocol
affects: [01-02, 01-03, session-transitions, empirical-verification]
tech-stack:
  added: []
  patterns: [injected dependencies, coalesced reset, frame-tagged pose, held schedulers]
key-files:
  created:
    - Tennis TrainerTests/BallDetectionManagerTests.swift
    - Tennis TrainerTests/PoseDetectionManagerTests.swift
    - docs/references/toss-cue-validation.md
  modified:
    - Tennis Trainer/BallDetectionManager.swift
    - Tennis Trainer/CameraManager.swift
    - Tennis Trainer/VideoPlayerManager.swift
    - Tennis Trainer/PoseDetectionManager.swift
    - Tennis Trainer/Detectors/ColorKalmanBallDetector.swift
    - LEARNINGS.md
key-decisions:
  - Idle resets reserve one clearing publication; model storage clears on the next worker, coalescing repeated resets.
  - Recheck generation after each observable effect and track callback because subscribers can reset synchronously.
  - Preserve portrait-fit/nonportrait-fill, overlay index 4, and iOS 18.5.
requirements-completed: [CUE-01, CUE-02, CUE-04]
coverage:
  - id: D1
    description: Camera PTS and acquired playback time reach the automatic cue callback
    requirement: CUE-01
    verification:
      - kind: integration
        ref: Tennis TrainerTests/BallDetectionManagerTests.swift#testAutomaticCue_WhenCameraSampleHasSourcePTS
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/BallDetectionManagerTests.swift#testAutomaticCue_WhenPlaybackReturnsDifferentDisplayTime
        status: pass
    human_judgment: false
  - id: D2
    description: One lease through publication, no queued inputs, and generation-safe reset
    requirement: CUE-02
    verification:
      - kind: unit
        ref: Tennis TrainerTests/BallDetectionManagerTests.swift#testBoundedWork_WhenWorkerAndPublicationAreHeld
        status: pass
      - kind: unit
        ref: Tennis TrainerTests/BallDetectionManagerTests.swift#testCombinedBounds_WhenTwoManagersSharePose
        status: pass
    human_judgment: false
  - id: D3
    description: Same-image pose values, explicit absence, and serialized shared request
    requirement: CUE-04
    verification:
      - kind: unit
        ref: Tennis TrainerTests/PoseDetectionManagerTests.swift
        status: pass
    human_judgment: false
  - id: D4
    description: Reproducible baseline protocol with permitted-media and physical evidence pending
    verification:
      - kind: other
        ref: docs/references/toss-cue-validation.md
        status: pass
    human_judgment: false
actuals:
  tokens: 15701
  tasks: 2
  commits: 4
commits: 4
plan_head_before: 2a1da7e613b8bcb9268a9cdd767436e84b8c967c
measurement_head: 05ba037bf2ed5fec863e5d9e5b4c3c02da70e0fd
duration: 18min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 1: Consistent Toss Cues Summary

**Camera PTS and acquired player time now enter one admitted job through pose,
prediction, and generation-checked callback publication.**

## Performance

- Started: 2026-09-25T22:01:34Z
- Implementation completed: 2026-09-25T22:19:21Z
- Tasks: 2; implementation/documentation files: 9
- Actual tokens: ceiling of 62,802 realized diff characters / 4, measured at
  `05ba037` before close-out metadata. Four task/TDD commits measured using the
  persisted `.git/gsd-plan-head-before-01-01` ledger.

## Accomplishments

- Both real source adapters use original rational media time; playback checks for
  a new frame and copies once using returned display time. Stable source UUIDs,
  UUID generations, checked UInt64 sequences and rational time comparisons reject
  invalid/equal/regressing submissions before any worker or pose work.
- Admission retains one job through the final effect batch. Held worker and held
  publication bursts reject 1,000 offers at each stage without additional analysis
  or pose calls. Diagnostics contain scalar counters only and saturate.
- Shared Vision request perform-and-extract is serialized; missing, failed and
  low-confidence pose produces empty value joints. Pose UI publication, ball,
  track/cue processing and processed-frame notification share one completion.
- Reset immediately invalidates generation while the old job keeps capacity.
  Repeated idle resets occupy one clearing publication; repeated busy resets add
  no closure. Matching release prevents an old completion releasing a new lease.
- Validation protocol was written before production edits, including baseline
  commit verification, model hashes, settings, ownership/permission inventory,
  independent label and matching rules, denominators and separate clocks.

## Task Commits

1. Task 1 RED: `4128fbb` — define media ingress tracer expectations.
2. Task 1 GREEN: `bb75136` — carry source time through admitted cue work.
3. Task 2 RED: `0994fc8` — expose reset and held-publication failures.
4. Task 2 GREEN: `05ba037` — bound pose and publication under one lease.

No separate refactor commit was needed. Normal hooks ran; no tracked files were
deleted. Metadata commits follow these measured implementation commits.

## Final Interfaces

- `BallDetectionManager.Input(pixelBuffer:sourceTime:orientation:sourceID:)`
- `FrameIdentity(sourceID:generation:sequence:sourceTime:)`
- `Dependencies.analyze: (Input, FrameIdentity, FramePose) throws -> Analysis`
- `Dependencies.extractPose`, `publishPose`, `reset`, `worker`, `publication`
- `process(input:) -> Bool`, `resetTrackingState(sourceID: UUID? = nil)`
- `Diagnostics`: admitted/dropped/completed/released, current leases/publications,
  their high-water counts, and constant zero pending inputs.
- `CameraManager.submitSampleBuffer(_:)` is invoked by `captureOutput`.
- `VideoPlayerManager.FrameOutputReading` wraps new-frame detection and copy;
  `processCurrentFrame(output:requestedTime:orientation:)` is invoked by
  `processDisplayLinkFrame`, the explicitly named Objective-C selector.
- Both media `setupBallDetection(with:factory:)` methods support injection before
  test hardware suppression and forward `onApex` and `onFrameProcessed`.
- `PoseDetectionManager.FramePose` owns exact identity and value `Joint`s;
  `extractPose(in:orientation:identity:)` returns values, `publish(_:)` updates UI.
- `ColorKalmanBallDetector.process(pixelBuffer:shoulderX:)` consumes captured pose
  values. Its algorithm and exclusion from automatic serve cues remain unchanged.

## Verification

Simulator destination: iPhone 17 Pro / iOS 26.5, Xcode 27.0.

| Run | Executed | Passed | Failed | Skipped | Result bundle under `/private/tmp/` |
|---|---:|---:|---:|---:|---|
| Task 1 intentional RED | 3 | 0 | 3 | 0 | `tennis-01-01-task1-red3.xcresult` |
| Task 1 GREEN | 3 | 3 | 0 | 0 | `tennis-01-01-task1-green.xcresult` |
| Tracer feedback gate | 3 | 3 | 0 | 0 | `tennis-01-01-tracer-gate.xcresult` |
| Task 2 intentional RED | 7 | 5 | 2 | 0 | `tennis-01-01-task2-red.xcresult` |
| Final targeted suite | 19 | 19 | 0 | 0 | `tennis-01-01-task2-final.xcresult` |
| Full unit regression | 26 | 26 | 0 | 0 | `tennis-01-01-unit-regression.xcresult` |

Commands used `xcodebuild test -scheme 'Tennis Trainer' -destination
'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` with the plan's two named
`-only-testing` class selectors (Task 1 selects only BallDetectionManagerTests),
then `-only-testing:Tennis TrainerTests` for full regression. Logs accompany each
bundle with `.log` extension. Exact counts were read using `xcresulttool`.

The final targeted suite includes 15 manager and 4 pose tests: source adapter
tracers, factory suppression, held stages, two-manager aggregate bounds, idle and
busy reset, reentrant reset, matching lease release, invalid/rational time,
counter exhaustion, warmup/no-result/thrown-analysis cleanup, owner teardown,
same-image values, missing/error/low-confidence pose, and request serialization.
Backend failure cases inject their no-result/error boundary; actual Core ML
failure and tensor contracts are intentionally covered by later plans.

`ContentView` automatic callback → `AudioManager.playBeep` and manual Test Beep
wiring were inspected and unchanged. No sound was emitted in tests. Deployment
target, bundle identity and camera/microphone usage declarations remain unchanged.

## TDD Gate Compliance

Both task RED gates passed `check tdd-red-evidence`: Task 1 failed on missing
source times/callbacks; Task 2 failed on missing idle-reset publication and one
stale cue after callback-triggered reset. Records are
`/private/tmp/tennis-task1-red.json` and `tennis-task2-red.json`. The runtime gate
only parses TAP, so records explicitly identify their TAP projection from actual
XCTest results; original logs and xcresults remain the authority. Initial Task 1
selector compile failures were INVALID_RED and did not authorize implementation.

## Proven Bounds and Remaining Evidence

Per manager: one lease, zero pending inputs, at most one publication. Two managers:
two leases, zero pending inputs, at most two publications; shared pose transaction
maximum concurrency one. Publication closures retain value pose/analysis results,
not raw input or tensor payloads. Framework allocations and distinct pixel-buffer
counts are not established by these scheduling tests.

The source baseline is `1bae995d96650b2619faeebe568a36715f50db0d`; source/test/project
diff to pre-execution HEAD `2a1da7e` was empty. No permitted repository clip was
available and physical iPhone/audio setup is unknown. Accuracy, sampling
sufficiency, gap limits and physical sound latency remain pending Phase 4 evidence.
01-02 still owns immutable model windows and historical candidate-pose association;
01-03 still owns decoder/model smoke and complete buffer/history accounting. The
requirements list above reflects plan coverage, not final shared-ID completion.

## Deviations from Plan

- [Rule 3 — Blocking] Renamed the private Objective-C display-link entry point to
  `processDisplayLinkFrame` after Swift rejected an overloaded selector. The real
  callback still calls the planned testable adapter. Verified by builds/tracers.
- [Rule 2 — Project rules] Updated LEARNINGS.md with new selector and reentrant
  publication observations. The orchestrator set `git.allow_default_branch_commits`
  to match existing `branching_strategy: none`; the explicit guard returned false
  before commits. No branch or target migration occurred.

## Issues Encountered

CoreSimulator and xcresult cache access required sandbox escalation. Tests ran
after access was granted; permission errors were never counted as test passes.
Apple's living docs required JavaScript; the installed AVFoundation header was
used to verify returned display-time semantics and iOS compatibility. Existing
Xcode 27 deprecation warnings were not used to change the iOS 18.5 baseline.

## User Setup Required

None for deterministic execution. Permitted clips, physical device and synchronized
sound timing remain explicitly pending empirical verification inputs.

## Next Phase Readiness

Ready for 01-02 using the frame identity and pose value contracts. Source lifecycle
matrix remains Phase 2 scope. No production stub prevents this plan's goal;
default empty fake-pose dependencies are deliberate injection defaults, and the
production factory supplies the real extractor.

## Self-Check: PASSED

All three created files and all four task commits exist. Both named test classes
executed; targeted and full unit results passed with zero skipped tests.
