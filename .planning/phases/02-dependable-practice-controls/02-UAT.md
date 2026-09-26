---
status: testing
phase: 02-dependable-practice-controls
source: [02-VERIFICATION.md]
started: 2026-09-26T17:07:00.272Z
updated: 2026-09-26T17:07:00.272Z
---

## Current Test

number: 1
name: Physical permission and Settings recovery: on a supported iPhone record device/OS/build, request undetermined access, deny then Open Settings, grant and return, revoke and return, and inspect available restriction cases.
expected: |
  One OS request; denied access opens system Settings; grant alone stays stopped until explicit Start; revocation closes capture; restriction explains the limitation without a misleading action. Unsupported scenarios remain explicit.
awaiting: user response

## Tests

### 1. Physical permission and Settings recovery: on a supported iPhone record device/OS/build, request undetermined access, deny then Open Settings, grant and return, revoke and return, and inspect available restriction cases.
expected: One OS request; denied access opens system Settings; grant alone stays stopped until explicit Start; revocation closes capture; restriction explains the limitation without a misleading action. Unsupported scenarios remain explicit.
result: [pending]
why_human: DEBUG permission controls and injected authorization snapshots do not exercise the OS permission/Settings boundary.

### 2. Physical capture and visible clearing: Start, Stop during startup, interrupt capture, Stop during recovery, foreground again, Retry, and switch modes; record actual preview/state and overlay outcomes.
expected: Status reflects actual hardware; Stop stays actionable and wins late completion; old overlays clear and do not replace active-mode presentation; return preserves stopped intent and explicit Retry can recover.
result: [pending]
why_human: Injected startup/notification ordering and seeded UI clearing prove software transitions, not real capture delivery, interruption timing or physical preview behavior.

### 3. Representative permitted-video review: select a real clip, play, scrub repeatedly, Pause while seeking, reach end, Replay, replace/cancel/fail an import, and leave/return to the mode.
expected: Only the current successful seek resumes under Play intent; Pause clears overlays; end stops processing; Replay begins at zero with fresh evidence; failed/cancelled replacement preserves the prior paused usable clip and originals survive.
result: [pending]
why_human: A generated one-second 64×64 movie and injected picker/player effects do not establish representative local-media user-flow acceptance.

### 4. EDGE-LIFE-01 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review.
expected: Human must classify the undefined edge or explicitly accept control-intent invalidation through both held stages and ingress races; deterministic tests do not resolve the unknown classifier row
result: [pending]
why_human: The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance.

### 5. EDGE-LIFE-02 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review.
expected: Human must classify/accept fresh-window and no-retrospective-cue semantics, including partial toss loss across reset
result: [pending]
why_human: The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance.

### 6. EDGE-CAM-02 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review.
expected: Human must classify/accept actual-state versus requested-intent and Stop dominance during startup/interruption/recovery; injected events alone do not establish hardware delivery
result: [pending]
why_human: The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance.

### 7. EDGE-PLAY-01 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review.
expected: Human must classify/accept latest successful current seek plus current play intent, including latest false completion and retry
result: [pending]
why_human: The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance.

### 8. EDGE-PLAY-02 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review.
expected: Human must classify/accept Ended, Replay zero-seek and fresh-window/cooldown semantics
result: [pending]
why_human: The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance.

### 9. EDGE-PLAY-03 — explicitly classify the original unclassified/unresolved edge or accept its stated contract during phase-end review.
expected: Human must classify/accept prior usable selection paused after failed/cancelled replacement and current-ready-candidate commit
result: [pending]
why_human: The canonical edge row has no defined executable probe. Tests support the authored predicate but cannot supply the missing human disposition; timing deferral is not acceptance.

### 10. Evidence-limit prohibition — review the phase verification and validation ledger, then explicitly resolve the retained transparency item.
expected: MUST NOT present injected lifecycle tests or software cue callbacks as proof of real camera permission recovery, physical capture behavior, clip accuracy, or audible timing.
result: [pending]
why_human: The projected prohibition remains status unresolved with no verification or enforcement descriptor. This report's scoped wording is a non-authoritative judge assessment, not human acceptance.

### 11. VoiceOver: traverse and adjust the playback position slider, inspect elapsed/total announcement and tracking-summary focus order, then clear tracking.
expected: Slider purpose/value and native adjustment are understandable; tracking is summarized once per active mode and disappears when cleared; controls remain reachable in a useful order.
result: [pending]
why_human: UI-tree assertions verify labels, values and absence; they do not observe spoken delivery or focus navigation on hardware.

### 12. Smallest supported portrait size and accessibility Dynamic Type: inspect Start/Stop/Retry, Play/Pause/Replay, Choose, Cancel and long failure messages.
expected: All essential controls and state text remain readable, operable and reachable without clipping or overlap.
result: [pending]
why_human: UI-05 remains a structural layout warning in a code-only audit; rendered fit at these sizes was not measured.

### 13. Light/dark and Increase Contrast: inspect enabled/disabled controls, slider/status text and overlays against bright and dark preview backgrounds; measure relevant contrast.
expected: Essential actions, status and disabled state remain distinguishable and legible under the inspected appearance settings.
result: [pending]
why_human: No screenshots or measured contrast results exist; native semantic colors and source review do not establish a visual pass.

## Summary

total: 13
passed: 0
issues: 0
pending: 13
skipped: 0
blocked: 0

## Gaps
