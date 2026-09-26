---
phase: 02-dependable-practice-controls
plan: "04"
subsystem: playback-import
tags: [swift, photosui, avfoundation, ownership, lifecycle, xctest]
requires:
  - phase: 02-03
    provides: Completion-owned seeking and immutable timeline event reconciliation
  - phase: 02-01
    provides: Synchronous analysis invalidation and mode-owned presentation
provides:
  - Request-scoped provider imports with unique owned copies and consumer leases
  - Current validated ready candidate commit preserving the prior paused selection
  - Explicit original-owner playback retirement with real AV and rendered recovery checks
affects: [phase-2-verification, phase-3-geometry, phase-4-device-validation]
tech-stack:
  added: []
  patterns: [ARC media leases, candidate commit transaction, original-owner teardown, current readiness reconciliation]
key-files:
  created:
    - Tennis Trainer/VideoImportManager.swift
    - Tennis TrainerTests/VideoImportManagerTests.swift
    - docs/references/practice-controls-validation.md
  modified:
    - Tennis Trainer/VideoPickerView.swift
    - Tennis Trainer/VideoPlayerManager.swift
    - Tennis Trainer/ContentView.swift
    - Tennis Trainer/AppRuntime.swift
    - Tennis TrainerTests/VideoPlayerManagerTests.swift
    - Tennis TrainerTests/PracticeLifecycleTests.swift
    - Tennis TrainerUITests/Tennis_TrainerUITests.swift
    - LEARNINGS.md
key-decisions:
  - Cancellation retires authority immediately; independently retained media leases survive until each actual consumer returns.
  - Candidate metadata and readiness must both validate before atomic selection commit; failure preserves the prior paused session.
  - Provider copying finishes inside its callback; sheet dismissal cancels only before selection, never a selected pending provider.
requirements-completed: [PLAY-03, PLAY-04, LIFE-01, LIFE-02]
coverage:
  - id: D1
    description: Current provider import, safe copy lifetime, unique ownership, cancellation and original preservation
    requirement: PLAY-03
    verification:
      - kind: unit
        ref: Tennis TrainerTests/VideoImportManagerTests.swift
        status: pass
      - kind: automated_ui
        ref: Tennis TrainerUITests/Tennis_TrainerUITests.swift#testVideoImportRecoveryControls
        status: pass
    human_judgment: false
  - id: D2
    description: Current valid metadata plus readiness commit, stale rejection, held-stage invalidation and fresh clip cue
    requirement: LIFE-02
    verification:
      - kind: unit
        ref: Tennis TrainerTests/VideoPlayerManagerTests.swift#testSupersededMetadataReadinessAndErrorsCannotAlterNewCandidate
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testReplacementIntentInvalidatesBothHeldStagesAndFreshClipCanCue
        status: pass
    human_judgment: false
  - id: D3
    description: One active loop and original-owner cleanup, deferred consumer release and real AV playback
    requirement: PLAY-04
    verification:
      - kind: unit
        ref: Tennis TrainerTests/VideoPlayerManagerTests.swift#testHundredReplacementCyclesBalanceOwnersAndReleaseAllCopies
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/VideoPlayerManagerTests.swift#testGeneratedMovieReadinessSeekEndReplayAndRetirement
        status: pass
      - kind: automated_ui
        ref: Tennis TrainerUITests/Tennis_TrainerUITests.swift#testVisibleOverlayClearOnStopAndPause
        status: pass
    human_judgment: false
  - id: D4
    description: Physical controls, representative media, six undefined edge dispositions and evidence-limit review
    human_judgment: true
    rationale: User deferred checks to phase end; injected control tests and a generated movie cannot establish physical camera, tennis accuracy or audible timing.
actuals:
  tokens: 20847
  tasks: 3
  commits: 6
commits: 6
plan_head_before: 58560f571ad3f983655a5d306adc9accf103816d
measurement_head: fd76ff6af762ec1eb2c19780cd607b41c5d4716f
duration: 24min
completed: 2026-09-26
status: complete
---

# Phase 2 Plan 4: Transactional Video Ownership Summary

**Selected videos are copied during provider lifetime, committed only as current valid ready candidates, and retained until every retired AV consumer releases its lease.**

## Performance and Task Commits

Three tasks, eleven implementation/test/learnings/validation files. Measured implementation interval from first RED commit at 2026-09-26T16:10:58Z to final code commit near 16:35Z is 24 minutes; initial context reading is outside that interval. Actuals are ceiling of 83,387 scoped realized-diff characters / 4 = 20,847, not harness tokens. Six commits are measured from the persisted `.git/gsd-plan-head-before-02-04` ledger through measurement_head; metadata closeout commits are outside this count.

1. `b2e02d0` — Task 1 RED: expose lost selection after replacement failure.
2. `55e0665` — Task 1 GREEN: import unique media with request-owned leases.
3. `3ca0c20` — Task 2 RED: expose superseded candidate metadata takeover.
4. `fc60037` — Task 2 GREEN: commit only validated current ready candidates.
5. `7016bdb` — Task 3 RED: expose premature file release during pending seek.
6. `fd76ff6` — Task 3 GREEN: retire owned playback resources and prove recovery.

Root-pin/protected-branch checks ran; project configuration permits the existing sequential main strategy. Normal hooks ran. No tracked file deletion. Parent-owned architecture/index/ramp-up edits and `.gsd/`/milestone.lock were not staged.

## Accomplishments and Ownership Interfaces

- `VideoImportManager.begin(request:completion:)`, `receiveSelection(request:provider:)`, `pickerDismissed(request:)` and `cancel()` own provider request/Progress identity. Empty selection and pre-selection dismissal cancel. Normal dismissal after selection preserves pending work. The callback copies synchronously before its temporary URL expires, then queues an owned outcome. Stale success releases its copy; stale failure cannot change current state.
- `MediaHandle.external(_:)` has no deletion authority. Only the importer creates an owned handle after copying to a UUID destination under `PracticeImports`; allowed media extension is independent of identity. `lease()` retains the same private ARC owner. Its final deinit removes its proven owned path once. Partial copy errors remove only their destination; an existing-destination error explicitly does not remove it. No arbitrary temp sweep or media/path/joint logging exists.
- `beginReplacement()` pauses and invalidates analysis/seek intent while retaining the committed selection. `acceptImport(_:request:)` accepts only the current UUID. `loadVideo(from: URL)` remains an externally owned compatibility entry. `cancelReplacement()` invalidates a current candidate without creating cancellation messages when nothing is pending.
- Candidate owns handle, metadata task, asset-related player/item and status observation. Metadata requires playable media, at least one video track and finite positive duration; orientation retains the existing transform conversion. Identity is checked after each suspension and state hop. Readiness notifications requery actual current item status after dispatch, and commit rechecks ready status. Only metadata plus readiness commits a candidate once, at zero paused with a fresh source. Failure preserves the prior paused session and displays an actionable message; first failure preserves the empty Choose state.
- `PlaybackSession.retire()` removes periodic tokens from their registering player, detaches output from its original item, disconnects layer/player references and releases media. Seek/request/timeline identity is invalidated before callbacks can run. Metadata, readiness, seek/time/event delivery and executing output-reader operations independently retain file leases. Cancellation never substitutes for completion. Mode/scene exit cancels candidates and retains at most the paused committed selection; owner disappearance calls shutdown.
- The existing weak display-link target and 02-03 load/timeline ownership remain. Native end/error callbacks retain their original registration identity and require fresh backend evidence; no old event is relabeled. `VideoPlayerView` geometry/layer handoff is unchanged.
- ContentView uses manager-committed state rather than a raw selected URL. Loading offers Cancel; failure/cancellation leaves Choose available and the previous Play actionable once settled. DEBUG import scenarios traverse the same importer/provider outcome boundary; seeded ball/pose publishers exercise real Stop/Pause clearing without a later frame-count tick.

## Verification

Exact commands, environment, final class inventory, ownership maxima, evidence limits and all pending reviews are in [practice-controls-validation.md](../../../docs/references/practice-controls-validation.md). Canonical repo-relative path is `docs/references/practice-controls-validation.md`.

Every test command uses iPhone 17 Pro/iOS 26.5 and `-parallel-testing-enabled NO`. Final full unit and UI runs add `-collect-test-diagnostics never` after the diagnostic-collection issue below. Required selectors were not removed or skipped.

| /tmp result basename | Scope | Pass | Fail | Skip |
|---|---|---:|---:|---:|
| tennis-0204-t1-red | Failed-replacement assertion | 0 | 1 | 0 |
| tennis-0204-t1-green | Import class | 5 | 0 | 0 |
| tennis-0204-tracer | Committed tracer feedback gate | 5 | 0 | 0 |
| tennis-0204-t2-red | Reentrant candidate assertion | 0 | 1 | 0 |
| tennis-0204-t2-final | Import/player/lifecycle classes | 51 | 0 | 0 |
| tennis-0204-t3-red | Pending seek file-lifetime assertion | 0 | 1 | 0 |
| tennis-0204-t3-focused | Import/player including generated AV movie | 31 | 0 | 0 |
| tennis-0204-full | Full unit target before last two regressions | 143 | 0 | 0 |
| tennis-0204-final | Full unit target including output-reader lease | 144 | 0 | 0 |
| tennis-0204-verified-final | Final full unit target | 145 | 0 | 0 |
| tennis-0204-ui-final | Both exact plan UI selectors | 2 | 0 | 0 |

Final unit counts: association 10, ball manager 22, camera manager 21, decoder 6, pose 4, lifecycle 23, apex 23, importer 9, player 26, Swift Testing scaffold 1. `xcresulttool get test-results summary` confirmed finalized 145/145 and 2/2 with zero skips. Exit 0 for all successful commands; intentional RED exit 65. Release build passed (`/tmp/tennis-0204-release-final.log`), `git diff --check` passed, camera/microphone descriptions remain configured.

The real integration generates a one-second 64×64 H.264 movie using AVAssetWriter, loads through the public external-input path, waits for real item readiness, seeks, receives native end, replays through the real zero-seek completion and checks detached output/layer plus preserved external file. Bounded XCTest expectations replace sleeps; no personal clips or downloads are used. It proves framework wiring, not tennis accuracy.

One hundred cycles prove maximum one active loop, one time observer and one timeline registration; removals are once per registered owner, delayed callbacks are inert, manager weak probes clear, and all 100 owned files disappear after callbacks drain. Actual filesystem tests preserve original and unknown legacy files. Held metadata and seek consumers and reentrant frame-reader retirement prove no early deletion. Replacement invalidates both held analysis stages and a fresh five-frame window subsequently cues.

## TDD Gate Compliance

Each task has its own intentional assertion RED before GREEN. `/tmp/tennis-0204-t1-red.json`, `t2-red.json` and `t3-red.json` all returned `RED_EVIDENCE_OK`. Records normalize named XCTest assertions into TAP for the GSD validator and retain raw log/xcresult references. No compile failure, fixture crash or discovery failure was used as RED. No separate refactor commit was needed. The committed tracer reran successfully before candidate expansion.

## Deviations and Issues

**[Rule 3 — Verification infrastructure] Diagnostic collection stalled after all tests completed.** `tennis-0204-verified` printed 145 passing tests, then waited in `XCTHRunDestinationAllocator.collectSimulatorDiagnostics` (stack sample `/tmp/tennis-0204-xcodebuild-sample.txt`). After about four minutes only the owned xcodebuild process was terminated, exit 143. Its incomplete result is not counted as success. The entire unchanged suite reran with supported `-collect-test-diagnostics never`; finalized 145/145. Final UI uses the same flag. No selective retry or test suppression.

Task 3 necessarily extends AppRuntime for its explicitly planned DEBUG scenarios and strengthens the importer dismissal/collision coverage. These direct acceptance dependencies were authorized by the dispatch; no new product scope. New files use apply_patch because this runtime has no separate Write tool. No package installs or architecture decisions were needed.

No goal-blocking stubs, skipped required automated checks or unrun final automated verifies. Injected optional no-op effects and DEBUG synthetic provider bytes are intentional fixtures and excluded from real-media claims. The inherited controlled-semaphore QoS warning remains WINDOWS 1. All new file/async boundaries fall within T-02-12 through T-02-16; no additional network/auth/schema surface was introduced.

## Pending Acceptance and Handoff

All three implementation tasks are complete; Phase 2 is **awaiting independent review/verification/UAT**, not accepted. Requirement status is deliberately unchanged as instructed by Task 3; frontmatter copies the plan IDs and is not whole-phase human acceptance.

Physical permission/Settings/restriction, actual startup/Stop/interruption/retry and representative real-clip review remain WINDOWS 3–5. The generated movie does not close representative playback inspection. EDGE-LIFE-01, LIFE-02, CAM-02, PLAY-01, PLAY-02 and PLAY-03 retain unclassified/unresolved status. The descriptor-less transparency prohibition remains flagged/unverified until explicit human evidence-limit review; WINDOWS 6 records it together with the six dispositions. Physical audio, labeled corpus, frozen numeric criteria and sustained process-memory/device results remain Phase 4 obligations. User deferral changed timing only; global auto flags remain false.

## Self-Check: PASSED

All three created deliverables exist; all six task commits resolve; final required unit/UI commands and Release build passed with nonzero required counts and zero skips. All implementation changes were committed before this summary. No task-file deletion or uncovered threat surface was found.
