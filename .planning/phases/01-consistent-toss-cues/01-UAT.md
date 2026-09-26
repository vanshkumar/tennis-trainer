---
status: testing
phase: 01-consistent-toss-cues
source: [01-VERIFICATION.md]
started: 2026-09-26T04:52:25Z
updated: 2026-09-26T04:52:25Z
---

## Current Test

number: 1
name: Review the evidence ledger and transparency prohibition
expected: |
  The report accepts the tested limit of eight app-visible buffers per manager
  and sixteen across two managers. It leaves real clip accuracy, device behavior,
  framework/process memory and physical beep timing unmeasured. Review
  docs/references/toss-cue-validation.md and explicitly resolve the requirement
  that synthetic tests and callback times must not be presented as those measurements.
awaiting: user response

## Tests

### 1. Review the evidence ledger and transparency prohibition
expected: Review docs/references/toss-cue-validation.md against the source/model provenance and recorded test results. Accept only the scoped deterministic claims and retain all missing empirical evidence. Record an explicit decision on the prohibition against presenting synthetic cue counts, finite queue bounds or software callback times as measured real-toss accuracy or physical beep latency.
result: [pending]

### 2. Confirm the frame-association edge contract (EDGE-CUE-01)
expected: Confirm that the intended contract is to decode against the original five owned frames and their exact timestamps and geometry, even when newer input arrives or the original capture buffer is mutated. Held-prediction and source-mutation tests pass for that contract. Explicitly classify/resolve this previously unclassified item, or identify an additional edge case and its check; do not count an undefined probe as passed.
result: [pending]

### 3. Confirm the pose-association edge contract (EDGE-CUE-04)
expected: Confirm that pose must match the toss sample's source, generation and frame identity. Missing or mismatched pose uses the existing strict height fallback above 0.70; fixtures cue at 0.71 and suppress at 0.69/0.70. Explicitly classify/resolve this previously unclassified item, or specify the missing edge obligation and check; valid frame metadata must not be rejected just because pose is missing.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps

No deterministic implementation gaps were established. The independent build and complete shared-scheme test run passed (65 tests, zero failures/skips); 12/12 combined deterministic truths and CUE-01 through CUE-04 have evidence. These three human decisions remain pending and do not accept Phase 4 clip/device/audio requirements. Run `$gsd-verify-work 01` to record review outcomes and complete the required verification transition.
