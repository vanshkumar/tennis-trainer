---
phase: 02-dependable-practice-controls
plan: "03"
subsystem: playback
tags: [swift, avfoundation, seeking, replay, lifecycle, xctest]
requires:
  - phase: 02-01
    provides: Synchronous analysis invalidation, captured admission generation and mode-owned presentation
  - phase: 02-02
    provides: DEBUG scenario factory and native control test harness
provides:
  - Latest-successful-seek gating with current play intent and explicit failed-seek retry
  - Captured playback timeline observations with fresh backend end/error reconciliation
  - Ended and Replay controls, fresh analysis/cooldown and one weakly owned extraction loop
affects: [02-04, phase-4-device-validation]
tech-stack:
  added: []
  patterns: [immutable event registration owner, event-driven backend reconciliation, completion-owned seek, weak display-link target]
key-files:
  created: [Tennis TrainerTests/VideoPlayerManagerTests.swift]
  modified:
    - Tennis Trainer/VideoPlayerManager.swift
    - Tennis Trainer/ContentView.swift
    - Tennis Trainer/AppRuntime.swift
    - Tennis TrainerTests/PracticeLifecycleTests.swift
    - Tennis TrainerUITests/Tennis_TrainerUITests.swift
    - LEARNINGS.md
key-decisions:
  - A matching event registration is only a reconciliation signal; current stopped-at-end or failed backend state is required after state delivery.
  - Failed seeks remain ineligible until an explicit Play retries and the current seek succeeds; paused successful seeks may update position without resuming.
  - Display ticks retain their originating frame run and use a weak target; explicit shutdown and control retirement remove loop and event owners.
requirements-completed: [PLAY-01, PLAY-02, LIFE-01, LIFE-02, PLAY-04]
coverage:
  - id: D1
    description: Latest successful seek, current intent, invalid-value rejection and retry through real controls
    requirement: PLAY-01
    verification:
      - kind: unit
        ref: Tennis TrainerTests/VideoPlayerManagerTests.swift#testOnlyLatestSuccessfulSeekMayResume_InEveryCompletionOrder
        status: pass
      - kind: automated_ui
        ref: Tennis TrainerUITests/Tennis_TrainerUITests.swift#testPlaybackSeekControls
        status: pass
    human_judgment: false
  - id: D2
    description: Old same-item end/error cannot retire newer seek/Replay, while fresh frames and cues continue and genuine current events still work
    requirement: LIFE-02
    verification:
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testSameItemHeldEndAndErrorCannotStopNewSeekOrReplayAndFreshCue
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/PracticeLifecycleTests.swift#testCurrentEndInvalidatesBothHeldStagesAndReplayResetsCooldown
        status: pass
      - kind: automated_ui
        ref: Tennis TrainerUITests/Tennis_TrainerUITests.swift#testPlaybackEndAndReplayControls
        status: pass
    human_judgment: false
  - id: D3
    description: One extraction loop and event owner with explicit retirement, stale tick rejection and weak manager lifetime
    requirement: PLAY-04
    verification:
      - kind: unit
        ref: Tennis TrainerTests/VideoPlayerManagerTests.swift#testRepeatedReplayAndPlayKeepSingleLoopAndOwner
        status: pass
      - kind: unit
        ref: Tennis TrainerTests/VideoPlayerManagerTests.swift#testObserverAndTickCallbacksDoNotRetainManagerAfterOwnerExit
        status: pass
    human_judgment: false
  - id: D4
    description: Real local-media end, repeated scrub, Pause during seek and Replay inspection
    requirement: PLAY-02
    human_judgment: true
    rationale: User deferred physical and real-media inspection to the end of Phase 2; scripted native controls are not real playback/device/audio evidence.
actuals:
  tokens: 12004
  tasks: 2
  commits: 4
commits: 4
plan_head_before: 80c5311645d1c3dcfae521bed63c0f552791caef
measurement_head: 636dbe25d7a513b420abfa7512301446d930dd1a
duration: 15min
completed: 2026-09-26
status: complete
---

# Phase 2 Plan 3: Completion-Owned Playback Summary

**Seeking waits for current success, and immutable playback-run ownership plus fresh backend reconciliation prevents delayed end/error callbacks from stopping a newer timeline or its fresh cue.**

## Performance and Task Commits

Two tasks; seven implementation/test/learnings files. Recorded implementation interval: first RED commit 2026-09-26T15:48:52Z through verified GREEN closeout around 16:03:47Z, 15 minutes; initial context reading is outside that interval. Actuals are ceiling of 48,015 scoped realized-diff characters / 4 = 12,004, not model usage. Four commits are measured from the persisted `.git/gsd-plan-head-before-02-03` ledger to measurement_head; metadata commits are outside that measurement.

1. `017997e` — Task 1 RED: expose frame ingress during an unsettled seek.
2. `d6b92a7` — Task 1 GREEN: gate playback on the latest successful seek.
3. `93f91b5` — Task 2 RED: expose missing playback end invalidation.
4. `636dbe2` — Task 2 GREEN: reconcile owned playback timelines and replay.

Root-pin and protected-branch checks ran before commits. Project configuration expressly allows the existing sequential main strategy. Hooks ran normally; no tracked deletion occurred. Parent-owned `.gsd/` and `.planning/milestone.lock` were left alone.

## Accomplishments and Interfaces

- `PlaybackState` exposes empty, paused, seeking, playing, ended and failed(message); `playRequested` is distinct from actual extraction/isPlaying. Load identity, latest seek identity, timeline identity, frame-run identity and analysis generation have separate lifetimes. Each replacement advances load identity; production snapshots additionally require the actual current AVPlayerItem.
- `seek(to:)` validates finite positive duration and finite target, clamps to the loaded range, rejects CMTime overflow, replaces seek identity before cancellation can synchronously complete old requests, closes ingress/resets analysis before AV pause, cancels pending seeks, then issues a completion-handler seek with zero tolerances. State-executor acceptance requires matching load/request and success plus a valid current backend position. Duplicates and superseded results do nothing. Pause/context exit preserve closure. Play during a seek records intent only. A failed seek retains its target and requires a successful explicit retry before reopening.
- `replay()` requests play and seeks exactly zero through the same completion gate; `resetToBeginning()` uses that seek machinery while preserving current intent. Analysis generation reset supplies fresh five-frame warmup and fresh cooldown, without a second timer. End/error closes ingress and invalidates pending effects before presenting terminal state.
- `ItemEvent` and `PlaybackSnapshot(position:stopped:failed:)` are effect values. `armTimeline()` installs item-filtered end/failed-to-end notifications and item/player status observations. Each callback weakly captures the manager and immutable load/timeline registration identity before dispatch. A matching native event is only a reconciliation signal: after delivery, current stopped-at-finite-end evidence or current player/item failed status is required; historical payloads cannot authorize failure. Reconciliation runs once on arming and rechecks identity after reading effects. Seek, Replay, Pause/context exit, replacement, shutdown and deinit retire observations.
- Dependencies retain play/pause/startLoop/stopLoop and add synchronous injected load metadata, seek/cancel/current-time/state delivery, tick/time/event registration, output reader and backend snapshot seams. Injected callbacks exercise production transitions. Production metadata remains the existing asynchronous loader with a minimal load-ID guard; transactional candidate readiness and owned file cleanup are intentionally 02-04.
- The real CADisplayLink targets an NSObject with a weak manager reference and immutable frame run. Extraction starts idempotently, invalidates/nils on stop, and rejects retired tick identities. The existing copied display time and expected analysis generation remain authoritative around acquisition. Delayed periodic time callbacks read current owned backend position after load/seek guards instead of publishing their historical payload. `shutdown()` explicitly retires the session.
- ContentView renders Seeking…, Ended/Replay and actionable failure text. Requested intent keeps Pause available while a seek waits. Identifiers are `playback.action`, `playback.status`, `playback.slider` and `playback.position`. DEBUG `playback-seek` / `playback-end` factories drive real SwiftUI controls with scripted effects; Release excludes scenario parsing/effects. Clip audio stays muted; manual Test Beep, player-layer geometry, model/preprocessing and cue policy are unchanged.

## Verification

Xcode 27.0; iPhone 17 Pro simulator, iOS 26.5 (23F77), UDID 75781558-668B-412B-A9BD-5DBB1CE13CF4. Deployment remains iOS 18.5. All test commands use `-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled NO` and `-resultBundlePath /tmp/<basename>.xcresult`; raw logs share each basename with `.log`.

| Basename under /tmp | Scheme / selectors | Pass | Fail | Skip |
|---|---|---:|---:|---:|
| tennis-02-03-task1-red | Tennis Trainer / PracticeLifecycleTests/testSeekImmediatelyClosesProductionFrameIngress | 0 | 1 | 0 |
| tennis-02-03-task1-final | Tennis Trainer / VideoPlayerManagerTests + PracticeLifecycleTests | 28 | 0 | 0 |
| tennis-02-03-task1-ui | Tennis Trainer UI Tests / testPlaybackSeekControls | 1 | 0 | 0 |
| tennis-02-03-tracer-unit | Tennis Trainer / VideoPlayerManagerTests + PracticeLifecycleTests | 28 | 0 | 0 |
| tennis-02-03-tracer-ui | Tennis Trainer UI Tests / testPlaybackSeekControls | 1 | 0 | 0 |
| tennis-02-03-task2-red | Tennis Trainer / VideoPlayerManagerTests/testCurrentEndClosesPlayIntentAndExtraction | 0 | 1 | 0 |
| tennis-02-03-task2-green | Tennis Trainer / VideoPlayerManagerTests + PracticeLifecycleTests | 36 | 0 | 0 |
| tennis-02-03-task2-full | Tennis Trainer / Tennis TrainerTests | 124 | 0 | 0 |
| tennis-02-03-task2-ui | Tennis Trainer UI Tests / both playback and both prior camera methods | 4 | 0 | 0 |
| tennis-02-03-final | Tennis Trainer / Tennis TrainerTests | 125 | 0 | 0 |

Base unit command is `xcodebuild test -scheme 'Tennis Trainer'`; class selectors are `'-only-testing:Tennis TrainerTests/VideoPlayerManagerTests' '-only-testing:Tennis TrainerTests/PracticeLifecycleTests'`, and full target selector is `'-only-testing:Tennis TrainerTests'`. UI base is `xcodebuild test -scheme 'Tennis Trainer UI Tests'`; full selectors use `'-only-testing:Tennis TrainerUITests/Tennis_TrainerUITests/<method>'` for `testPlaybackSeekControls`, `testPlaybackEndAndReplayControls`, `testCameraPermissionControls`, and `testCameraStopDuringStartupAndRecovery`. Successful commands exited 0; intentional REDs exited 65. Required selected classes/methods executed. xcresult summaries confirm final 125/125 and 4/4, zero skips.

Final class counts: AnalysisAssociationTests 10, BallDetectionManagerTests 22, CameraManagerTests 21, GridTrackNetDecoderTests 6, PoseDetectionManagerTests 4, PracticeLifecycleTests 22, ServeTossApexDetectorTests 23, VideoPlayerManagerTests 16, Swift Testing scaffold 1. Inherited exact rational cooldown, strict fallback above 0.70, frame/pose association, owned-window/tensor and buffer-bound tests remain green.

`xcodebuild build -scheme 'Tennis Trainer' -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO` passed (`/tmp/tennis-02-03-release.log`). The final subsequent source change only clears isLoading in shared teardown; the final full Debug target compiled and tested it. `git diff --check` passes. No signing, identifiers, targets, usage descriptions or generated models changed.

Task 1's first GREEN attempt (`tennis-02-03-task1-green`) encountered an unowned test-fixture teardown crash after all 19 lifecycle tests passed. This was not RED evidence or a successful regression. The fake now uses weak effect captures, and subsequent focused, tracer and full runs pass. The inherited controlled-semaphore QoS warning remains WINDOWS entry 1; it is not production timing evidence.

## Race Schedules and Positive Recovery

- Seek A/B exercises old true/false before and after current success; duplicate current failure is ignored. Pause/context exit, Play while pending, failed retry, nonfinite/overflow values, invalid backend position, post-dispatch ownership and old-item time/seek callbacks are covered.
- Seek and end independently hold the real pipeline worker and publication stages. After invalidation old pose/ball/track/frame/cue effects stay suppressed. Four fresh frames remain warmup, followed by a new eligible synthetic toss using real preparation, decoder and cue detector.
- Both end and error callbacks are captured and held before state acceptance. On the unchanged item, a newer successful seek and, separately, Ended→Replay-to-zero establish new owners. Releasing the old event preserves requested play, exact position, status and the same active-loop counts. An ambiguous event delivered to the new registration against a healthy backend also cannot stop it. Retired ticks admit no frames; nine fresh current ticks advance frames and cue again inside the old cooldown, using exact rational timestamps starting at 0.033 seconds for Replay or 2.033 seconds after seek. Subsequent genuine current end/error closes the run and presents the appropriate state.
- A replaced item's retained tick cannot enter the new source; the new item still advances nine frames and cues. Repeated 100 Play requests, 20 seek cycles and 50 Replay cycles keep maximum active loop and event-owner counts at one. Explicit shutdown and manager deallocation retire callbacks; retained closures cannot retain or revive the manager.

## TDD Gate Compliance

Both tasks have intentionally failing behavioral assertions, validated by `check tdd-red-evidence` returning `RED_EVIDENCE_OK` for `/tmp/tennis-02-03-task1-red.json` and `/tmp/tennis-02-03-task2-red.json`, followed by their GREEN commits. Records normalize named XCTest assertions to TAP and retain raw logs/xcresults. Task 2 RED includes only the injected event/snapshot type declarations necessary to compile its fixture; no observation or event-handling behavior was implemented before RED. Task 1's committed unit and UI tracer reruns passed before Task 2 expansion. No separate refactor commit was needed.

## Deviations from Plan

**[Rule 3 - Wiring] Extend AppRuntime for the planned native-control scenarios.** Both tasks require the existing DEBUG factory, though AppRuntime was absent from this plan's file list. Added only playback-seek/playback-end scripted effects and `makeVideoPlayerManager`, wired from ContentView. UI and Release verification pass; commits `d6b92a7`, `636dbe2`.

**[Rule 2 - Correctness] Guard the existing metadata completion with the same load identity.** Replacement must invalidate seeks/time/events; an old asynchronous load must not repopulate their duration/readiness. Added minimal matching-load guards and finite playable duration checks while retaining the existing loader. Full transactional candidate/file ownership remains 02-04; commit `d6b92a7`.

The test-fixture teardown correction is documented above and in LEARNINGS. `apply_patch` created files because this runtime has no separate Write tool. No packages, architectural replacement, or import/file-ownership feature was added.

## Known Stubs, Threats and Pending Evidence

No goal-blocking stubs, skipped required automated tests or unrun automated commands remain. Optional empty injected effects are deliberate test seams; production supplies AV effects. T-02-09 through T-02-11 are covered by the seek/timeline/current-backend guards, numeric validation, single-loop assertions and held-stage tests. No new network, authentication, schema or external-file trust boundary was introduced.

Real local-media end, repeated scrub, Pause during seek and Replay inspection remains pending by the user's explicit end-of-phase deferral (WINDOWS entry 5). No actual local movie, physical camera, physical sound onset, clip accuracy or process-memory claim follows from these fixtures. 02-04 retains the real generated-movie integration and full resource/file-lifetime acceptance. EDGE-PLAY-01/02 and all six unclassified edge dispositions remain unresolved; the evidence-limit review and other physical checks remain pending.

Ready for 02-04 import/candidate ownership and complete teardown. LIFE-01/LIFE-02/PLAY-04 are shared with that unfinished plan, so their project requirement checkboxes must remain pending. This summary's required frontmatter copies the plan IDs and does not declare whole-phase acceptance.

## Self-Check: PASSED

Created VideoPlayerManagerTests and this summary exist. All four task commits resolve. Final required class/method counts, zero-skip results, Release build and diff checks pass. Task implementation is committed with no tracked deletion; only metadata closeout and parent-owned runtime artifacts remain.
