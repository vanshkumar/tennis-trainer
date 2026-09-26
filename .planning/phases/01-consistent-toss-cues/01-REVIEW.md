---
phase: 01-consistent-toss-cues
reviewed: 2026-09-26T04:37:53Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - ARCHITECTURE.md
  - GRIDTRACKNET_COREML.md
  - LEARNINGS.md
  - Tennis Trainer/AnalysisFrame.swift
  - Tennis Trainer/BallDetectionManager.swift
  - Tennis Trainer/CameraManager.swift
  - Tennis Trainer/Detectors/ColorKalmanBallDetector.swift
  - Tennis Trainer/Detectors/GridTrackNetDecoder.swift
  - Tennis Trainer/Detectors/GridTrackNetDetector.swift
  - Tennis Trainer/Detectors/ServeTossApexDetector.swift
  - Tennis Trainer/PoseDetectionManager.swift
  - Tennis Trainer/VideoPlayerManager.swift
  - Tennis TrainerTests/AnalysisAssociationTests.swift
  - Tennis TrainerTests/BallDetectionManagerTests.swift
  - Tennis TrainerTests/GridTrackNetDecoderTests.swift
  - Tennis TrainerTests/PoseDetectionManagerTests.swift
  - Tennis TrainerTests/ServeTossApexDetectorTests.swift
  - docs/references/README.md
  - docs/references/toss-cue-validation.md
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
---

# Phase 1: Code Review Report

**Reviewed:** 2026-09-26T04:37:53Z
**Depth:** standard
**Files Reviewed:** 19
**Status:** clean

## Narrative Findings (AI reviewer)

No actionable BLOCKER or WARNING was established in the submitted Phase 1 implementation. No structural pre-pass or external reviewer evidence was supplied.

## Summary

Reviewed the complete contents of the 19 explicitly scoped source, test, and reference files against CUE-01 through CUE-04 at HEAD `cddaebb`. The phase diff starts at `bf5801e3ff4961c9c436af881af80d8cb3d23e78^`. Read the repository rules, learnings, all three plans and summaries, requirements, and relevant research; followed calls into the scaler, app configuration, and UI callback composition. No configured agent skills or repository skill directories were present.

All reviewed files meet quality standards for the scoped Phase 1 changes. No issues found.

The adversarial inspection covered:

- Raw/prepared buffer ownership, the exact-size orientation path, ring/snapshot sharing, and detached publication payloads. The inspected production path admits preparation only under the manager lease; the direct-detector concurrency fixture is not the production admission policy.
- Source time, checked frame sequence, generation and source identity, five-frame metadata validation, and decoding against the original prediction snapshot.
- Reset before work, during work, and during publication; coalesced idle resets; owner teardown; matching lease release; and synchronous invalidation from observable effects or callbacks.
- Watermark advancement for missing or low-confidence samples, overlapping and reordered evidence, history eviction, the three-entry bound, rational cooldown boundaries, and candidate-owned pose with explicit fallback.
- Independent FP16 head layouts, axis interpretation, positive nonoverlapping strides, checked storage-span arithmetic, finite values, threshold/tie behavior, fit/fill mapping, and malformed-result rejection.
- Test assertions and fixture ownership, including deterministic complete-adapter paths and separation of synthetic tensors from the bundled-model smoke test.

## Evidence Limits

This was a read-only code review; the reviewer did not run a new build or test suite. The summaries and validation ledger report the prior 65-test passing run and the actual bundled FP16 output layout. Those execution claims are recorded evidence, not an independently rerun result or a substitute for source inspection. The scoped `git diff --check` passed during review. Only this review artifact was created; no source files were changed and no commit was made.

The Thread Performance Checker item in `.planning/WINDOWS.md` concerns deliberate semaphore waits in the test preparation/predictor closures (`Tennis TrainerTests/BallDetectionManagerTests.swift:31`, `:36`, and `:245`) and their controlled global-queue execution. The production manager schedules work and publication asynchronously and does not use those semaphore gates. The source inspection does not establish a production correctness defect from this test diagnostic; the register was left unchanged for the orchestrator's disposition.

Complete stop/pause/seek/import/mode-transition acceptance belongs to Phase 2; displayed layer geometry belongs to Phase 3. Sampling sufficiency, representative clip accuracy, sustained process memory, and physical sound timing remain pending Phase 4 evidence. The eight/sixteen-buffer ledger covers admitted app-visible pipeline buffers and does not establish a framework-private allocation or process-memory ceiling. This clean Phase 1 review does not accept those later requirements or establish real-world cue accuracy.

---

_Reviewed: 2026-09-26T04:37:53Z_
_Reviewer: gsd-code-reviewer_
_Depth: standard_
