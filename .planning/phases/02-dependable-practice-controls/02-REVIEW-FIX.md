---
phase: 02-dependable-practice-controls
fixed: 2
skipped: 0
human_verification_required: true
updated: "2026-09-26"
---

# Phase 2 review fixes

| Finding | Resolution | Commit | Verification |
|---|---|---|---|
| CR-01 | Immutable production-only camera backend is initialized before preview/session access; injected construction omits it | d1af3ea | Backend identity and injected-construction tests plus source ownership proof; no physical race reproduction claimed |
| CR-02 | Replacement retires seek identity before Pause; prior clip becomes Paused while its unsettled target still requires a new successful seek | 792d728 | Held seek across cancellation, provider/metadata/readiness failures and stale completions, with positive fresh recovery; fixed: requires human verification |

The related UI-01 copy now identifies the preserved previous clip; empty-state Choose prompts remain. UI controls/accessibility are addressed in 8ba8451 and rechecked in UI-REVIEW.md.

Two targeted playback regressions first failed with assertions (exit 65), then the complete camera/player classes passed 51/51 with zero skips (exit 0). Raw temporary evidence: `/tmp/tennis-02-reviewfix-red.{log,xcresult}` and `/tmp/tennis-02-reviewfix-green.{log,xcresult}`. The final independent complete suites are recorded in the validation ledger and VERIFICATION report.

No findings were skipped or accepted as risk. Fixes ran on the existing authorized main checkout after the execution workflow's base-divergence isolation degradation. Final acceptance remains subject to phase UAT, including real-media behavior and physical camera checks.

Final independent source `212f17e`: Release passed; 149 units passed; full UI scheme passed 11 executions / 10 distinct tests; zero failures/skips. The intermediate overlay group regression is documented in the validation ledger and corrected by `212f17e`. Code re-review is clean; source-only UI recheck is 23/24 with one unmeasured layout recommendation.
