# Tennis Trainer

## What This Is

Tennis Trainer is a SwiftUI iPhone app for solo tennis serve practice. It analyzes live camera frames or a selected video on-device, tracks the ball and body pose, and plays a beep when it detects the apex of the player's toss so the player can practice without watching the screen.

The first GSD milestone improves the reliability of that existing cue across both modes. The user approved this scope on 2026-09-24: synchronized detections, correct overlays, dependable camera/playback controls, and repeatable verification of cue accuracy and latency.

## Core Value

A player can trust the toss-apex beep to correspond to the current toss, without stale or duplicate feedback interrupting practice.

## Requirements

### Validated

Existing capabilities below were source-inspected during initialization. Phase 1 reliability items additionally have a passing build, 65 automated tests, independent review and three explicit human review passes. Real-device performance and clip/audio reliability remain unmeasured.

- ✓ Live back-camera analysis with start/stop controls and pose/ball overlays — existing `CameraManager`, `CameraPreview`, and `ContentView`.
- ✓ Local video selection, muted playback, seeking, and frame analysis — existing `VideoPickerView` and `VideoPlayerManager`.
- ✓ On-device pose estimation and five-frame GridTrackNet ball inference — existing `PoseDetectionManager` and `GridTrackNetDetector`.
- ✓ Toss-apex detection with confidence filtering, pose-relative/fallback height gates, timestamp deduplication, cooldown, and an audio callback — existing `ServeTossApexDetector` and `AudioManager`.
- ✓ Regression tests for accepted/rejected tosses, cooldown, source/pose association, scheduling, ownership and decoding — Phase 1 full shared-scheme run passed 65/65.
- ✓ Exact original-frame, timestamp and coordinate-mapping association through prediction — CUE-01, Phase 1; held-window and source-mutation tests.
- ✓ Finite admitted work and app-visible buffers, with no pending-input backlog — CUE-02, Phase 1; one lease through publication, eight buffers per manager/sixteen aggregate under the documented scope.
- ✓ At most one automatic cue for overlapping/replayed eligible evidence, with an independent cooldown — CUE-03, Phase 1.
- ✓ Candidate-associated pose or explicit strict missing-pose fallback — CUE-04, Phase 1; exact source/session/frame identity, fallback height above 0.70.

### Active

- [ ] Preserve responsive user controls and invalidate feedback across every supported session transition using the bounded Phase 1 pipeline.
- [ ] Prevent stale overlays or beeps after stopping capture, pausing/seeking playback, replacing a clip, or switching modes.
- [ ] Align ball and pose overlays with the displayed image, including portrait videos, aspect-fit padding, and aspect-fill cropping.
- [ ] Provide a working camera permission recovery flow and accurate capture state.
- [ ] Handle video completion, replay, replacement, and cleanup predictably.
- [ ] Verify cue behavior and timing with deterministic regression tests, repeatable clips, and real-device checks.

### Out of Scope

- Trophy-position and contact cues — deferred until the existing toss-apex cue is dependable.
- Forehand revival and additional strokes — the approved milestone remains serve-focused; archived code stays unwired.
- Left-handed support, rally gating, and multi-player analysis — retain the current right-handed solo-practice assumptions.
- Landscape app UI — retain portrait orientation; correct handling of imported video geometry remains in scope.
- Accounts, cloud processing, analytics services, and server infrastructure — the product's current value is local feedback without a network dependency.
- Model replacement or retraining as a planned deliverable — first establish pipeline correctness and measured behavior with the bundled model; revisit separately if evidence shows model limitations block reliability.

## Context

### Existing implementation

- `Tennis Trainer/ContentView.swift` composes the managers and connects apex callbacks to the shared audio output.
- Camera and video modes each own a `BallDetectionManager`; both use the freshest GridTrackNet output index (`t = 4`) for overlays and all five timestamped samples for cue detection.
- `Tennis Trainer/Detectors/GridTrackNetDetector.swift` uses five RGB frames on a 768×432 model canvas. Portrait frames use aspect-fit to retain the toss arc; other source shapes use aspect-fill. Coordinates are mapped back to the oriented source frame.
- Vision provides body joints and a nose/neck baseline for the toss height gate. Normalized analysis coordinates have a bottom-left origin.
- The current cue confirms a local vertical maximum, applies confidence and height gates, and enforces a four-second cooldown. These are the starting behavior, not newly measured reliability guarantees.
- The color/Kalman detector is a fallback; the active serve cue depends on the GridTrackNet sample stream.

### Evidence motivating this milestone

The codebase map in `.planning/codebase/` was committed as `bc68dcc`. These findings describe the pre-Phase 1 baseline. Phase 1 fixed prediction association, pre-dispatch admission and manager generation guards with deterministic tests. Complete control-transition integration, visible alignment and empirical measurements remain later-phase obligations:

- Prediction and its timestamp/mapping metadata are captured in separate synchronized operations, allowing them to describe different frame windows.
- The `isInFlight` flag is set and cleared inside a serial queue's submitted closure, so it does not bound pending requests. Prediction also shares synchronization with frame preprocessing.
- Queued inference and main-thread callbacks lack a session generation that invalidates results after reset or mode transitions.
- Overlay placement uses full view bounds without consistently accounting for the AV layer's rendered image rectangle.
- The displayed camera permission button has an empty action; natural video completion is not observed; copied temporary videos lack explicit ownership cleanup.
- Existing automated tests concentrate on the apex algorithm. Model decoding, geometry, lifecycle transitions, and realistic end-to-end cue timing lack regression coverage.

See `.planning/codebase/CONCERNS.md` for supporting file references and `.planning/codebase/TESTING.md` for test organization.

### Phase 1 acceptance

Phase 1 completed on 2026-09-26 with 3/3 plans, 12/12 deterministic verification truths and all four CUE requirements accepted. The user separately passed the evidence-limit, frame-association and pose-fallback reviews in `.planning/phases/01-consistent-toss-cues/01-UAT.md`. The bundled model and preprocessing are unchanged; both production media adapters are covered through the cue callback. No representative clips, physical device trials, sustained process-memory measurement or physical audio timing were added by those reviews.

### Validation approach and unresolved measurements

Use deterministic tests for frame/result association, stale callback rejection, geometry, and cue state. Use repeatable short serve clips to inspect missed, extra, and delayed cues, followed by real-device live-camera checks under the supported setup.

No representative clip set, baseline accuracy, measured end-to-end audio latency, device matrix, or numeric acceptance threshold has been established in this workflow. Define those during requirements/research and phase planning before declaring reliability verified. The PRD's frame-interval estimate is not a measured capture-to-audio latency result.

### Product and repository references

- `README.md` and `PRD.MD`: product intent and current behavior.
- `ARCHITECTURE.md` and `docs/README.md`: runtime overview and knowledge map.
- `GRIDTRACKNET_COREML.md`: model conversion and decoding reference.
- `AGENTS.md` and `LEARNINGS.md`: repository rules and observed project-specific constraints.
- No root `*_IMPL.md` brief was present during mapping; this initialization does not imply an existing execution plan.

## Constraints

- **Platform:** Keep the SwiftUI iPhone application and existing Apple-framework stack, with the currently configured iOS 18.5 deployment target.
- **Practice setup:** Portrait phone on a tripod, right-handed solo server, full body and toss arc visible; retain the current recommended side-on setup.
- **Privacy:** Process camera frames, selected videos, pose, and ball detections locally.
- **Compatibility:** Preserve target/folder names, bundle identity, and working behavior outside the reliability scope.
- **Architecture:** Keep cue algorithms in detectors, runtime I/O in managers, and composition/presentation in views. Preserve `BallDetectionManager` as the ball/cue integration boundary.
- **Responsiveness:** Keep capture-session lifecycle separate from frame analysis; make pause/stop/reset effective immediately for future feedback.
- **Model contract:** Preserve temporal order, per-tensor strides, FP16 decoding, and orientation/source-coordinate mapping; verify these boundaries when refactoring.
- **Verification:** Synthetic tests alone cannot establish live cue accuracy or perceived beep latency. Report unperformed device/clip checks explicitly.

No deadline, budget, or specific test-device requirement has been provided.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Map the existing code before initializing GSD | Distinguish implemented behavior from new scope and unverified assumptions | ✓ Map completed and committed |
| First milestone is toss-apex reliability in both live and playback modes | User selected reliability and approved the proposed scope | ✓ Phase 1 complete; Phases 2–4 pending |
| Keep portrait, right-handed solo practice | Limit variables while making the current cue dependable | — Retained constraint |
| Defer additional serve cues and other strokes | Build on a dependable timing and geometry foundation | — Deferred |
| Combine regression tests, repeatable clips, and device validation | Code inspection and synthetic tosses do not prove full-pipeline behavior | — Validation work pending |
| Organize phases around complete user outcomes (MVP mode) | User approved vertical delivery and all 17 reliability requirements on 2026-09-25 | — Four-phase roadmap approved |
| Hold one admission lease through final publication and generation-check each effect | Prevent queued work and synchronous callback resets from leaking stale effects | ✓ Adversarial manager tests pass; full control wiring remains Phase 2 |
| Preserve original owned windows and exact candidate pose | Newer input and overlay pose must not rewrite a prediction's evidence | ✓ Deterministic tests and user contract reviews pass |
| Keep first-consumed identity estimates authoritative with bounded history | Overlapping windows must not replay or revise consumed cue evidence | ✓ Rational-time and replay tests pass; real sampling impact remains Phase 4 |
| Separate app-buffer counts and callback evidence from device/audio claims | Framework allocations and physical sound require different measurements | ✓ Evidence limits accepted in human UAT; empirical work remains pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

After each phase transition:
1. Move invalidated requirements to Out of Scope with a reason.
2. Move verified requirements to Validated with the phase and evidence.
3. Add newly discovered requirements to Active.
4. Record decisions and their observed outcomes.
5. Update What This Is if product reality changes.

After each milestone:
1. Review all sections and confirm the Core Value still guides priorities.
2. Revisit exclusions and their reasons.
3. Update Context with shipped behavior, measurements, and user feedback.

---
*Last updated: 2026-09-26 after Phase 1 verification and human UAT*
