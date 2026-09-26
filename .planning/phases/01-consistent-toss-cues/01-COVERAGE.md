# Phase 1 source coverage

No external API integration: Phase 1 refines the existing on-device AVFoundation, Vision and bundled Core ML pipeline; it adds no external service or SDK integration.

All in-scope source items are planned. No CONTEXT.md, SPEC.md or UI-SPEC.md exists; no discussion decision was fabricated. The approved roadmap and requirements govern scope. Research prescriptions and probe resolutions are technical planning choices, not newly approved product preferences.

| Source | ID / item | Plan / task | Status |
|---|---|---|---|
| GOAL | Consistent toss feedback tied to analyzed frames/body pose in either mode | 01-01 T1 → 01-02 T1–T3 → 01-03 T2 | COVERED |
| REQ | CUE-01 exact source/prediction association | 01-01 T1; 01-02 T1; 01-03 T1–T2 | COVERED |
| REQ | CUE-02 finite work/buffer bound | 01-01 T1–T2; 01-02 T1/T3; 01-03 T2 | COVERED |
| REQ | CUE-03 at most one eligible cue with repeated/overlapping input | 01-02 T3; 01-03 T2 | COVERED |
| REQ | CUE-04 candidate-associated pose or explicit fallback | 01-01 T2; 01-02 T1–T2; 01-03 T2 | COVERED |
| RESEARCH | Real live/playback ingress and automatic callback | 01-01 T1; 01-03 T2 | COVERED |
| RESEARCH | PTS, returned player display time, rational ordering and invalid-time rejection | 01-01 T1; 01-02 T1/T3; 01-03 T2 | COVERED |
| RESEARCH | Admission before dispatch, pose and preprocessing; one lease, zero pending inputs | 01-01 T1–T2 | COVERED |
| RESEARCH | One publication including pose/ball/track/cue/processed effects | 01-01 T2; 01-03 T2 | COVERED |
| RESEARCH | Matched release on every terminal path; coalesced reset; source/generation seam | 01-01 T2; 01-03 T2 | COVERED |
| RESEARCH | Owned immutable five-record window; all metadata and exact-size/.up ownership | 01-02 T1; 01-03 T1–T2 | COVERED |
| RESEARCH | Serialized shared Vision extraction; confidence/nose/neck/missing rules | 01-01 T2; 01-02 T2 | COVERED |
| RESEARCH | Monotonic identity watermark independent of history and cooldown | 01-02 T3 | COVERED |
| RESEARCH | Count-bounded history, horizon characterization, first estimate policy | 01-02 T3; 01-03 T2 | COVERED |
| RESEARCH | No guessed FPS/gap/accuracy/audio promises | 01-01 T1; 01-03 T2 and prohibition | COVERED |
| RESEARCH | Tensor type/shape/stride validation; FP16; five temporal indices; independent offsets | 01-03 T1 | COVERED |
| RESEARCH | Portrait fit/nonportrait fill, orientation, bottom-left mapping and freshest overlay index | 01-02 T1; 01-03 T1 | COVERED |
| RESEARCH | Inject fakes before eager service construction; deterministic held schedulers | 01-01 T1–T2; 01-02 T1 | COVERED |
| RESEARCH | Bundled-model smoke distinct from deterministic tests | 01-03 T1 | COVERED |
| RESEARCH | Unique pixel ownership plus two-manager aggregate bound; finite diagnostics | 01-01 T2; 01-02 T1/T3; 01-03 T2 | COVERED |
| RESEARCH | Baseline reference/protocol before implementation/tuning; permitted-media/device inventory | 01-01 T1; 01-03 T2 | COVERED |
| RESEARCH | Native iOS 18.5, existing model/frameworks, on-device operation, architecture boundary | Every plan context/action and threat model | COVERED |
| RESEARCH | Current color fallback, manual Test Beep, separate camera session queue | 01-01 T1–T2; 01-03 T2 | COVERED |
| RESEARCH | Input validation, integrity, resource limits and local data minimization | Every plan threat_model | COVERED |
| CONTEXT | No CONTEXT.md / no D-NN decisions | Explicitly absent; approved source constraints preserved | NOT APPLICABLE |

## Dependency and ownership graph

| Plan | Needs | Creates / improves | Wave | Checkpoint |
|---|---|---|---|---|
| 01-01 | Existing native media/ball/apex path | Baseline before edits; real ingress tracer; injected services; finite scheduler; pose values | 1 | None |
| 01-02 | 01-01 Input, identity, lease, FramePose | Immutable model window; associated candidate pose; monotonic dedup and bounded history | 2 | None |
| 01-03 | Final manager/window/cue contracts | Validated decoder, real-model smoke, complete-path tests and final ownership/evidence ledger | 3 | None |

Shared manager/detector/test seams require sequential waves. No same-wave overlap. Each task modifies at most five files and each plan has two or three tasks. A costly internal interface refactor is flagged, but no one-way published/persisted contract is introduced. No external user setup, package installation, schema push, new app scaffold, UI redesign or new service integration applies.

## Edge probe ledger

The supplied report has seven items. Five explicit resolutions are preserved verbatim as truths; two unclassified items remain flagged assumptions with deterministic manual association contracts.

| Requirement/category | Disposition | Location |
|---|---|---|
| CUE-02 boundary | Explicit resolved truth | 01-03 must_haves truth 1; ownership/terminal-path boundary tests |
| CUE-02 precision | Explicit resolved truth | 01-02 truth 3; input/counter/dense-history tests |
| CUE-03 adjacency | Explicit resolved truth | 01-02 truth 4; repeated/overlapping source plus independent cooldown boundaries |
| CUE-03 empty | Explicit resolved truth | 01-02 truth 5; empty/no-position/incomplete-warmup tests |
| CUE-03 ordering | Explicit resolved truth | 01-02 truth 6; same-source old/repeated window after pruning |
| CUE-01 unclassified | Unresolved flagged assumption | 01-02 flagged_assumptions; held-A/new-B pixels/metadata contract |
| CUE-04 unclassified | Unresolved flagged assumption | 01-02 flagged_assumptions; exact identity pose-or-missing contract |

No-silent-drop equality: 7 surfaced = 5 truths + 2 flagged assumptions. The manual tests do not relabel unclassified probe results as resolved.

UAT resolution — 2026-09-26: The user explicitly passed the original-five-frame contract for EDGE-CUE-01 and the exact-identity pose-or-missing contract for EDGE-CUE-04. See `01-UAT.md` tests 2–3 and `01-VERIFICATION.md`. This human decision closes the planning ambiguity; it does not fabricate or execute an undefined probe. The evidence-claim prohibition below was separately reviewed and passed in UAT test 1.

## Prohibition recall

Adversarial recall considered per requirement the following candidates: wrong source/geometry/time, reused pixels, host-time substitution, hidden uploads, repurposed coaching scope, unsupported accuracy claims, lost provenance, and synthetic evidence represented as measured behavior (CUE-01); unbounded input/publication/history, premature lease release, hidden capture retention, frozen controls, concealed drops, invented FPS, finite-queue claims represented as physical latency, and unbounded diagnostics (CUE-02); duplicate windows/candidates, post-pruning replay, skipped nil identities, out-of-order evidence, cooldown hiding dedup, tuning eligibility to improve scores, manual beeps counted as detector success, unsupported physical-toss segmentation, and misleading synthetic accuracy claims (CUE-03); shared/latest pose, stale/missing inheritance, wrong identity, confidence treated as freshness, concurrency races, ambiguous nearest-time pairing, silent fallback changes, unapproved handedness/multiplayer expansion, pose-data leakage, and unjustified reliability claims (CUE-04).

Routine correctness items are covered by the edge/tests/actions and are dropped from the bespoke prohibition list. Product expansions are already excluded by the approved project/roadmap. Privacy/data-retention/consent canon is referred to the security review and local-data threat controls rather than minted as a duplicate prohibition. One bespoke transparency item survives: synthetic counts, bounded work and callback time must not be represented as measured real-toss accuracy or physical beep latency. Its exact descriptor-less projection was generated by the installed probe-core.cjs projectProhibitions function and is authored under 01-03 must_haves.prohibitions as unresolved/flagged-unverified. No check_* target or enforcement path is invented.

## Explicit assumptions and boundaries

Research A1 (real sampling sufficiency), A2 (eight unique app-visible buffers) and A3 (triplet-history equivalence) have measurement/proof tasks; none is claimed proven at planning. The chosen count bound can change only with an explicit ownership ledger and matching adversarial assertions. Physical iPhone, permitted clips and physical-audio measurement remain unknown. A model smoke that cannot run remains reported pending. Full permission/player/mode-transition acceptance belongs to Phase 2, source-to-display geometry to Phase 3, and final empirical release evidence/criteria to Phase 4. These are roadmap exclusions, not dropped Phase 1 items.

No app build, test, clip run or device measurement was performed while writing these plans. Parent owns roadmap/state/learnings updates, independent checks and commits.

## Planning verification — 2026-09-25

The independent plan checker passed on its second review with zero blockers or warnings. The revision separated invalid frame/window rejection from missing-pose fallback and recorded a planning disposition for each research question; empirical results remain pending.

All three plan structures and their sequential dependencies were checked. All four Phase 1 requirement IDs are covered, and all seven automated verification commands state an observable failure condition. The command-path probe reports `not_applicable` for `xcodebuild`; the project scheme, unit-test target, and available simulator destination were checked separately. This is verification of the plans, not a successful app build or test run.
