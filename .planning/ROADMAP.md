# Roadmap: Tennis Trainer

## Overview

Make the existing toss-apex cue dependable in both live-camera practice and saved-video review. First establish consistent feedback from correctly associated frames and pose data, then make session controls trustworthy, align visible tracking with the displayed image, and verify the combined behavior with repeatable clips and real-device evidence. Each phase delivers an observable outcome in the existing app and includes its own regression checks.

**Milestone:** Toss-apex reliability
**Status:** Phase 1 planned 2026-09-25; ready to execute
**Structure:** Coarse, vertical MVP phases; preserve portrait, right-handed solo practice and on-device processing.

## Phases

- [ ] **Phase 1: Consistent Toss Cues** - Associate each cue with its actual frames and pose, without duplicate events or accumulating inference work.
- [ ] **Phase 2: Dependable Practice Controls** - Stop, recover camera access, seek, replay, and replace clips without stale feedback or incorrect state.
- [ ] **Phase 3: Accurate Visible Tracking** - Align ball and pose overlays with the actual live preview and imported-video image.
- [ ] **Phase 4: Verified Practice Reliability** - Establish repeatable regression, clip, and device evidence against criteria fixed before final scoring.

## Phase Details

### Phase 1: Consistent Toss Cues

**Goal:** A player receives consistent toss feedback tied to the frames and body pose being analyzed in either mode.
**Mode:** mvp
**Depends on:** Nothing (first phase)
**Requirements:** CUE-01, CUE-02, CUE-03, CUE-04
**Success Criteria** (what must be TRUE):

1. A recorded result can be traced to the exact source frames, timestamps, and geometry used for its prediction, including when newer frames arrive before the result is delivered.
2. Submitting frames faster than they can be analyzed cannot grow pending work or retained buffers beyond the documented finite bound; obsolete pending work does not accumulate into a stream of late cues.
3. A fully observed eligible toss produces at most one automatic cue when timestamps repeat or five-frame windows overlap; the existing cooldown remains a separate eligibility rule.
4. Delaying or removing pose observations cannot substitute a newer or stale body position for the toss sample's height gate; the corresponding valid pose or documented fallback determines the result.

**Plans:** 3/3 plans executed across 3 sequential waves
**Wave 1**

- [x] 01-01-PLAN.md

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-03-PLAN.md

Planning notes:

- Complete these behaviors through the existing live and playback paths, including the cue callback, rather than stopping at an isolated detector refactor.
- Add deterministic fixtures for input/output association, bounded admission, temporal overlap, pose association, and model decoding while changing those boundaries.
- Establish session/source identity and test seams here; Phase 2 owns complete integration and acceptance of every stop/reset/control transition.
- Begin the evaluation protocol, permitted-clip inventory, and baseline collection before tuning. Keep a reproducible pre-change reference where measurements cannot be collected immediately. Phase 4 owns final CHECK-02 acceptance.
- Keep the bundled model, current preprocessing, and five-frame ordering stable. Identify and test irregular sampling rather than inventing a fixed analyzed FPS guarantee.

### Phase 2: Dependable Practice Controls

**Goal:** A player can control live practice and saved-video review without old work producing feedback or taking over the current session.
**Mode:** mvp
**Depends on:** Phase 1
**Requirements:** LIFE-01, LIFE-02, CAM-01, CAM-02, PLAY-01, PLAY-02, PLAY-03, PLAY-04
**Success Criteria** (what must be TRUE):

1. Stop, Pause, seek, clip replacement, completion, and mode exit prevent invalidated worker results and already queued publication callbacks from updating overlays or scheduling a new automatic beep; a new session warms up from fresh samples without retrospective feedback.
2. The camera access control requests undetermined access, offers Settings recovery when denied, explains restriction, and rechecks on return; capture state reflects actual startup/running/interruption/failure and honors Stop even when an earlier start or recovery finishes later.
3. Repeated seeks only resume analysis after the latest successful completion and only while playback remains requested; reaching the end stops processing, and Replay begins at the start with fresh tracking and cooldown state.
4. Rapid clip replacement, cancellation, and failed loads leave the current selection usable; late metadata, seek, notification, and detection completions from old items cannot change its state.
5. Repeated play/pause/replacement cycles maintain only the intended active processing loop and release retired outputs, observers, display links, and app-owned video copies without deleting original or externally owned media.

**Plans:** TBD
**UI hint:** yes

Planning notes:

- Treat lifecycle invalidation as immediate user intent; asynchronous teardown or an uncancellable prediction may finish without being allowed to publish effects.
- An already audible beep is distinct from newly scheduled stale feedback. Preserve the explicit manual Test Beep action.
- Add adversarial completion-order tests and UI/state checks alongside the permission and player changes. Complete the supported deny → Settings → return path on hardware when available, recording any pending check.

### Phase 3: Accurate Visible Tracking

**Goal:** A player can trust that the displayed ball and pose markers identify the corresponding locations in the camera preview or selected video.
**Mode:** mvp
**Depends on:** Phase 1, Phase 2
**Requirements:** VIEW-01, VIEW-02
**Success Criteria** (what must be TRUE):

1. Ball and pose markers share a verified source-to-display transform in live preview, including orientation, origin conversion, and aspect-fill cropping; cropped points are not presented as valid on-screen markers.
2. Portrait, landscape, and rotated video sources display markers inside the actual rendered image rectangle, with fit padding and layout changes accounted for rather than scaling into the entire container.
3. Corner, center, and known-point fixtures pass separately through model-to-source and source-to-display conversion, and actual AV-layer integration checks confirm the same placement after layout and clip changes.

**Plans:** TBD
**UI hint:** yes

Planning notes:

- Preserve the portrait app UI. Landscape source clips are supported media geometry, not a landscape UI expansion.
- Preserve current portrait-fit/nonportrait-fill model preprocessing unless a deliberate validated change is separately approved; reconcile the older blanket aspect-fill note through fixtures.
- Define measurable placement tolerances before evaluating the final fixtures and clips. Phase 4 reruns the full set with the final build.

### Phase 4: Verified Practice Reliability

**Goal:** A maintainer can make an evidence-based release decision about toss feedback in both supported modes.
**Mode:** mvp
**Depends on:** Phase 1, Phase 2, Phase 3
**Requirements:** CHECK-01, CHECK-02, CHECK-03
**Success Criteria** (what must be TRUE):

1. One documented regression run covers frame/result association, finite work bounds, stale-result rejection, cue behavior, decoding, geometry, and lifecycle transitions, using the tests developed alongside earlier phases.
2. A versioned labeled clip set can be rerun with fixed matching rules, detector settings, and eligibility labels; its report identifies missed, extra, duplicate, and stale cues with counts, denominators, timing, ambiguity, and measurement uncertainty.
3. Accuracy, geometry, freshness/gap, and audible-latency acceptance bounds are recorded before final scoring; the final report states pass/fail against them without substituting the PRD's frame-interval estimate for measured latency.
4. Real-device live and playback trials cover sustained practice and control transitions, and distinguish software scheduling time from physical beep onset while recording device, OS, build, audio route, setup, and synchronization uncertainty.
5. Every required check has evidence or is explicitly outstanding. The milestone is not declared verified while required device/audio/clip evidence or an acceptance failure remains unresolved.

**Plans:** TBD

Planning notes:

- This phase consolidates and reruns earlier regression evidence; it does not postpone writing correctness tests until the end.
- Baseline acquisition and protocol work start in Phase 1. Freeze the final criteria and confirmation cases before final verification, without tuning the criteria to make the results pass.
- Device availability, labeled clips, and physical audio measurement are validation dependencies, not assumed resources. Their absence does not block deterministic fixes in earlier phases, but cannot count as a pass here.
- Keep evidence local; no cloud telemetry, new coaching cues, or model retraining is included.

## Coverage

All 17 approved v1 requirements map to exactly one owning phase. Cross-phase integration and regression checks do not create duplicate ownership.

| Phase | Requirement count | Requirements |
|-------|-------------------|--------------|
| 1. Consistent Toss Cues | 4 | CUE-01, CUE-02, CUE-03, CUE-04 |
| 2. Dependable Practice Controls | 8 | LIFE-01, LIFE-02, CAM-01, CAM-02, PLAY-01, PLAY-02, PLAY-03, PLAY-04 |
| 3. Accurate Visible Tracking | 2 | VIEW-01, VIEW-02 |
| 4. Verified Practice Reliability | 3 | CHECK-01, CHECK-02, CHECK-03 |

**Mapped:** 17/17. **Unmapped:** 0. **Duplicate ownership:** 0.

## Progress

**Execution Order:** 1 → 2 → 3 → 4. Independent plans within a phase may run in parallel after their dependencies are known. Detailed plan counts are determined by `$gsd-plan-phase`.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Consistent Toss Cues | 3/3 | In Progress|  |
| 2. Dependable Practice Controls | 0/TBD | Not started | - |
| 3. Accurate Visible Tracking | 0/TBD | Not started | - |
| 4. Verified Practice Reliability | 0/TBD | Not started | - |

---
*Created and approved: 2026-09-25*
