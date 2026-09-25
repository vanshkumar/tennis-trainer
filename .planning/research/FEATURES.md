# Feature Research

**Domain:** On-device iPhone serve-toss cue reliability, live camera and saved video
**Researched:** 2026-09-24
**Confidence:** MEDIUM — official platform behavior is verified; product priorities and acceptance recommendations below are project-specific inferences, not user-study results.

This is a reliability milestone for an existing product. `.planning/PROJECT.md` defines the approved scope; PRD timing and single-flight statements are intentions, not measured guarantees. Preserve portrait, right-handed solo practice, the bundled model, and local processing.

## Feature Landscape

### Table Stakes (Required Reliability Behaviors)

All priorities and complexity estimates are **MEDIUM-confidence project inferences** from PROJECT.md and the codebase maps. Complexity includes verification, not just the visible control.

| Feature | Why Expected | Complexity | Acceptance behavior / dependencies |
|---------|--------------|------------|------------------------------------|
| Cue belongs to the current toss | A beep from an earlier run undermines the core value | HIGH | Frame pixels, source timestamps, geometry, and result identity stay associated; pose used for gating must have an explicit freshness policy |
| Responsive Stop/Pause and mode changes | A control must end active feedback when accepted | HIGH | Invalidate old work at the transition; no new automatic cue or overlay update from it, including callbacks already queued for UI/audio delivery |
| No duplicate cue from overlapping windows | One toss must not sound like several tosses | MEDIUM | Repeated source timestamps and overlapping five-frame outputs cannot create duplicate events; retain the current four-second cooldown pending evidence |
| Correct ball and pose placement | Players use overlays to check whether the app tracks their toss | HIGH | Both overlays align to the displayed source image through orientation, fit padding, and fill cropping; check portrait and landscape source clips in portrait UI |
| Working camera access recovery | The current permission control must perform a useful action | MEDIUM | Request once when undetermined; show Settings recovery when denied; explain restricted access; recheck on return; do not claim capture is running without authorization [A1, A2] |
| Truthful capture status | Start, interrupted, and running are different states | MEDIUM | Controls/HUD reflect actual startup, running, stopped, interruption, and failure; user Stop prevents a later asynchronous start/recovery from reactivating analysis [A3] |
| Predictable playback and seeking | Reviewing the same serve should not inherit unrelated tracking history | HIGH | Pause suppresses feedback; seek discards the previous timeline; only the latest successful seek can resume analysis; use media time for sample identity [A4] |
| Completion and replay | Reaching the end must not look like ongoing playback | MEDIUM | Current item completion stops frame polling and analysis, updates controls, and offers Replay; replay resets tracking and cooldown so the same toss can be evaluated again [A5] |
| Safe clip replacement and recoverable import failure | Choosing a new clip should not produce old cues or strand controls | MEDIUM | Retired-item results/notifications are ignored; selected app-owned copies are cleaned up on replacement/disposal; cancellation and failure retain a usable state |
| Repeatable evidence for both modes | A working synthetic detector does not establish a dependable live cue | HIGH | Deterministic transition/geometry tests plus labeled clips and device runs; report missed, extra, duplicated, stale, and late cues separately |

### Differentiators / Optional Improvements

These are optional improvements within the same cue, not claims of competitive advantage.

| Feature | Value Proposition | Complexity | When to Include |
|---------|-------------------|------------|-----------------|
| Brief setup reminder | Reminds users to keep full body and toss arc visible in supported side-on framing | LOW | Add if validation reveals repeated setup mistakes; no new camera-placement modes |
| Minimal tracking-unavailable indication | Explains why no cue is possible when frames/model results are unavailable | MEDIUM | Add only with an honest state source; do not present detector confidence as calibrated cue correctness |
| Local diagnostic clip report | Speeds comparison of the same clips between builds | MEDIUM | A developer-facing evidence artifact is useful now; a polished in-app report is optional |
| Audio route hint beside Test Beep | Helps a player notice that feedback is going to an unexpected output | MEDIUM | Add if physical-device checks reveal route confusion; keep broader audio customization deferred |

### Anti-Features / Out of Scope

| Feature | Why It Seems Attractive | Why Avoid This Milestone | Alternative |
|---------|-------------------------|--------------------------|-------------|
| Trophy/contact cues or other strokes | Adds more coaching feedback | Expands event definitions before existing timing is trustworthy | Stabilize toss-apex only |
| Left-handed, multi-player, rally, landscape UI support | Broadens usability | Adds unapproved detection and presentation cases | Validate current right-handed solo setup; support imported clip geometry |
| Cloud analytics, uploads, accounts | Centralizes diagnostics | Adds infrastructure and changes the local privacy model | Local evidence files and opt-in local fixtures |
| Model replacement/retraining | May improve raw tracking | Cannot establish whether current failures come from pipeline or model | Measure the current model after synchronization fixes; escalate demonstrated model limits separately |
| User-adjustable confidence/cooldown controls | Appears to offer a quick tuning fix | Hides regressions behind per-user settings and weakens repeatability | Version the existing detector settings in the evaluation record |
| Guaranteed latency based on source FPS | Gives a simple performance claim | Frame interval omits capture, scheduling, inference, confirmation, and audio delay | Measure software timing and audible timing independently |

## Feature Dependencies

```text
Current-toss cues -> require immutable frame/time/geometry association
No stale feedback -> requires bounded admission + session/timeline invalidation
Correct overlays -> require source-space transforms + displayed-image rectangle
Seek/replay/replacement -> require timeline reset + current-item ownership
Trustworthy clip metrics -> require event tracing + labeled fixtures + matching rules
Live timing acceptance -> requires physical device + calibrated audio observation
```

### Dependency Notes

- Build shared association and invalidation seams before wiring separate camera and player recovery behavior; both modes need the same rejection rules.
- Establish evaluation protocol and acquire fixtures early; run final measurements after pipeline/lifecycle/geometry changes so results describe the shipped behavior.
- Cooldown is an existing eligibility rule, not proof of deduplication. Test overlapping windows independently of cooldown; annotate close successive tosses as policy-suppressed rather than silently counting them as misses.
- Pausing/seeking mid-toss may leave insufficient continuous samples after resume. Recommend fresh-window warm-up and no retrospective beep; distinguish this from a missed fully observed toss in acceptance records.

## Milestone Definition

### Complete This Milestone With

- [ ] Current-session, correctly associated detections and bounded pending work in both modes.
- [ ] No new automatic beep from invalidated work after Stop, Pause, seek, replacement, completion, or mode switch; explicitly distinguish an already audible beep finishing from a newly scheduled stale beep.
- [ ] Geometry-correct overlays, actionable permission recovery, actual capture status, and dependable playback/replay controls.
- [ ] A repeatable validation package with test outcomes, clip annotations, device/OS/build details, measurement definitions, and honestly reported pending checks.

### Add After Validation

- [ ] Setup guidance or route hints when actual failures justify them.
- [ ] A richer local review interface only if the basic clip workflow impedes reliability evaluation.

### Future Consideration

Keep new cues, handedness, strokes, cloud systems, and retraining outside this roadmap. Any observed limitation becomes an explicit follow-up decision, not silent milestone expansion.

## Expected Controls and Transition Checks

These are recommended product contracts, not claims that the current implementation passes them.

| Scenario | Expected User-Visible Result | Verification |
|----------|-----------------------------|--------------|
| First camera use; deny; return from Settings | A useful access action and accurate state; saved-video mode remains available | Exercise each authorization state; verify recheck and grant/revoke recovery [A1, A2] |
| Stop during inference, then Start | Old overlays clear; old work cannot beep; new run warms up normally | Delay inference and UI delivery deliberately, cross the boundary, then release callbacks |
| Camera interruption / background and return | Show unavailable/stopped state; invalidate old feedback; recommend explicit Start to resume | Simulated state events plus real-device interruption/background checks [A3] |
| Pause, scrub repeatedly, resume | No automatic beeps while paused/seeking; only final timeline contributes after resume | Complete seeks out of order, including `finished == false`; inspect event identities [A4] |
| Natural end and Replay | End state replaces Playing; Replay starts from beginning without prior-run cooldown | End notification from current versus retired items; repeat the same clip [A5] |
| Replace clip or cancel picker | Accepted replacement starts clean; cancellation preserves the previous clip in a usable paused state | Late import/result/notification delivery cannot overwrite current selection |
| Test Beep | Deliberate audio check remains distinct from detector feedback | Tag manual versus automatic requests; exclude manual beep from cue-quality metrics |

## Clip and Device Evaluation Strategy

The following is a **MEDIUM-confidence proposed protocol**. No labeled corpus, device availability, numeric accuracy target, or latency budget is established yet.

1. **Create the evidence set:** obtain permitted local short clips; record file identity, orientation, dimensions, source frame timestamps/rate, framing, and expected toss count. Include ordinary complete serves, no-toss intervals, low/occluded ball visibility, portrait and landscape media, and repeated tosses. Professional footage is useful for regression but does not substitute for the supported tripod practice setup.
2. **Label before scoring:** manually mark an apex frame or plausible apex interval and whether each toss is fully observed and eligible under the documented cooldown. Record ambiguous/occluded cases separately. Set a one-to-one event matching window from annotation uncertainty and intended feedback tolerance before the final run; do not tune it to make results pass.
3. **Separate tuning from confirmation:** keep some clips or sessions unused during fixes/tuning when available; freeze labels, settings, and matching rules before evaluating them. Small convenience samples establish regression evidence, not population-wide accuracy.
4. **Score observable events:** report matched eligible tosses/eligible tosses, unmatched automatic cues, duplicate cues, and stale cues after transitions, with raw counts and denominators. Report cue-to-labeled-apex timing distributions with sample count and uncertainty; disclose sparse samples instead of implying precise tail estimates.
5. **Separate clocks and endpoints:** preserve media/capture timestamps for apex localization; record monotonic times for admission, inference, decision, and audio scheduling. A signposted software interval is not audible latency [A6]. For playback, distinguish detected apex location on the clip timeline from delay relative to the displayed apex.
6. **Measure audible timing on hardware:** select an available supported iPhone and record its model, iOS version, build/configuration, actual capture rate, audio route, warm-up, and thermal/session conditions. Use a synchronized audiovisual observation of toss/apex and audible beep with documented synchronization uncertainty; if unavailable, report only software timing and leave audible latency unverified.
7. **Exercise both usage modes:** rerun reference clips and perform live serves in the supported setup, including Start/Stop, switching, foreground/background, replay, and repeated imports. Include a sustained practice run to expose growing queues or resource use. Expand to an older supported device if available; do not imply a device matrix was supplied.
8. **Define release bounds from evidence:** require deterministic lifecycle/association/geometry invariants to pass; propose accuracy, overlay tolerance, and latency bounds after baseline collection and lock them before final verification. Use realistic performance configuration and repeated runs [A7]. Simulator checks are useful for logic/UI; physical performance still requires hardware [A8].

The PRD's approximately 16–33 ms at 60 fps is a sample-interval estimate, not measured capture-to-speaker latency. Missing clips/device evidence leaves the empirical acceptance gate pending; it does not prevent implementing deterministic reliability fixes.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Association, stale-feedback rejection, bounded work | HIGH | HIGH | P1 |
| Crop/fit/orientation-correct overlays | HIGH | HIGH | P1 |
| Permission/capture and playback lifecycle recovery | HIGH | MEDIUM | P1 |
| Clip/device validation and evidence capture | HIGH | HIGH | P1 |
| Setup guidance, route hints, richer local reports | MEDIUM | LOW–MEDIUM | P2, evidence-triggered |

**Priority key:** P1 is required for this reliability milestone; P2 is optional after its core behavior is validated. Competitor feature comparison is intentionally omitted because the approved scope concerns existing behavior, not market expansion.

## Sources

Local scope/evidence: `.planning/PROJECT.md`, `PRD.MD`, `LEARNINGS.md`, `.planning/codebase/TESTING.md`, and `.planning/codebase/CONCERNS.md` (static map dated 2026-09-19; no runtime verification implied).

Official docs were checked 2026-09-24; pages do not expose publication dates. Confidence classification: GSD `query classify-confidence --provider websearch --verified` returned **MEDIUM**. The same tier applies to source-backed claims; product contracts above remain inferences.

- **A1:** [Apple — Requesting authorization to capture and save media](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media); cross-check [authorizationStatus(for:)](https://developer.apple.com/documentation/avfoundation/avcapturedevice/authorizationstatus(for:)).
- **A2:** [Apple — openSettingsURLString](https://developer.apple.com/documentation/uikit/uiapplication/opensettingsurlstring).
- **A3:** [Apple — Capture session interruption notification](https://developer.apple.com/documentation/avfoundation/avcapturesession/wasinterruptednotification); cross-check [AVCaptureSession state](https://developer.apple.com/documentation/avfoundation/avcapturesession).
- **A4:** [Apple — Seek completion and interruption](https://developer.apple.com/documentation/avfoundation/avplayeritem/seek(to:completionhandler:)-91gnw).
- **A5:** [Apple — Player item completion notification](https://developer.apple.com/documentation/avfoundation/avplayeritem/didplaytoendtimenotification).
- **A6:** [Apple — XCTOSSignpostMetric](https://developer.apple.com/documentation/xctest/xctossignpostmetric).
- **A7:** [Apple — Writing and running performance tests](https://developer.apple.com/documentation/xcode/writing-and-running-performance-tests).
- **A8:** [Apple — Running on simulated or physical devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices); cross-check [Improving app responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness).
