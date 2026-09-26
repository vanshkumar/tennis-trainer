---
phase: 01-consistent-toss-cues
plan: "03"
subsystem: inference
tags: [swift, coreml, fp16, xctest, ownership]
requires:
  - phase: 01-02
    provides: Owned prediction windows, associated candidate pose and bounded cue history
provides:
  - Strict per-head tensor validation with actual bundled-model smoke evidence
  - Complete camera/playback preparation-to-cue integration tests
  - Eight-buffer per-manager ownership proof with scoped transient lifetimes
  - Versioned deterministic evidence and explicit empirical follow-ups
affects: [session-transitions, overlay-alignment, empirical-verification]
tech-stack:
  added: []
  patterns: [scoped tensor bytes, scoped autorelease pools, weak ownership probes]
key-files:
  created:
    - Tennis Trainer/Detectors/GridTrackNetDecoder.swift
    - Tennis TrainerTests/GridTrackNetDecoderTests.swift
  modified:
    - Tennis Trainer/AnalysisFrame.swift
    - Tennis Trainer/Detectors/GridTrackNetDetector.swift
    - Tennis TrainerTests/AnalysisAssociationTests.swift
    - Tennis TrainerTests/BallDetectionManagerTests.swift
    - docs/references/toss-cue-validation.md
    - LEARNINGS.md
key-decisions:
  - Validate each FP16 head inside scoped byte access using its own explicit semantic axes and strides.
  - Drain preparation and prediction temporary owners before returning detached values.
  - Preserve eight unique admitted-pipeline buffers per manager; framework-private process memory remains unmeasured.
requirements-completed: [CUE-01, CUE-02, CUE-03, CUE-04]
coverage:
  - id: D1
    description: Strict independent FP16 layouts and actual bundled-model compatibility
    requirement: CUE-01
    verification:
      - kind: unit
        ref: Tennis TrainerTests/GridTrackNetDecoderTests.swift
        status: pass
    human_judgment: false
  - id: D2
    description: Both source adapters feed real preparation, decoder, candidate pose and one forwarded cue
    requirement: CUE-03
    verification:
      - kind: integration
        ref: Tennis TrainerTests/AnalysisAssociationTests.swift#testCompleteCameraCue_WhenRealPreparationAndDecoderAreUsed
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/AnalysisAssociationTests.swift#testCompletePlaybackCue_WhenRealPreparationAndDecoderAreUsed
        status: pass
    human_judgment: false
  - id: D3
    description: Finite unique buffers, no queued input and terminal ownership release
    requirement: CUE-02
    verification:
      - kind: integration
        ref: Tennis TrainerTests/BallDetectionManagerTests.swift#testUniqueBufferBound_WhenTwoManagersHoldPreparationPredictionAndPublication
        status: pass
      - kind: integration
        ref: Tennis TrainerTests/BallDetectionManagerTests.swift#testPixelAndLeaseRelease_WhenRealPipelineTerminatesOrOwnerDisappears
        status: pass
    human_judgment: false
  - id: D4
    description: Candidate-own pose or explicit missing-pose fallback
    requirement: CUE-04
    verification:
      - kind: integration
        ref: Tennis TrainerTests/AnalysisAssociationTests.swift
        status: pass
    human_judgment: false
  - id: D5
    description: Evidence ledger separates deterministic bounds from outstanding empirical reliability
    verification:
      - kind: other
        ref: docs/references/toss-cue-validation.md
        status: pass
    human_judgment: true
    rationale: Review evidence claims and permitted-input inventory; clip/device/physical audio checks remain pending Phase 4.
actuals:
  tokens: 14312
  tasks: 2
  commits: 4
commits: 4
plan_head_before: e3c845d87fdcc54ae8e0080dc90c908411f6d1da
measurement_head: c20c9353b1b145f424b60e4651080dc20190aa3c
duration: 16min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 3: Validated Decoder and Bounded Cue Pipeline Summary

**Scoped FP16 decoding, real source-adapter cue tests and observed buffer destruction preserve the model contract and prove an eight-buffer admitted pipeline per manager.**

## Performance and Commits

Initialization timestamp: 2026-09-26T04:14:56Z; implementation/evidence completed
2026-09-26T04:30:36Z (2026-09-25 local). Two tasks; eight implementation/test/
evidence files. Actual tokens are ceiling of 57,248 scoped realized-diff characters
divided by four; four commits measured from the persisted plan ledger before metadata.

1. `6267b54` — Task 1 RED: expose independent tensor layout failures.
2. `6a182bf` — Task 1 GREEN: validate each GridTrackNet tensor before decoding.
3. `b496c04` — Task 2 RED: expose retained preparation buffers during prediction.
4. `c20c935` — Task 2 GREEN: bound temporary frame ownership through publication.

Normal hooks and root/default-branch guards ran. The project explicitly allows its
existing main-branch sequential strategy. No tracked file was deleted. Parent-owned
architecture/model-reference edits and orchestration artifacts were not staged.

## Accomplishments and Final Interfaces

- `GridTrackNetDecoder.decode(outputs:window:)` is the one pure decode boundary.
  Both detector convenience paths call it through `decode(_:window:)` using the
  original five-record snapshot. Every tensor independently validates FP16, exact
  five-frame/48×27 semantics, rank, positive/nonoverlapping strides, overflow and
  accessible scoped byte span. All tensor values must be finite. Supported forms
  are `[5,48,27]`, `[5,27,48]` and their leading singleton equivalents. No guessed
  shape, raw unbounded pointer binding, or mutable post-prediction metadata remains.
- All five temporal indices, independently padded/permuted heads, threshold and
  argmax ties, invalid dtype/rank/dimensions/strides/storage span and nonfinite
  values have deterministic fixtures. Low-confidence samples retain metadata with
  absent positions. Portrait fit/nonportrait fill, padding, out-of-source rejection,
  bottom-left conversion and actual rotated pixel quadrants are verified.
- The actual bundled model loads and predicts on the selected simulator. All heads
  return FP16 (raw dtype 65552), `[1,5,48,27]`, strides `[7680,1536,32,1]`; inputs
  are f1…f5 images at 768×432. Model hashes are unchanged. The first smoke asserted
  the old three-axis reference and failed; the corrected allowed-batch fixture
  passes. This is compatibility evidence, not ball accuracy or physical latency.
- Both source adapters exercise actual preparation, snapshots, strict decoding,
  candidate-associated pose, apex logic and media callback forwarding. Nine acquired
  frames yield one cue each for candidate sequence 3. Every window's five identities,
  times, orientation, mapping and pose values are checked. Equivalent rational-time
  replay cannot create another observation or callback. ContentView → AudioManager
  automatic wiring and the separate manual Test Beep remain unchanged.
- `AnalysisFrame.Preparation` supplies optional per-call orientation/resize seams;
  its production defaults are the existing scaler. Tests inject failure boundaries
  or weak observers that call the real transforms. No global observer, production
  trace or new media logger exists. Preparation and prediction use scoped
  autorelease pools so only the prepared frame or detached samples escape.

## Verification

Commands, source fingerprint, unchanged model hashes and full result distinctions
are recorded in `docs/references/toss-cue-validation.md`. All runs use Xcode 27.0,
iPhone 17 Pro / iOS 26.5 (23F77), with the unchanged iOS 18.5 deployment target.
Logs and `.xcresult` bundles are under `/private/tmp/`.

| Run | Executed | Passed | Failed | Skipped | Bundle basename |
|---|---:|---:|---:|---:|---|
| Task 1 RED | 2 | 0 | 2 | 0 | tennis-01-03-task1-red |
| First GREEN/model observation | 4 | 3 | 1 | 0 | tennis-01-03-task1-green |
| Corrected decoder/model | 5 | 5 | 0 | 0 | tennis-01-03-task1-final |
| Task 2 RED/characterization | 4 | 3 | 1 | 0 | tennis-01-03-task2-characterization |
| Initial full regression | 64 | 64 | 0 | 0 | tennis-01-03-full-regression |
| Final full regression | 65 | 65 | 0 | 0 | tennis-01-03-final-regression |

Final required class counts: manager 21, association 10, decoder 6, pose 4, apex 23;
the remaining 1 is the existing scaffold. All required groups executed, no skip.
One Thread Performance Checker priority warning arises from controlled semaphore
stalls in manager tests; it is recorded in `.planning/WINDOWS.md`, not counted as
a test failure or production timing evidence.

## Resource and Requirement Matrix

| Quantity | Per manager | Two managers |
|---|---:|---:|
| Lease/worker through publication | 1 | 2 |
| Pending inputs | 0 | 0 |
| Prepared ring / shared snapshot pixels | 5 | 10 |
| Peak unique pixels: ring + raw + oriented + new prepared | 8 | 16 |
| Prediction unique pixels: ring + raw | 6 | 12 |
| Held publication unique pixels: ring only | 5 | 10 |
| Value publications | 1 | 2 |
| Publication-owned pixels/tensors | 0/0 | 0/0 |
| Cue history entries | 3 | 6 |
| Production trace history | 0 | 0 |

Weak CVPixelBuffer identity probes and raw-storage destruction callbacks establish
actual unique ownership. Both managers simultaneously attain eight each/sixteen
total at preparation. One thousand further offers per manager at preparation,
prediction and publication do not increase retained work. Snapshot/model input
feature values share ring pixels. The decoder transiently owns three 6,480-Float
canonical arrays (77,760 scalar bytes); publication owns neither those nor tensors.
The bound excludes caller-owned rejected offers/source pools and framework-private
allocations; no process-memory ceiling is claimed.

Reset in prediction clears ring storage on worker completion and suppresses
effects. Reset while publication is held suppresses effects, retains at most five
idle ring pixels until next worker reset, and teardown releases them. Tests cover
warmup, missing model, missing/failed pose, orientation/resize failure, thrown
prediction, malformed tensors, invalid generations, publication discard and
owner teardown. Matching release counts prove capacity returns exactly once.

| Requirement | Evidence |
|---|---|
| CUE-01 | Camera/playback acquired times, complete windows, independent FP16 heads and geometry |
| CUE-02 | Unique-buffer maxima, raw destruction, terminal release and held-stage bursts |
| CUE-03 | Complete-path single cue plus overlapping/replayed/pruned evidence and exact cooldown |
| CUE-04 | Candidate-own pose, contradictory later pose, identity mismatch and strict missing fallback |

## TDD Gate Compliance

Both executable RED records passed `check tdd-red-evidence`; records are
`/private/tmp/tennis-01-03-task{1,2}-red.json`, explicit TAP projections of actual
XCTest evidence. Task 1 failed numerical independent-layout assertions and
malformed-output acceptance before decoder changes. Task 2 failed the expected
twelve prediction-time buffers with fourteen observed before the pool fix. The
eight/sixteen peak cap was never relaxed.

The Task 2 observation seam was introduced with RED tests before changing runtime
allocation lifetimes. Complete adapter and terminal characterization already
passed and were retained as regression proof, not falsely reported as failures.
Additional pixel-quadrant/arithmetic guards and tensor-release tests were added
after the core RED gates and passed in full regression; they did not receive
separate pre-implementation RED runs. No refactor commit was needed.

## Deviations from Plan

- **[Rule 1 — Bug] Drain transient Core Image ownership before inference.** The
  real weak-identity test observed two extra oriented buffers until the outer
  test worker pool drained. A scoped preparation pool fixes this lifetime, and
  a prediction pool similarly bounds app-owned feature/tensor temporaries.
  Files: AnalysisFrame/GridTrackNetDetector; verified unchanged 12/16 assertions,
  terminal destruction and tensor-release tests; commit `c20c935`.
- **[Rule 2 — Critical testability] Added AnalysisFrame preparation seams.** The
  plan's shorter file list omitted the real allocation boundary needed to prove
  intermediate ownership and failure paths. Parent approved this bounded extension;
  production transforms are unchanged. Seam committed with RED `b496c04`.
- **[Rule 2 — Project rules] Updated LEARNINGS.md** with the observed batch/padded
  model representation and autorelease lifetime lesson. No model, UI, service,
  dependency, OS target, bundle identifier or new network boundary changed.

## Remaining Evidence and Flagged Assumptions

No permitted repository `.mov`, `.mp4` or `.m4v` fixture exists; external media
permission, physical phone and synchronized audio setup remain unknown. No baseline
clip comparison or physical beep measurement ran. The controlled adapter inputs
are 10033…10297/1000 with 33/1000-second gaps, not measured capture cadence.

A1 sampling sufficiency remains empirical. A2 eight-buffer ownership is proven
within the stated app-object scope; sustained process memory is pending. A3 compact
history has preserved and adversarial deterministic coverage, not real-clip scoring.
The first consumed estimate, including missing/low-confidence positions, remains
authoritative. EDGE-CUE-01 / EDGE-CUE-04 remain unclassified/unresolved in the
supplied report. The descriptor-less transparency prohibition remains flagged:
synthetic counts, queue bounds and callbacks must not be sold as measured tennis
accuracy or sound onset.

Phase 2 owns full control transitions, Phase 3 displayed overlay alignment, Phase 4
permitted labeled clips, frozen numeric empirical criteria, sustained device tests
and physical sound timing. No empirical criterion was retroactively tuned.

## Known Stubs and Threat Flags

No goal-blocking production stub, skipped test or unrun automated verification.
Empty pose/missing position are explicit outcomes. No new unmodeled network,
authentication, file-access or schema boundary was introduced. The test-stall
warning is the only newly recorded open defect; review or waiver belongs to the
orchestrator before shipping.

## Next Phase Readiness

Plan execution is complete. Phase completion and shared CUE requirement acceptance
remain with the parent's independent review/security/verification. Human review
of the evidence ledger remains pending; physical reliability is not accepted.

## Self-Check: PASSED

New decoder and test files exist; all four task commits exist. Final bundle reports
65 passed, zero failed/skipped, with every required XCTest class represented.
`git diff --check` passes; model checksums match baseline; no tracked deletion.
