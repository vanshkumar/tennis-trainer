---
phase: 01-consistent-toss-cues
plan: "02"
subsystem: inference
tags: [swift, coremedia, coreml, xctest, pose, deduplication]
requires:
  - phase: 01-01
    provides: Rational frame identities, bounded analysis leases, and frame-tagged pose
provides:
  - App-owned five-frame prediction snapshots with required per-sample metadata
  - Candidate-owned pose height evaluation with strict missing-pose fallback
  - Rational monotonic consumption and three-entry cue history
affects: [01-03, session-transitions, empirical-verification]
tech-stack:
  added: []
  patterns: [immutable window, injected predictor, rational watermark, candidate-owned pose]
key-files:
  created:
    - Tennis Trainer/AnalysisFrame.swift
    - Tennis TrainerTests/AnalysisAssociationTests.swift
  modified:
    - Tennis Trainer/BallDetectionManager.swift
    - Tennis Trainer/Detectors/GridTrackNetDetector.swift
    - Tennis Trainer/Detectors/ServeTossApexDetector.swift
    - Tennis TrainerTests/BallDetectionManagerTests.swift
    - Tennis TrainerTests/ServeTossApexDetectorTests.swift
    - LEARNINGS.md
key-decisions:
  - First consumed estimates are authoritative, including missing and low-confidence positions.
  - Only an authorized manager identity domain can reset cue history and cooldown.
  - Use integer CMTime fixtures and rational subtraction for exact cooldown boundaries.
requirements-completed: [CUE-01, CUE-02, CUE-03, CUE-04]
coverage:
  - id: D1
    description: Owned pixels and exact five-frame metadata remain associated through held prediction
    requirement: CUE-01
    verification:
      - kind: integration
        ref: Tennis TrainerTests/BallDetectionManagerTests.swift#testWindowRetainsOriginalMetadata_WhenPredictionIsHeld
        status: pass
      - kind: unit
        ref: Tennis TrainerTests/BallDetectionManagerTests.swift#testPreparedPixelsRemainOwned_WhenSourceIsMutated
        status: pass
    human_judgment: false
  - id: D2
    description: Candidate pose or strict fallback controls the automatic manager cue
    requirement: CUE-04
    verification:
      - kind: integration
        ref: Tennis TrainerTests/AnalysisAssociationTests.swift#testCueUsesCandidatePose_WhenLaterNoseIsHigher
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/AnalysisAssociationTests.swift#testNoCueUsesCandidatePose_WhenLaterNoseIsLower
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/AnalysisAssociationTests.swift#testCueUsesFallback_WhenPoseIdentityMismatchesAboveThreshold
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/AnalysisAssociationTests.swift#testNoCue_WhenPoseIdentityMismatchesAtOrBelowFallback
        status: pass
    human_judgment: false
  - id: D3
    description: Replayed and overlapping evidence cannot grow cue history or revise consumed candidates
    requirement: CUE-03
    verification:
      - kind: integration
        ref: Tennis TrainerTests/AnalysisAssociationTests.swift#testSlidingWindowsAndReplayAfterPruning_KeepBoundedManagerCueState
        status: pass
      - kind: unit
        ref: Tennis TrainerTests/ServeTossApexDetectorTests.swift#testDenseHistoryRemainsBounded_WhenOneThousandWindowsOverlap
        status: pass
    human_judgment: false
actuals:
  tokens: 21789
  tasks: 3
  commits: 7
commits: 7
plan_head_before: 55bfc74c1964bba7ce6a60fffdd89486173818b9
measurement_head: 06e127448f368931fc77a0b4618036ee84ca3fce
duration: 19min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 2: Associated Prediction and Cue Evidence Summary

**Owned prediction windows preserve every frame's pixels, geometry, rational time and pose; cue consumption uses a persistent watermark and at most three eligible entries.**

## Performance

- Started: 2026-09-25T22:24:03Z
- Implementation completed: 2026-09-25T22:43:22Z
- Tasks: 3; implementation files: 8
- Actual tokens: ceiling of 87,155 realized diff characters / 4, measured before close-out metadata. Seven commits measured from the persisted `.git/gsd-plan-head-before-01-02` ledger.

## Accomplishments

- Each prepared frame owns a newly allocated 768×432 buffer, including the former `.up`/exact-size alias path. Five-record snapshots share ring buffers without another five-pixel-buffer copy. Held prediction returns the original five identities, pixel sentinels, rational times, orientations, dimensions, mappings and pose values after newer, differently shaped frames enter the ring.
- Missing/invalid/mismatched pose becomes explicit absence while valid frame metadata remains eligible. Nose precedes neck at confidence strictly greater than 0.3. Automatic evaluation reads the candidate baseline plus 0.05, or strict y > 0.70 fallback; current UI pose is unreachable from that decision.
- Consumption checks source/generation, sequence and rational time before eligibility. Missing and low-confidence samples advance the watermark. Repeated, older or equal-time evidence cannot revise a candidate after history eviction. Three retained entries, scalar candidate identity, scalar cooldown identity and saturating counters replace time-only history growth.
- The manager supplies the authorized domain before cue consumption and preserves its original lease/publication checks. Resetting into a new domain clears cue state; sample mismatch and repeated same-domain reset cannot reset the watermark.

## Task Commits

1. Task 1 RED: `d5a81fb` — expose retained source pixel mutation.
2. Task 1 GREEN: `c5b3eb5` — own prediction pixels and frame metadata.
3. Task 2 RED: `893a662` — expose historical candidate pose mismatch.
4. Task 2 GREEN: `f152089` — evaluate each candidate with its own pose.
5. Task 3 RED: `9e67e5f` — expose replay and finite history failures.
6. Task 3 GREEN: `d6df7f6` — consume cue evidence once with bounded history.
7. Follow-up correctness: `06e1274` — capture monotonic ingress time when Input is created, before pose/preparation; apply repository test indentation.

Normal hooks ran. No tracked file deletion occurred. Close-out metadata is committed separately.

## Final Interfaces

- `AnalysisFrame.prepare(input:identity:pose:ingressTime:) -> AnalysisFrame?` allocates prepared pixels; optional ingress override is for deterministic fixtures, production retains `Input.ingressTime`.
- `AnalysisFrame.Metadata` holds identity, original `CMTime`, monotonic ingress time, raw/oriented sizes, orientation, `Mapping`, and sanitized `FramePose`.
- `AnalysisFrame.Window.init?(_:)` accepts exactly five valid records from one source/generation with strictly increasing sequence and rational time. Metadata validates positive finite geometry, oriented dimensions, mapping values and identity time consistency.
- `GridTrackNetDetector.Predictor = (AnalysisFrame.Window) throws -> RawOutputs`; injection constructs no bundled model. Production maps oldest-to-newest to `f1`…`f5` and retains `conf/x_off/y_off`.
- `pushFrame(input:identity:pose:) -> Bool`, `snapshot()`, `predict(window:)`, `decode(_:window:)`, and both convenience detection methods share the same snapshot. Prediction serialization is separate from ring synchronization. `Sample.metadata` is required; `timestamp` derives from it.
- Grid `Diagnostics` exposes ring count and unique prepared buffers. Manager diagnostics expose those observations alongside the existing lease/publication counters.
- `ServeTossApexDetector.consume(samples:)` has no live height provider. `reset(sourceID:generation:)` authorizes a new domain. `CueDiagnostics` contains retained count, consumed/evaluated/emitted counts and last emitted candidate identity; manager `cueDiagnostics` provides a locked value snapshot.

## Verification

Commands used `xcodebuild test -scheme 'Tennis Trainer' -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` with plan-selected class filters; complete regression used `-only-testing:Tennis TrainerTests`. Exact counts were read with `xcresulttool`. Logs and bundles are under `/private/tmp/`.

| Run | Executed | Passed | Failed | Skipped | Bundle |
|---|---:|---:|---:|---:|---|
| Task 1 intentional RED | 1 | 0 | 1 | 0 | `tennis-01-02-task1-red.xcresult` |
| Task 1 GREEN | 24 | 24 | 0 | 0 | `tennis-01-02-task1-green.xcresult` |
| Task 2 intentional RED | 15 | 8 | 7 | 0 | `tennis-01-02-task2-red.xcresult` |
| Task 2 GREEN | 17 | 17 | 0 | 0 | `tennis-01-02-task2-green.xcresult` |
| Task 3 intentional RED/characterization | 24 | 21 | 3 | 0 | `tennis-01-02-task3-red.xcresult` |
| Task 3 final targeted | 31 | 31 | 0 | 0 | `tennis-01-02-task3-final.xcresult` |
| Final full unit regression | 54 | 54 | 0 | 0 | `tennis-01-02-final-regression.xcresult` |

The original six apex outcomes remain unchanged. Additional characterization covers the inclusive 1.5-second horizon, split batches, expired batch candidates, empty/partial/tied/no-position input and confidence gaps. Exact integer source times independently verify 3,999ms rejection and 4,000/4,001ms acceptance with two evaluated candidates and six consumed frames.

Both pure detector and real-manager tests cover the two contrary-pose directions and all three mismatch dimensions. Each mismatch explicitly asserts missing pose and independently proves y=0.71 cues while y=0.69/0.70 does not. Additional cases cover absent/error/boundary-confidence pose, valid neck, nose priority, invalid numeric joints, delayed pose, and changed model confidence on repeated evidence.

The 1,000 sliding-window fixture consumes exactly 1,004 samples and evaluates 1,002 candidates; retained history never exceeds three. Replaying the old window after pruning leaves consumed/evaluated/emitted counts unchanged. Manager warmup through the actual injected grid produces no prediction for zero through four records; missing positions produce no cue after warmup. Explicit generation reset rejects previous-domain samples and restarts warmup.

## TDD Gate Compliance

All three RED evidence records passed `check tdd-red-evidence`; records are `/private/tmp/tennis-01-02-task{1,2,3}-red.json`. They retain command, exit, target test, expected/actual values and an explicitly labeled TAP projection of XCTest evidence.

Task 1 reproduced ownership using the existing detector and a temporary reflection probe before changing production code. The held-window and malformed-metadata tests were added with the new injection contract and did not receive separate pre-implementation RED runs. This is a sequencing deviation from the plan's request for three RED association tests, not a claim that a compiler failure proved behavior. Final tests use direct window/predictor semantics and no reflection or real model initialization.

Task 3's first exact-cooldown fixture was not exact: converting floating seconds into a million-tick timebase could quantize below the intended boundary. That fixture was corrected to explicit integer milliseconds without weakening the required exact boundary. The ownership, replay and history failures were real executable behavioral RED evidence. First Task 3 GREEN had one fixture failure; the corrected targeted and full suites pass.

## Bounds and Remaining Evidence

The production manager retains one lease and no pending input. Its ring owns at most five prepared buffers; its synchronous prediction snapshot shares those same buffers. Pure-detector adversarial tests deliberately allow a second ring to replace entries while the first snapshot is held; the production manager's single lease prevents that concurrent preparation pattern. Transient preparation allocations, tensor layouts, whole-pipeline aggregate counts and bundled-model smoke remain 01-03 obligations. This plan does not claim a framework/process-memory bound.

Portrait-fit/nonportrait-fill, overlay index 4 at both media adapters, model names, iOS 18.5, bundle identity and manual/audio callback wiring are preserved. No package, service, UI mode, model replacement or trust boundary was added.

EDGE-CUE-01 and EDGE-CUE-04 remain **unclassified/unresolved in the supplied edge-probe report**. Their manual association/fallback contracts now have deterministic coverage; that does not silently reclassify the probes. Research A3 is characterized for the preserved six cases, horizon/batch/partial/confidence-gap cases and bounded replay tests. First-consumed-estimate policy and sampling adequacy remain unscored on representative clips. Physical device, clip accuracy and audible latency remain pending Phase 4; callback counts do not prove audio timing.

## Deviations from Plan

- Task 1 RED sequencing used an executable legacy ownership probe; new snapshot/injection-specific tests were introduced with the interface, as detailed above.
- [Rule 2 — Integration] Task 3 also changes `BallDetectionManager.swift` to pass an explicitly authorized source/generation to cue reset and expose diagnostics. Its action required that integration despite the shorter task file list.
- [Rule 1 — Bug] Final review moved monotonic ingress capture from preparation into `Input` so optional timing is not shifted by prior pose work; the owned-pixel test asserts preservation.
- [Rule 2 — Project rules] Added project-specific observations to `LEARNINGS.md`. Existing unrelated compiler warnings are recorded in `deferred-items.md` without changes to playback code. The optional WINDOWS register is absent.

## Issues Encountered

Simulator/xcresult access required authorized sandbox escalation. The initial source-ownership probe initialized the legacy model but never ran a prediction; final injected tests do not initialize it. One patch tool rejected a same-file delete/add operation before making changes; a file replacement succeeded. No auth gate, installation, skipped test or unrun automated verification remains.

## Known Stubs

None. Missing-pose values and nil detection positions represent explicit input outcomes, not unwired production behavior. Tensor hardening remains the next planned implementation, not a substituted fake decoder.

## Next Phase Readiness

Ready for 01-03 decoder, aggregate ownership and complete integration verification. Shared CUE requirements remain pending final phase verification despite this summary's required plan-coverage array. Phase 1 is not complete.

## Self-Check: PASSED

Both new source/test files and all seven task/fix commits exist. Required suites execute semantic assertions; final full regression passes 54/54 with zero skips. `git diff --check` passes; no tracked files were deleted and run artifacts were not staged.
