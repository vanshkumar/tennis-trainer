# Requirements: Tennis Trainer

**Defined:** 2026-09-24
**Status:** Requirements and roadmap mappings approved 2026-09-25
**Milestone:** Toss-apex reliability in live camera and saved-video playback
**Core Value:** A player can trust the toss-apex beep to correspond to the current toss, without stale or duplicate feedback interrupting practice.

## v1 Requirements

Here, v1 means the first GSD reliability milestone in this existing application. It does not imply these are all new product capabilities.

### Current-Toss Feedback

- [x] **CUE-01**: A player's ball result and apex cue use the same source frames, timestamps, and geometry that produced the prediction.
- [x] **CUE-02**: A player can use analysis without an accumulating backlog of old feedback; processing has a tested finite work/buffer bound.
- [x] **CUE-03**: A player receives at most one automatic cue for an eligible toss, even when source frames repeat or inference windows overlap.
- [x] **CUE-04**: A player's toss height gate uses pose associated with that toss sample, or the documented fallback when valid pose is unavailable.

### Session Transitions

- [ ] **LIFE-01**: After Stop, Pause, seek, clip replacement, completion, or mode exit, no invalidated work can publish an overlay or schedule a new automatic beep.
- [ ] **LIFE-02**: Starting or resuming analysis after a reset builds a fresh temporal window and cannot issue a retrospective cue from the previous session or timeline.

### Overlay Alignment

- [ ] **VIEW-01**: A player sees ball and pose overlays aligned with the live preview, including its orientation and aspect-fill crop.
- [ ] **VIEW-02**: A player sees ball and pose overlays aligned with the actual displayed area of portrait, landscape, and rotated source clips inside the portrait app UI.

### Camera Access and State

CAM-01/02 checkboxes record completed implementation and passing automated checks in 02-02. Physical permission/Settings, startup/interruption/Stop/recovery and Phase 2 human acceptance remain pending under the user's explicit end-of-phase timing decision; these are not hardware acceptance marks.

- [x] **CAM-01**: A player can request camera access when undetermined, reach Settings when denied, understand restricted access, and have access rechecked on return.
- [x] **CAM-02**: A player sees the actual capture state and can stop safely during startup, interruption, or recovery without a later completion restarting analysis against their intent.

### Saved-Video Controls

- [x] **PLAY-01**: A player can seek repeatedly, and only the latest successfully completed seek can resume analysis if playback is still requested.
- [x] **PLAY-02**: A player sees an ended state when a clip finishes and can replay from the beginning with fresh tracking and cooldown state.
- [ ] **PLAY-03**: A player can replace a clip or recover from a failed/cancelled import without an old load or callback taking over the current selection.
- [ ] **PLAY-04**: A player can repeatedly play and replace clips without accumulating duplicate processing loops or orphaned app-owned video copies; externally owned files are preserved.

### Verification Evidence

- [ ] **CHECK-01**: Maintainers can run deterministic regression checks for frame/result association, bounded work, stale-result rejection, cue behavior, decoding, geometry, and lifecycle transitions.
- [ ] **CHECK-02**: Maintainers can rerun a versioned labeled clip set and review missed, extra, duplicate, and stale cues plus timing results under matching rules and acceptance bounds frozen before final scoring.
- [ ] **CHECK-03**: Maintainers can review real-device evidence for live practice and playback, including control responsiveness, sustained operation, and physical beep timing, with device/build/audio-route details and any missing checks explicit.

## Acceptance Notes

- An eligible toss is fully observed under the supported setup and the current confidence/height/cooldown policy. Preserve the existing four-second cooldown initially; it is separate from deduplicating overlapping input. Any later tuning requires evidence and recorded settings.
- Pausing/seeking mid-toss may leave insufficient new samples to confirm an apex. Fresh-window warmup must not create a retrospective cue; record partial/ambiguous tosses separately from fully observed eligible tosses.
- LIFE-01 prevents scheduling new automatic feedback from invalidated work. Sound already physically emitted cannot be undone. The explicit Test Beep action is distinct from automatic detector cues and excluded from scoring.
- CUE-02 requires an explicitly selected finite admission/retention policy and adversarial burst tests. It does not promise a particular analyzed FPS or latency before measurement.
- CUE-04 requires frame/time/source association and explicit missing pose. A confidence score alone does not establish pose freshness. Any time-tolerance policy must be specified and verified.
- VIEW requirements cover model-to-source conversion and source-to-display placement separately. Preserve the current portrait-fit preprocessing unless a deliberate, verified change is approved; do not accidentally change it while fixing display geometry.
- PLAY-01 must treat superseded/cancelled seek completions as ineligible to reopen analysis. Clip/load identity must also protect asynchronous metadata updates.
- PLAY-04 applies ownership-aware, unique temporary copies and explicit teardown of display links, observers, and outputs. It does not authorize deletion of original user media.
- CHECK-02 begins with an evaluation protocol and baseline acquisition early in the milestone. Label apex intervals and ambiguity, declare cooldown eligibility, record source format/timebase and detector settings, and separate tuning from confirmation cases when available.
- Numeric accuracy, overlay-error, freshness/gap, and audible-latency bounds are not established by this draft. Propose and record them from baseline evidence before the final verification run; report counts, denominators, measurement uncertainty, and pass/fail against the frozen bounds.
- CHECK-03 distinguishes software callback/scheduling time from physical sound onset. Use documented audiovisual synchronization on a real supported iPhone; unavailable hardware or audible timing remains a pending gate, not an implied pass.

## v2 Requirements

Deferred improvements to consider only after evidence supports their value:

- **GUIDE-01**: A player can review concise setup guidance for the supported body/toss framing.
- **AUDIO-01**: A player can identify the active audio route alongside the manual beep check.
- **REVIEW-01**: A maintainer can inspect a richer local diagnostic report in the app rather than relying on developer evidence artifacts.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Trophy/contact cues and other strokes | User chose to stabilize the existing toss-apex cue first |
| Left-handed, multi-player, and rally support | Retain current right-handed solo-practice scope |
| Landscape app UI | Preserve portrait UI; imported media geometry remains in scope |
| Cloud uploads, accounts, telemetry services | Preserve on-device processing and current privacy model |
| Planned model replacement or retraining | First separate pipeline errors from demonstrated model limitations |
| User-adjustable detector thresholds and cooldown | Keep evaluation repeatable; tuning follows evidence rather than adding controls |
| UI redesign, OS-target upgrade, or framework migration | Not required to deliver the approved reliability behavior |

## Traceability

Each v1 requirement maps to exactly one owning phase in the approved roadmap; other phases may exercise its integration. Regression tests accompany implementation, while Phase 4 owns complete CHECK-01 verification. Evaluation protocol and baseline acquisition begin in Phase 1, while Phase 4 owns final CHECK-02 acceptance.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CUE-01 | Phase 1 | Complete |
| CUE-02 | Phase 1 | Complete |
| CUE-03 | Phase 1 | Complete |
| CUE-04 | Phase 1 | Complete |
| LIFE-01 | Phase 2 | Pending |
| LIFE-02 | Phase 2 | Pending |
| VIEW-01 | Phase 3 | Pending |
| VIEW-02 | Phase 3 | Pending |
| CAM-01 | Phase 2 | Complete |
| CAM-02 | Phase 2 | Complete |
| PLAY-01 | Phase 2 | Complete |
| PLAY-02 | Phase 2 | Complete |
| PLAY-03 | Phase 2 | Pending |
| PLAY-04 | Phase 2 | Pending |
| CHECK-01 | Phase 4 | Pending |
| CHECK-02 | Phase 4 | Pending |
| CHECK-03 | Phase 4 | Pending |

**Coverage:**

- v1 requirements: 17 total
- Mapped to phases: 17
- Unmapped: 0

## Basis

- User-approved scope in `PROJECT.md` (2026-09-24).
- Static code map in `codebase/`; findings are not claims of reproduced device failures.
- Primary-source research synthesized in `research/SUMMARY.md`.

---
*Requirements defined: 2026-09-24*
*Last updated: 2026-09-26 after CUE-01 through CUE-04 passed Phase 1 verification and human UAT*
