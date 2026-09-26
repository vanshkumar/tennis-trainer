---
phase: "01"
slug: "consistent-toss-cues"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-09-25"
register_authored_at_plan_time: true
---

# Phase 1 — Security

Local native integrity and resource review against the twelve threats authored in the three phase plans. All twelve planned mitigations are present. This is the configured level-1 phase check, not a full ASVS certification, penetration test, or acceptance of the later lifecycle and empirical requirements.

## Trust Boundaries

| Boundary | Data crossing |
|----------|---------------|
| AVFoundation → managed analysis | Local media pixels, rational source times, source and generation identities |
| Shared Vision → frame values → publication | Body joints, optional candidate baseline, overlay values and cue callbacks |
| Prepared frames → prediction → samples | Owned pixels and one immutable five-frame metadata snapshot |
| Core ML storage → decoder | Three independently shaped and strided FP16 tensors |
| Samples → retained cue state | Candidate identity, rational time, finite geometry and associated pose |
| Execution evidence → reliability claims | Build/test results, source/model provenance and explicitly outstanding measurements |

## Threat Register

Paths below are relative to the repository root. Test references identify behavioral fixtures in the named suites.

| Threat ID | Category | Component | Severity | Disposition | Mitigation and evidence | Status |
|-----------|----------|-----------|----------|-------------|-------------------------|--------|
| T-01-01 | Denial of service | Frame admission/publication | high | mitigate | `BallDetectionManager.swift` reserves one lease before dispatch, drops busy input without retaining it, and holds the lease through publication. `BallDetectionManagerTests` covers held worker/publication bursts and two independent managers. | closed |
| T-01-02 | Tampering | Source time/reset/lease | high | mitigate | Manager admission validates numeric, monotonic CMTime and checked sequence identity. Publication rechecks generation after observable effects/callbacks; matching lease IDs protect release. Tests cover invalid time, sequence exhaustion, repeated reset, reset from track callbacks, teardown and double completion. | closed |
| T-01-03 | Tampering | Shared Vision request | medium | mitigate | `PoseDetectionManager.swift` locks the complete perform-and-extract operation and returns frame values; missing extraction clears published joints/angles. `PoseDetectionManagerTests` covers serialization and missing/low-confidence observations. | closed |
| T-01-04 | Information disclosure | Validation evidence/diagnostics | medium | mitigate | Manager diagnostics retain scalar saturating counts, not media or joint traces. `docs/references/toss-cue-validation.md` records a local permitted-media inventory as unavailable. Phase production changes add no payload logs or upload path. | closed |
| T-01-05 | Tampering | Window/sample association | high | mitigate | `AnalysisFrame.swift` unconditionally prepares app-owned pixels and validates five records. `GridTrackNetDetector.swift` uses the same snapshot for prediction and decoding. Manager fixtures mutate original pixels and hold prediction while newer frames arrive; decoded samples require original metadata. | closed |
| T-01-06 | Tampering | Candidate pose and identity | high | mitigate | Exact frame identity selects pose or explicit missing fallback. `ServeTossApexDetector.swift` stores the candidate's baseline and a monotonic consumption watermark surviving history eviction. Association/apex suites cover contrary and mismatched poses, overlap, reordering and replay after pruning. | closed |
| T-01-07 | Denial of service | Frame ring/cue history | high | mitigate | GridTrackNet retains five prepared records; apex retains at most three eligible entries with scalar watermarks and saturating counters. Dense-stream, burst, replay and retained-count fixtures cover these bounds. | closed |
| T-01-08 | Tampering | Numeric boundaries | medium | mitigate | Admission/window/sample validation rejects invalid source times and nonfinite geometry; ordering and cooldown use rational CMTime. Apex tests use exact integer timestamps around equality, horizon and 3,999/4,000/4,001 ms cooldown boundaries. | closed |
| T-01-09 | Tampering | Tensor decoding | high | mitigate | `GridTrackNetDecoder.swift` validates each head's dtype, supported axes, positive nonoverlapping strides and checked storage span inside scoped byte access; nonfinite values fail closed. Decoder tests cover malformed heads, independent padding, threshold/tie behavior, geometry and the real bundled-model layout. | closed |
| T-01-10 | Denial of service | Distinct buffers/publication | high | mitigate | Scoped preparation/prediction autorelease pools retire intermediates before publication. Weak-identity/destruction fixtures establish maxima of eight app-visible buffers per manager and sixteen across two managers, zero queued inputs, and terminal release; publication owns no tensors. These bounds exclude framework-private allocations. | closed |
| T-01-11 | Information disclosure | Local evidence | medium | mitigate | Evidence stays in local repository documents and local test bundles; permitted clips remain explicitly unavailable. The phase introduces neither remote services nor pixel/joint payload production logging. | closed |
| T-01-12 | Repudiation | Verification record | low | mitigate | Validation ledger preserves baseline source/model hashes, detector settings, test commands/counts and unmeasured items; software callback time is distinguished from physical sound onset. Summaries and independent gate record source-reviewed deterministic evidence without accepting Phase 4 criteria. | closed |

## Accepted Risks Log

No accepted risks. No missing mitigation was waived.

## Security Audit Trail

| Audit date | Threats total | Closed | Open | Run by |
|------------|---------------|--------|------|--------|
| 2026-09-25 | 12 | 12 | 0 | Execution orchestrator, source and test inspection |
| 2026-09-26 | 12 | 12 | 0 | Verify-work orchestrator: unchanged production/test diff; existing L1 controls retained; human evidence review passed |

Independent final gate at source HEAD `cddaebb`: `xcodebuild build` passed, and the complete shared-scheme test run passed 65 tests with zero failures or skips on iPhone 17 Pro / iOS 26.5. Results: `/private/tmp/tennis-phase1-test-gate.xcresult`; logs: `/private/tmp/tennis-phase1-build-gate.log` and `/private/tmp/tennis-phase1-test-gate.log`. Tests were run with `-parallel-testing-enabled NO`. These temporary paths are local execution evidence, not committed portable artifacts.

The result bundle contains one Thread Performance Checker warning from deliberate semaphore stalls in `BallDetectionManagerTests.swift`. Independent code review found no corresponding production wait or correctness defect; `.planning/WINDOWS.md` retains this test-harness warning for later disposition. It does not leave any of the twelve planned threat mitigations open.

Representative clip accuracy, actual admitted sampling sufficiency, sustained process memory and physical audio timing remain unmeasured Phase 4 obligations. Complete user control transitions belong to Phase 2 and visible overlay alignment to Phase 3. This report does not accept those requirements.

## Sign-Off

- [x] Every authored threat has a disposition and inspected mitigation.
- [x] No risks were accepted or transferred without evidence.
- [x] All twelve threats are closed; `threats_open: 0` confirmed.
- [x] `status: verified` set for this scoped level-1 check.

**Approval:** Verified 2026-09-25 against the authored Phase 1 threat register.
