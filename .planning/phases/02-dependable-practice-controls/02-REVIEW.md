---
phase: 02-dependable-practice-controls
reviewed: 2026-09-26T16:53:06Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - LEARNINGS.md
  - Tennis Trainer/AppRuntime.swift
  - Tennis Trainer/BallDetectionManager.swift
  - Tennis Trainer/CameraManager.swift
  - Tennis Trainer/ContentView.swift
  - Tennis Trainer/VideoImportManager.swift
  - Tennis Trainer/VideoPickerView.swift
  - Tennis Trainer/VideoPlayerManager.swift
  - Tennis TrainerTests/BallDetectionManagerTests.swift
  - Tennis TrainerTests/CameraManagerTests.swift
  - Tennis TrainerTests/PracticeLifecycleTests.swift
  - Tennis TrainerTests/VideoImportManagerTests.swift
  - Tennis TrainerTests/VideoPlayerManagerTests.swift
  - Tennis TrainerUITests/Tennis_TrainerUITests.swift
  - docs/references/practice-controls-validation.md
  - ARCHITECTURE.md
  - docs/README.md
  - docs/RAMPUP.md
  - docs/references/README.md
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
---

# Phase 2: Code Review Report

**Reviewed:** 2026-09-26T16:53:06Z
**Depth:** standard
**Files Reviewed:** 19
**Status:** clean

## Summary

Reviewed the explicit Phase 2 scope against baseline `c49e45657d9c74a53b007e4921888c5fe0b1ba31`, including production callers and the supplied lifecycle tests. The initial review found two blockers. Re-review of the current source through `212f17e` confirms both are resolved and finds no outstanding substantiated defects in the incremental control/accessibility changes. A subsequent UI gate caught an empty accessibility group that the earlier source review had not identified; the failed-gate/fix provenance is retained below. Frontmatter counts represent outstanding findings; original findings remain below as resolved history.

The follow-up examined CameraManager, VideoPlayerManager, ContentView, AppRuntime, CameraManagerTests, VideoPlayerManagerTests and Tennis_TrainerUITests, including the complete changed production methods and their callers. No source was modified and no Xcode/simulator commands were run by this reviewer; final build/test execution belongs to the parent. Project instructions, learnings, plans and summaries were read; no project-local skills or configured agent skills apply. No structural pre-pass or external reviewer evidence was supplied.

## Narrative Findings (AI reviewer)

No outstanding findings. The camera initializer establishes immutable backend references before registering effects or requesting authorization reconciliation. Replacement retires seek authority before Pause settles visible state and preserves the unconfirmed target for completion-gated retry. The slider uses its positive validated duration, clamps displayed position and disables input while loading; mode-owned pose accessibility groups are constructed only when at least one right-arm joint exists. Import recovery messages distinguish a retained clip from the empty selection. The added short-clip scenario remains inside DEBUG-only injection.

Incremental evidence inspected: `ContentView.swift:150-168, 289-307, 350-360`; `AppRuntime.swift:17, 85`; `VideoPlayerManager.swift:327-329`; `VideoPlayerManagerTests.swift:53-80`; `Tennis_TrainerUITests.swift:12-94`. New tests assert fractional slider position/end, import loading disable/re-enable, recovery messages and existing visible overlay clearing. Their runtime results and final regression gates are owned by the parent; this review does not claim a rendered VoiceOver or physical-device test.

## UI Gate Follow-up Provenance

The parent reported that the complete UI gate after `8ba8451` failed the existing overlay-clear check: an empty pose accessibility group remained after Stop despite `.accessibilityHidden(true)`. The earlier clean source review is not evidence that this gate passed. Commit `212f17e923ea9228c142e03940153620d06b6cdd` replaces that modifier with conditional construction of the entire camera and playback pose groups. The exact commit diff and current `ContentView.swift:150-168, 289-307` were re-read: both conditions inspect the corresponding mode-owned right-arm joints, and all Circle coordinate formulas, size, color and nonempty accessibility metadata remain unchanged. Empty tracking now supplies no group view or associated accessibility element. No additional source defect was found in this fix. The parent is rerunning the complete build/unit/UI gates; their post-fix outcome is **pending** at this review timestamp, and no runtime pass is claimed here.

## Resolved Findings History

The following records preserve the original 2026-09-26T16:40:36Z findings and source line references. Their BLOCKER classifications describe the original defects, not outstanding work.

### CR-01: First camera access can initialize different sessions on UI and session queues — RESOLVED

**Classification:** BLOCKER
**File:** `/Users/vanshkumar/Documents/repos/tennis-trainer/Tennis Trainer/CameraManager.swift:86-90`
**Related lines:** `CameraManager.swift:124-126, 163-178, 461-469`; `ContentView.swift:135-138`.
**Issue:** Phase 2 replaced the eager session with an ordinary Swift instance `lazy var`. That storage is first accessed both by main-thread preview construction and by session-queue effects, with no lock or established initialization ordering. In particular, denied authorization or inactive/mode-exit handling queues `stopCapture()` even before a preview exists; its production `stop` effect dereferences `captureSession` merely to check `isRunning`. A later authorization/context return can render the first preview while that queued effect is initializing the same lazy property. The initializer also writes `ownedSession` from whichever executor gets there. Concurrent first reads can construct and publish different sessions: the preview can retain one while configuration/start and teardown operate on another, producing a blank preview or inconsistent AV ownership. The operation lock protects the operation UUID, not either session-storage write. The DEBUG camera UI scenarios suppress the real preview and injected tests do not exercise this allocation boundary.
**Fix:** Establish a single session identity before exposing it to either executor. For example, construct a production-only backend containing immutable `let` session/output references during manager initialization, while injected/test managers omit that backend. Alternatively, put all first-access creation behind a dedicated synchronized owner and hand the same already-created session to preview construction; do not synchronize an AV start/stop call on the UI. Remove the separate unsynchronized `ownedSession` assignment. Add an allocation/identity regression that holds first backend creation while preview access and a queued Stop compete, asserting one creation and identical preview/configuration/teardown ownership.

**Verified resolution:** Commit `d1af3ea`. Current `/Users/vanshkumar/Documents/repos/tennis-trainer/Tennis Trainer/CameraManager.swift:57-63` defines a backend with immutable session/output references, line 91 holds it in an immutable property, and lines 112-116 initialize it before `super.init()` and all effect registration. Production start/stop/snapshot, configuration, observation, preview and deinit use that same owner (lines 127-151, 155-163, 207-210, 443, 474-481). The lazy session and secondary `ownedSession` writer are gone. `/Users/vanshkumar/Documents/repos/tennis-trainer/Tennis TrainerTests/CameraManagerTests.swift:6-43` checks absent backend allocation in injected/default-test paths and consistent preview/queued-effect identity using an explicit inert backend. This test is an initialization/ownership regression with injected effects; it does not recreate a physical concurrent first-access race or run actual camera startup. The source removes the competing lazy initialization entirely, so no physical race reproduction is needed to establish this specific fix.

### CR-02: Cancelled replacement leaves a retired seek displayed as still in progress — RESOLVED

**Classification:** BLOCKER
**File:** `/Users/vanshkumar/Documents/repos/tennis-trainer/Tennis Trainer/VideoPlayerManager.swift:187-191`
**Related lines:** `VideoPlayerManager.swift:199-214, 318-322, 511-514, 550-569`.
**Issue:** Start a seek on a loaded clip, hold its completion, then choose a new video. `beginReplacement()` calls `pause()` while `seekID` is still set; `pause()` intentionally does not change `.seeking` in that case. The following line clears `seekID` and cancels the backend seek, so no completion can clear that presentation anymore. Picker cancellation, provider failure, metadata failure and readiness failure only clear loading/set an import message, leaving the preserved clip in `.seeking` indefinitely. The actual UI continues to display “Seeking…” despite having no current seek; a later old success/failure is correctly rejected and cannot repair it. Existing failed-replacement tests begin from playing/paused state, so they do not cover this cross-control transition. Explicit Play can recover by retrying the retained seek target, but the idle state remains incorrect until another user action.
**Fix:** Retire the seek identity before calling `pause()` in replacement setup, or explicitly normalize the retained session to `.paused` after retiring it and before cancellation can deliver callbacks. Retain the unsettled target (or an equivalent successful-seek requirement) so later Play still goes through the completion gate rather than allowing analysis on an unconfirmed timeline. Add held-seek regressions for cancelled selection, provider error, metadata/readiness failure and late old completion; assert the prior duration/selection is retained, `playRequested`/`isPlaying` are false, state is `.paused`, no extraction loop exists, and explicit Play resumes only after a fresh successful seek.

**Verified resolution:** Commit `792d728`. Current `/Users/vanshkumar/Documents/repos/tennis-trainer/Tennis Trainer/VideoPlayerManager.swift:187-193` clears `seekID` before `pause()` and before cancelling backend seeks. `failedSeekTarget` remains retained, so `play()` still issues a fresh seek instead of reopening immediately. `/Users/vanshkumar/Documents/repos/tennis-trainer/Tennis TrainerTests/VideoPlayerManagerTests.swift:7-51` holds the old seek across five replacement outcomes and both old success/failure results; asserts immediate and terminal Paused state, retained duration/position, no requested/actual playback or loop, rejection of old callbacks before/during/after retry, and a single loop only after the fresh successful seek. This directly covers the original state-transition failure.

---

_Reviewed: 2026-09-26T16:53:06Z_
_Reviewer: gsd-code-reviewer_
_Depth: standard_
