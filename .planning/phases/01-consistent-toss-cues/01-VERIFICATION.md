---
phase: 01-consistent-toss-cues
verified: 2026-09-26T04:48:00Z
status: human_needed
score: 12/12 must-haves verified
behavior_unverified: 0
overrides_applied: 0
covered_files:

  - .planning/REQUIREMENTS.md
  - .planning/ROADMAP.md
  - .planning/phases/01-consistent-toss-cues/01-01-PLAN.md
  - .planning/phases/01-consistent-toss-cues/01-01-SUMMARY.md
  - .planning/phases/01-consistent-toss-cues/01-02-PLAN.md
  - .planning/phases/01-consistent-toss-cues/01-02-SUMMARY.md
  - .planning/phases/01-consistent-toss-cues/01-03-PLAN.md
  - .planning/phases/01-consistent-toss-cues/01-03-SUMMARY.md
  - .planning/phases/01-consistent-toss-cues/01-COVERAGE.md
  - .planning/phases/01-consistent-toss-cues/01-PATTERNS.md
  - .planning/phases/01-consistent-toss-cues/01-RESEARCH.md
  - .planning/phases/01-consistent-toss-cues/01-REVIEW.md
  - .planning/phases/01-consistent-toss-cues/01-SECURITY.md
  - .planning/phases/01-consistent-toss-cues/01-UI-REVIEW.md
  - ARCHITECTURE.md
  - GRIDTRACKNET_COREML.md
  - LEARNINGS.md
  - Tennis Trainer/AnalysisFrame.swift
  - Tennis Trainer/AudioManager.swift
  - Tennis Trainer/BallDetectionManager.swift
  - Tennis Trainer/CameraManager.swift
  - Tennis Trainer/ContentView.swift
  - Tennis Trainer/Detectors/ColorKalmanBallDetector.swift
  - Tennis Trainer/Detectors/GridTrackNetDecoder.swift
  - Tennis Trainer/Detectors/GridTrackNetDetector.swift
  - Tennis Trainer/Detectors/ServeTossApexDetector.swift
  - Tennis Trainer/PixelBufferScaler.swift
  - Tennis Trainer/PoseDetectionManager.swift
  - Tennis Trainer/VideoPlayerManager.swift
  - Tennis TrainerTests/AnalysisAssociationTests.swift
  - Tennis TrainerTests/BallDetectionManagerTests.swift
  - Tennis TrainerTests/GridTrackNetDecoderTests.swift
  - Tennis TrainerTests/PoseDetectionManagerTests.swift
  - Tennis TrainerTests/ServeTossApexDetectorTests.swift
  - docs/references/README.md
  - docs/references/toss-cue-validation.md

covered_digest: "v1:sha256:08d548c54c75e3664d713d133e29f92801c2091ca8596ea048e2806ea3988a8c"
decision_coverage:
  honored: 0
  total: 0
  not_honored: []
flagged_prohibitions:

  - statement: "The reliability work must not present synthetic cue counts, finite queue bounds, or software callback times as measured real-toss accuracy or physical beep latency."
    status: unverified
    reason: "Descriptor-less unresolved prohibition; no enforcement descriptor or human acceptance was supplied."
    judgment: "NON-AUTHORITATIVE: inspected documentation separates deterministic evidence from empirical claims."
    flag: "unverified-prohibition — human review recommended"
unresolved_edge_items:

  - id: EDGE-CUE-01
    status: unclassified_unresolved
    reason: "Manual association contract has passing deterministic tests; the supplied edge item has no classification or check descriptor."
  - id: EDGE-CUE-04
    status: unclassified_unresolved
    reason: "Manual exact-identity pose/fallback contract has passing deterministic tests; the supplied edge item has no classification or check descriptor."
deferred:

  - truth: "Every stop, pause, seek, replacement, completion and mode-exit transition invalidates old effects."
    addressed_in: "Phase 2"
    evidence: "Phase 2 success criteria 1–5 explicitly own complete control and resource-lifecycle acceptance."
  - truth: "Markers align with the actual visible AV preview/player image."
    addressed_in: "Phase 3"
    evidence: "Phase 3 success criteria 1–3 require source-to-display geometry and actual AV-layer integration."
  - truth: "Real toss sampling sufficiency, representative clip accuracy, sustained process memory and physical beep latency meet frozen criteria."
    addressed_in: "Phase 4"
    evidence: "Phase 4 success criteria 2–5 require permitted labeled clips, frozen acceptance limits, real devices, physical audio and explicit outstanding checks."
human_verification:

  - test: "Review the final ownership ledger, permitted-media inventory and reliability claims, explicitly resolving the transparency prohibition."
    expected: "Accept only the tested eight-buffer per-manager/sixteen-buffer aggregate app-pipeline bound; retain clip, device, framework/process-memory and physical-audio evidence as unavailable. Record a human decision on the prohibition."
    why_human: "01-03-PLAN.md explicitly defers this human-check; the unresolved prohibition has no deterministic enforcement descriptor. LLM review cannot silently approve it."
  - test: "Classify or explicitly resolve EDGE-CUE-01 against the held-window association contract."
    expected: "Confirm the intended edge obligation or provide a held-out check; preserve the passing exact-frame/pixel/time/geometry tests without claiming the unclassified probe itself passed."
    why_human: "The original edge item remains unclassified/unresolved and supplies no executable predicate."
  - test: "Classify or explicitly resolve EDGE-CUE-04 against the exact-identity pose-or-fallback contract."
    expected: "Confirm exact source/generation/frame association and strict fallback above 0.70, or specify the missing edge obligation and a held-out check."
    why_human: "Passing manually specified pose cases cannot silently classify the original unresolved edge item."
---

# Phase 1: Consistent Toss Cues Verification Report

**Phase Goal:** As a player, I want to receive consistent toss feedback tied to the frames and body pose being analyzed in either mode, so that I can trust feedback for my current toss.
**Verified:** 2026-09-26T04:48:00Z
**Status:** human_needed
**Re-verification:** No — initial verification; no previous VERIFICATION.md or overrides existed.

The deterministic Phase 1 contract is implemented and behaviorally supported. All four CUE requirements are satisfied within that contract. No production blocker was found. Final acceptance remains **human_needed** because the plan deliberately retains an evidence-claim review, one unresolved transparency prohibition, and two unclassified edge items. **12/12 is a deterministic truth score, not empirical release acceptance.** Complete with **1 flagged prohibition and 2 unresolved edge items**; neither is silently green.

## User Flow Coverage

The roadmap initially marked MVP mode with a non-user-story goal. The canonical `user-story.validate` command rejected it. The orchestrator reformatted only that goal to the equivalent story above; validation then passed. Requirements and success criteria were unchanged.

| Step | Expected | Evidence in codebase | Status |
|---|---|---|---|
| Open the app and choose live practice | Capture frames reach the shared cue pipeline with their source time | `ContentView.swift:55`; `CameraManager.swift:179–189`; actual sample-buffer adapter test | VERIFIED for Phase 1 ingress; permission/startup acceptance belongs to Phase 2 |
| Choose a saved video and play | Acquired frames use returned display time and the same analysis path | `VideoPlayerManager.swift:9–20,109–126`; complete playback-adapter test | VERIFIED for Phase 1 ingress; complete player controls belong to Phase 2 |
| Present a fully observed eligible toss | Associated samples produce one forwarded cue; overlap cannot replay it | Both `AnalysisAssociationTests.testComplete*Cue_WhenRealPreparationAndDecoderAreUsed` cases pass, with real preparation, decoder and apex logic | VERIFIED for deterministic eligible evidence |
| Receive current-toss feedback | Candidate pose or explicit fallback determines the cue; callback is connected to audio | `BallDetectionManager.swift:230–251`; `ServeTossApexDetector.swift:62–99`; `ContentView.swift:83–87` → `AudioManager.swift:64–75` | VERIFIED for association/callback wiring; real toss accuracy and audible onset remain Phase 4 evidence |

Code coverage of the Phase 1 user flow is complete. Physical sound, visual placement, and device experience were not observed and are not certified by this table.

## Goal Achievement

### Observable Truths

Roadmap criteria are kept verbatim in rows 1–4. Plan restatements are merged into those rows; distinct plan detail is retained in rows 5–12. All 14 plan truth declarations are mapped below. `App/` and `Tests/` in tables mean `Tennis Trainer/` and `Tennis TrainerTests/` respectively.

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | A recorded result can be traced to the exact source frames, timestamps, and geometry used for its prediction, including when newer frames arrive before the result is delivered. | VERIFIED | `App/AnalysisFrame.swift:43–136` owns pixels and immutable metadata; `GridTrackNetDetector.swift:110–130` sends one window to prediction and decode. Passing held-window and source-mutation tests inspect all five identities, rational times, sentinels, mapping and pose. Includes 01-02 truth 1. |
| 2 | Submitting frames faster than they can be analyzed cannot grow pending work or retained buffers beyond the documented finite bound; obsolete pending work does not accumulate into a stream of late cues. | VERIFIED | `BallDetectionManager.swift:180–227` reserves before dispatch/pose, holds through publication, and retains no pending input. Actual weak-buffer/destruction assertions reach 8 per manager / 16 aggregate, 6/12 during prediction and 5/10 during held publication; 1,000 further offers at each held stage are rejected. Includes 01-01 truth 2 and 01-03 truth 1. |
| 3 | A fully observed eligible toss produces at most one automatic cue when timestamps repeat or five-frame windows overlap; the existing cooldown remains a separate eligibility rule. | VERIFIED | `ServeTossApexDetector.swift:47–99` advances identity/time watermarks before eligibility; triplet/candidate state is separate from cooldown. Passing overlap/replay tests assert consumption/evaluation counts, plus independent 3,999/4,000/4,001 ms cooldown cases. Includes 01-02 truth 4. |
| 4 | Delaying or removing pose observations cannot substitute a newer or stale body position for the toss sample's height gate; the corresponding valid pose or documented fallback determines the result. | VERIFIED | `AnalysisFrame.swift:66–76` sanitizes exact identity; `PoseDetectionManager.swift:55–69` serializes extraction and returns explicit absence; apex stores candidate baseline. Contrary-pose, missing/error/confidence-boundary and all source/generation/frame mismatch cases pass, including 0.71 cue and 0.69/0.70 suppression. Includes 01-02 truth 2. |
| 5 | Live capture and saved-video analysis reach the existing automatic-cue callback through the production manager path using capture PTS or the copied player's returned display time; complete deterministic paths cue once and reject repeated/malformed/invalidated evidence. | VERIFIED | Real `captureOutput`/display-link entry points invoke the tested adapters. Two complete adapter fixtures exercise real transforms, windows, decoder and apex with injected raw tensors/pose; nine acquired frames yield one candidate-3 callback, equivalent-time replay adds none. Malformed and generation-discard tests verify suppression. 01-01 truth 1; 01-03 truth 3. |
| 6 | Reset invalidates publication immediately without releasing an executing job's capacity; every terminal path releases only its own lease. | VERIFIED | `BallDetectionManager.swift:83–106,230–283` matches lease IDs, coalesces idle clearing and rechecks generation after effects. Passing held-worker/publication reset, track-callback reset, duplicate completion, terminal failure and teardown tests assert suppressed effects and release counts. 01-01 truth 3; terminal detail of 01-03 truth 1. |
| 7 | The reproducible source reference, permitted-media inventory, settings, and evaluation protocol exist before implementation; missing empirical inputs remain explicitly unavailable. | VERIFIED | `git show 4128fbb:docs/references/toss-cue-validation.md` contains the baseline/protocol before first production GREEN `bb75136`. Baseline-to-pre-execution app/test/project diff is empty. Current model SHA-256 hashes match all three recorded hashes. Inventory explicitly unavailable. 01-01 truth 4. |
| 8 | Invalid/nonfinite time values are rejected, identity counters cannot silently wrap into an existing generation, and dense or equal timestamps cannot grow retained history without a count bound. | VERIFIED | Manager numeric/rational guard and checked sequence; apex keeps at most three entries and saturating counters. Passing invalid/equal/regressing time, exhausted sequence and 1,000-overlap tests assert exact accepted/consumed counts. 01-02 truth 3. |
| 9 | An empty stream, fewer than the required warmup frames, or samples without accepted positions produces no automatic cue. | VERIFIED | Exactly-five `Window` initializer; warmup returns no sample batch; apex rejects absent/low-confidence positions. Real-grid warmup test asserts zero predictions through four frames, no cue after missing-position fifth frame, and fresh warmup after reset. 01-02 truth 5. |
| 10 | Duplicate and out-of-order frame identities never replay consumed cue evidence, including after temporal history pruning; accepted evidence retains chronological order. | VERIFIED | `isNew` requires increasing sequence and rational source time within an explicitly authorized domain. Passing pruned-history replay/reversal and equal-time/older-sequence tests leave consumed/evaluated/emitted counts unchanged. 01-02 truth 6. |
| 11 | The bundled five-frame model contract, FP16 values, independent output strides, temporal order and portrait-fit/nonportrait-fill source coordinates remain correct after refactoring. | VERIFIED | `GridTrackNetDecoder.swift:6–68` validates each tensor inside scoped bytes; production f1…f5 mapping is oldest→newest. Six decoder tests pass, including independent padded axes, malformed layouts, rotated pixel quadrants, hand-calculated geometry and actual bundled-model smoke. Observed heads are FP16 `[1,5,48,27]`, strides `[7680,1536,32,1]`; assets unchanged. 01-03 truth 2. |
| 12 | The validation record reports measured results, missing empirical evidence and final ownership bounds separately; deterministic success does not establish clip accuracy or physical beep timing. | VERIFIED as document content | Validation ledger contains actual test commands/counts, scoped owner counts and explicit pending media/device/audio entries. Direct result-bundle inspection agrees. The separate prohibition remains unverified pending human review; document presence/content does not resolve it. 01-03 truth 4. |

**Score:** 12/12 truths verified; **0** present-but-behavior-unverified truths. No overrides. No coincidental-reliance item identified: production establishes admission, identity and sequencing; fixtures supply supported boundary inputs rather than establishing an otherwise absent production precondition.

### Required Artifacts

Canonical `verify.artifacts` returned 4/4, 4/4 and 3/3 for the three plans (10 unique declared paths). Each was also inspected for implementation and callers, rather than accepted from existence alone.

| Artifact | Expected | Status | Substantive/wiring evidence |
|---|---|---|---|
| `App/BallDetectionManager.swift` | Admission and effect boundary | VERIFIED | Production dependencies construct real backends; both media managers submit; locked lease survives final callback/discard. |
| `App/AnalysisFrame.swift` | Owned frame/window values | VERIFIED | Always-allocating preparation, five-record validation, exact-identity pose sanitization; invoked by grid push. |
| `App/Detectors/GridTrackNetDetector.swift` | Snapshot prediction association | VERIFIED | Five-record ring; production model f1…f5; one snapshot passed to predictor and decoder. |
| `App/Detectors/ServeTossApexDetector.swift` | Bounded candidate/pose state | VERIFIED | Rational watermark, three-entry history, candidate baseline, separate cooldown; called inside manager publication. |
| `App/Detectors/GridTrackNetDecoder.swift` | Strict unified decoder | VERIFIED | Per-head dtype/axes/stride/byte-span checks and actual coordinate values; both detector convenience paths reach it. |
| `Tests/BallDetectionManagerTests.swift` | Ingress, scheduler and ownership proof | VERIFIED | 21 executed tests with value, callback, weak-reference and destruction assertions. |
| `Tests/PoseDetectionManagerTests.swift` | Same-image pose and serialization | VERIFIED | 4 executed tests, including clearing absent results and 100 concurrent extraction calls. |
| `Tests/AnalysisAssociationTests.swift` | Candidate pose and complete adapters | VERIFIED | 10 executed tests; both complete adapters and positive/negative mismatch fallback cases. |
| `Tests/GridTrackNetDecoderTests.swift` | Independent oracle and model smoke | VERIFIED | 6 executed tests; explicit tensor storage, hand-calculated expected points, actual model invocation. |
| `docs/references/toss-cue-validation.md` | Baseline, resource ledger and handoff | VERIFIED | Pre-change protocol preserved; executable evidence mapped; referenced from architecture and reference index. Human claims review pending. |

`CameraManager`, `VideoPlayerManager`, `PoseDetectionManager`, color fallback and the changed apex tests were inspected as supporting artifacts. Empty pose, optional positions, empty initial rings, and injected no-op defaults are valid state/seams: production supplies real services and populates outputs. No stub or orphan was found.

### Key Link Verification

The generic `verify.key-links` command reported all eight links as “Target not referenced in source.” Swift shares symbols across the synchronized app target rather than importing `.swift` filenames, and several declared links are callbacks through a manager. These are heuristic false negatives; the following explicit call chains and passing integration tests establish wiring.

| From | To | Via | Status | Evidence |
|---|---|---|---|---|
| CameraManager | BallDetectionManager | captureOutput → submitSampleBuffer → process(input:) | WIRED | `CameraManager.swift:179–189`; PTS and `.right` passed before analysis. |
| VideoPlayerManager | BallDetectionManager | display-link → processCurrentFrame → process(input:) | WIRED | `VideoPlayerManager.swift:9–20,100–126`; new-frame check and copied display time. |
| BallDetectionManager | ContentView/audio | onApex → media forwarding → playBeep | WIRED | `BallDetectionManager.swift:248`; camera 203–206/player 227–230; `ContentView.swift:83–87`. Manual beep at 188 is separate. |
| BallDetectionManager | AnalysisFrame | input/identity/extracted pose → grid push → prepare | WIRED | Manager 157–167,210–214; grid 81–84; frame 115–136. |
| GridTrackNetDetector | ServeTossApexDetector | snapshot-derived Sample metadata → manager publish → consume | WIRED | Grid 110–130; decoder 23–24; manager 243–248. |
| ServeTossApexDetector | BallDetectionManager | newly eligible consume return → onApex | WIRED | Apex 87–99; manager 247–249; real callback assertions. |
| GridTrackNetDetector | GridTrackNetDecoder | RawOutputs + original Window | WIRED | Grid 115–130; no mutable metadata read after prediction. |
| AnalysisAssociationTests | BallDetectionManager | actual media adapters + preparation/decoder/apex | WIRED | `runCompleteAdapter` builds injected boundaries, submits through each production adapter and asserts callback/metadata. |

### Data-Flow Trace (Level 4)

| Artifact/value | Source | Flow to output | Status |
|---|---|---|---|
| Source identity/time/pixels | CMSampleBuffer PTS or copied AVPlayer output | Input → admitted identity → owned frame → immutable window → sample | FLOWING |
| Pose/joints/baseline | Serialized Vision request on the admitted image | FramePose → metadata → candidate height gate; current FramePose also publishes overlays | FLOWING |
| Ball position | Bundled Core ML `conf/x_off/y_off` prediction | Strict decoder + original mapping → `ballPosition` → ContentView live/playback overlays | FLOWING |
| Automatic cue | Unseen eligible candidate with own pose | Apex consume → manager onApex → media onApex → AudioManager scheduleBuffer | FLOWING; physical onset unmeasured |

Tests replace model/pose/output boundaries with controlled inputs; production factories call actual Vision/Core ML/AVFoundation. No user-visible output terminates at a hardcoded test result. Display-layer placement is a separate Phase 3 obligation.

### Behavioral Spot-Checks

The orchestrator's independent gate already executed the complete shared scheme at source HEAD `cddaebb`. `git diff cddaebb -- 'Tennis Trainer' 'Tennis TrainerTests' 'Tennis Trainer.xcodeproj'` is empty. I inspected the actual logs and `.xcresult` rather than accepting summary prose. No redundant suite, server, or service was started by this verifier.

Recorded commands:

```sh
xcodebuild build -scheme 'Tennis Trainer' -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
xcodebuild test -scheme 'Tennis Trainer' -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled NO -resultBundlePath /private/tmp/tennis-phase1-test-gate.xcresult
xcrun xcresulttool get test-results summary --path /private/tmp/tennis-phase1-test-gate.xcresult
xcrun xcresulttool get test-results tests --path /private/tmp/tennis-phase1-test-gate.xcresult --compact
```

Build/test logs show `BUILD SUCCEEDED` / `TEST SUCCEEDED`. Direct bundle summary: **65 total, 65 passed, 0 failed, 0 skipped** on iPhone 17 Pro/iOS 26.5 (23F77). The result tree contains every named behavior referenced in this report. The following additional read-only single-test checks were executed by the verifier using `xcrun xcresulttool get test-results test-details --path /private/tmp/tennis-phase1-test-gate.xcresult --test-id '<identifier>' --compact`; each completed below 10 seconds and returned `testResult: Passed`.

| Behavior | Test identifier | Recorded execution | Status |
|---|---|---|---|
| Original snapshot survives newer input | `BallDetectionManagerTests/testWindowRetainsOriginalMetadata_WhenPredictionIsHeld()` | 0.239 s | PASS |
| Distinct ownership and held-stage limits | `BallDetectionManagerTests/testUniqueBufferBound_WhenTwoManagersHoldPreparationPredictionAndPublication()` | 0.504 s; test-harness QoS warning | PASS |
| Mismatched pose above fallback still cues | `AnalysisAssociationTests/testCueUsesFallback_WhenPoseIdentityMismatchesAboveThreshold()` | 0.0011 s | PASS |
| Replay after pruning changes no cue state | `ServeTossApexDetectorTests/testReplayAfterPruning_DoesNotChangeConsumptionEvaluationOrEmission()` | 0.015 s | PASS |

These inspect existing executed behavioral evidence; they are not claims of new test runs. Result bundles/logs are local temporary evidence, not portable committed assets.

### Probe Execution

Not applicable. This is a native app phase, not a migration/tooling phase. No executable `probe-*.sh` is declared in its plans/summaries or discovered among repository files. The “edge probe” ledger contains unresolved planning descriptors, not runnable shell probes; no synthetic PASS marker substitutes for them.

### Requirements Coverage

| Requirement | Source plans | Description | Status | Evidence |
|---|---|---|---|---|
| CUE-01 | 01-01, 01-02, 01-03 | Same source frames/timestamps/geometry for result and cue | SATISFIED — deterministic | Truths 1,5,7,11; held-window, ownership, adapter, tensor and mapping tests. |
| CUE-02 | 01-01, 01-02, 01-03 | Tested finite work/buffer bound without backlog | SATISFIED — deterministic | Truths 2,6,8; admission before work, actual distinct-buffer ledger and matching release assertions. |
| CUE-03 | 01-02, 01-03 | At most one cue with repeat/overlap | SATISFIED — deterministic | Truths 3,5,9,10; counts distinguish consumption, candidates and cooldown. |
| CUE-04 | 01-01, 01-02, 01-03 | Candidate-associated pose or documented fallback | SATISFIED — deterministic | Truth 4; contrary pose, confidence, absence/error and every identity mismatch tested in pure/manager paths. |

All IDs in every plan frontmatter exist in REQUIREMENTS.md. The complete Phase 1 mapping is exactly CUE-01…CUE-04; **0 orphaned requirements**. CHECK-01/02/03 remain Phase 4 ownership, LIFE/CAM/PLAY Phase 2, VIEW Phase 3. Plan summary `requirements-completed` arrays were not treated as acceptance evidence.

### Decision Coverage

Canonical `check.decision-coverage-verify` result: **“No CONTEXT.md - nothing to check.”** Skipped, 0/0 decisions, non-blocking. No discussion decision was fabricated.

### Test Quality Audit

| Test file | Linked requirements | Active/passed | Skipped | Circular | Strongest assertions | Verdict |
|---|---|---:|---:|---|---|---|
| BallDetectionManagerTests | CUE-01/02/04 | 21 | 0 | No | Held-stage workflow, exact releases, buffer identity/destruction, all-five metadata | Sufficient |
| AnalysisAssociationTests | CUE-01/02/03/04 | 10 | 0 | No | Complete adapter callback/count/identity plus positive and negative fallback | Sufficient |
| GridTrackNetDecoderTests | CUE-01 | 6 | 0 | No | Independent tensor strides, explicit FP16 coordinates, actual model interface | Sufficient within numerical/interface scope |
| PoseDetectionManagerTests | CUE-04 | 4 | 0 | No | Same image/identity, clearing and serialized transaction counts | Sufficient |
| ServeTossApexDetectorTests | CUE-02/03/04 | 23 | 0 | No | Separate consumed/evaluated/emitted counts, exact rational boundaries | Sufficient |

The remaining passing Swift Testing scaffold is not requirement evidence. No disabled requirement tests or fixture-output generators were found. Decoder expected values are independently specified arithmetic/geometry, appropriate to that numerical contract; they do not claim external tennis accuracy. The actual model is independently invoked only in the separate compatibility smoke.

Disconfirmation checks: (1) Real-world sampling sufficiency and accuracy are only partially evidenced and remain Phase 4. (2) The early fake-analysis tracers and same-nil-result terminal loop alone would not prove real decoder/preparation behavior; later complete-adapter and actual preparation/decoder failure fixtures do, and were inspected. (3) Physical Vision/Core ML allocation/service failures are injected at their boundaries rather than induced on hardware; actual device failure experience remains unobserved. No uncovered Phase 1 deterministic requirement was established by these limits.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `Tests/BallDetectionManagerTests.swift` | 32 | Deliberate semaphore stall produces Thread Performance Checker QoS warning | INFO for phase goal | Named test passes; the wait is test-only. Existing WINDOWS entry is retained; no production latency or safety conclusion is inferred. |

No unreferenced `TBD`, `FIXME` or `XXX` marker, placeholder, disabled test, unpopulated output or new production payload log was found in changed implementation/tests/validation. `git diff --check` passes. Existing model assets match baseline hashes. Color fallback uses captured shoulder value and does not emit automatic apex samples; target/bundle/deployment settings and manual beep wiring are preserved.

### Prohibitions, Unresolved Edges and Assumptions

**WARNING — unverified-prohibition — human review recommended.** 01-03's exact transparency prohibition has `status: unresolved` and no `verification`/enforcement descriptor. It is accepted and retained as flagged, not assigned an invented test tier or silently approved. **NON-AUTHORITATIVE LLM judgment:** the inspected ledger and reports consistently distinguish synthetic callback/ownership evidence from real toss accuracy and sound onset. Human resolution is still required.

**WARNING — EDGE-CUE-01 and EDGE-CUE-04 remain unclassified/unresolved.** Their explicit manual contracts have strong passing association and fallback tests. No truth is tagged `verification: backstop` in these plans; I do not invent that descriptor or downgrade inferable tested truths. The original unresolved probe items remain separate human decision items because their missing classification cannot be reconstructed from test success. Held-out checks are appropriate if classification reveals an additional obligation.

| Assumption | Disposition |
|---|---|
| A1 — one-job dropping samples enough real tosses | UNVERIFIED empirical assumption; Phase 4 must measure admitted gaps and clip outcomes. No FPS promise made. |
| A2 — eight unique app-visible buffers | VERIFIED within the documented admitted-pipeline scope; actual weak ownership and destruction assertions, 16 aggregate. Source pools/framework-private allocations and process memory are excluded and unmeasured. |
| A3 — compact history preserves intended behavior | VERIFIED for specified original/edge characterization; first consumed estimate remains authoritative. Real-clip impact remains unscored in Phase 4. |

### Deferred Items

| Item | Addressed in | Roadmap evidence |
|---|---|---|
| Full control/lifecycle invalidation matrix and permissions | Phase 2 | SC1–5 explicitly name Stop/Pause/seek/replacement/completion/mode exit and resources. |
| Visible AV-layer overlay placement | Phase 3 | SC1–3 require source-to-display transforms and real layer/layout checks. |
| Permitted labeled clips, actual cadence/accuracy, sustained device/process memory and physical sound timing | Phase 4 | SC2–5 require corpus, frozen criteria, real-device/audio evidence and outstanding-check accounting. |

These explicit later-phase obligations are not Phase 1 implementation gaps. They remain unaccepted and do not erase the Phase 1 human items below.

### Human Verification Required

1. **Evidence ledger and transparency prohibition.** Review `docs/references/toss-cue-validation.md`, the source/model hashes and the recorded test bundle. Expect only the scoped deterministic claims to be accepted, with missing clips/devices/process-memory/audio evidence retained. Record an explicit decision on the prohibition. This is the deferred `01-03-PLAN.md` human-check; an LLM cannot approve its own reliability claims.
2. **EDGE-CUE-01 classification.** Review the exact-frame/pixel/time/geometry association obligation and the held-prediction/source-mutation tests. Confirm the intended edge contract or supply a held-out predicate. Expect no claim that an unclassified probe passed merely because its manually specified tests passed.
3. **EDGE-CUE-04 classification.** Review exact pose identity and the strict fallback, including 0.71 versus 0.69/0.70 outcomes. Confirm the intended contract or define the missing edge check. Expect mismatched pose to become missing without rejecting valid frame metadata.

### Gaps Summary

No deterministic implementation gap or production BLOCKER was established. All 12 merged truths, 10 unique declared artifacts, 8 key links, and 4 phase requirements have substantive evidence. The final status is **human_needed**, because the required human review and unresolved flags prevent an unconditional `passed` verdict. No commit or production/test/tracking edit was made by this verifier.

Fingerprint fields above are copied from `gsd_run query verification.fingerprint` with every phase PLAN/SUMMARY, the mapped requirements, all changed implementation/tests, and supporting evidence files explicitly supplied. No nested or superseded plans were present. Future changes to covered files require fingerprint refresh/reverification as appropriate.

---

_Verifier: gsd-verifier_

UAT resume note — 2026-09-26: The API-coverage precheck initially misread the source-coverage document as an empty API matrix. Added the supported, reasoned no-external-integration declaration to `01-COVERAGE.md`; the gate then passed. No app, test, requirement or human-review outcome changed. The covered-input fingerprint was refreshed for that clarification and its learning entry; all three human items remain pending.
