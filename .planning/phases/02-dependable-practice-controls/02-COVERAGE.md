# Phase 2 planning coverage

No external API integration: this phase fixes existing on-device AVFoundation, PhotosUI and SwiftUI lifecycle and local-file ownership; it adds no service, endpoint, external SDK integration or package installation.

Planning status: verified on 2026-09-26 before implementation. User selected Continue without context on 2026-09-26; no CONTEXT.md or locked D-NN decisions exist. Research recommendations are implementation choices, not new user decisions. UI-SPEC is absent and the deterministic UI gate is nonblocking; plans preserve native controls and existing geometry.

Execution update: all four plans are implemented. Current test/review results live in the four SUMMARY files, the phase REVIEW/UI-REVIEW/SECURITY/VERIFICATION reports and `docs/references/practice-controls-validation.md`. The tables below preserve planning provenance; COVERED means assigned in plans, not human acceptance. EDGE-CAM-01 and EDGE-PLAY-04 now have explicit deterministic implementation evidence. The six unclassified edge rows and evidence-limit prohibition remain pending human disposition, together with the recorded device checks.

## Source audit

| Source | ID | Feature or constraint | Plan/task | Disposition |
|---|---|---|---|---|
| GOAL | Phase 2 | Control live practice/review so old work cannot produce feedback or take over current session | 02-01 through 02-04 | COVERED |
| GOAL | Success 1 | All control transitions invalidate held worker and queued publication; fresh warmup | 02-01.1–2, 02-03.1–2, 02-04.1–3 | COVERED |
| GOAL | Success 2 | Permission recovery and actual capture state honoring Stop | 02-02.1–2 | COVERED |
| GOAL | Success 3 | Latest successful seek, end and Replay; stale same-item end/error cannot stop or overwrite the newer timeline | 02-03.1–2 | COVERED |
| GOAL | Success 4 | Rapid replacement/cancellation/failure and all stale callbacks | 02-04.1–2 | COVERED |
| GOAL | Success 5 | Single loop and owned cleanup, originals preserved | 02-03.1–2, 02-04.1–3 | COVERED |
| REQ | LIFE-01 | Stop/Pause/seek/replacement/end/mode exit suppress overlays/new automatic cue scheduling | 02-01, 02-02, 02-03, 02-04 | COVERED |
| REQ | LIFE-02 | Every reset starts fresh temporal evidence and cannot cue retrospectively | 02-01, 02-02, 02-03, 02-04 | COVERED |
| REQ | CAM-01 | Undetermined request, denied Settings, restricted explanation, active return recheck | 02-02.1 | COVERED |
| REQ | CAM-02 | Actual capture status; Stop wins over startup/interruption/recovery | 02-02.2 with 02-01.1 boundary | COVERED |
| REQ | PLAY-01 | Latest successful current seek plus still-requested play | 02-03.1 | COVERED |
| REQ | PLAY-02 | Ended and completion-gated Replay from zero, fresh window/cooldown | 02-03.2 | COVERED |
| REQ | PLAY-03 | Current candidate only, preserve usable selection on failed/cancelled import | 02-04.1–2 | COVERED |
| REQ | PLAY-04 | Single processing loop, explicit original-owner teardown and unique owned copies | 02-03, 02-04 | COVERED |
| RESEARCH | Architecture/Patterns 1 | Main-state intent before asynchronous AV effects; identity checked after executor hop | All task actions | COVERED |
| RESEARCH | Ingress proof | Acquired-buffer check/admission race AND already queued old buffers on reopening | 02-01.1 expected-generation admission and stop/detach/drain | COVERED |
| RESEARCH | Presentation proof | Old-mode pose clearing and nested ball observation | 02-01.2, 02-04.3 visible-clear UI check | COVERED |
| RESEARCH | Pattern 2 | Separate session/video queues, idempotent configuration, actual state observations and bounded recovery | 02-01.1, 02-02.1–2 | COVERED |
| RESEARCH | Pattern 3 | Current item/load/seek identities, false completion, finite seek bounds and Replay gating; captured timeline event owner plus fresh reconciliation for ambiguous native events | 02-03.1–2; 02-04.3 preserves event-owner retirement | COVERED |
| RESEARCH | Pattern 4 | Playable media, finite positive duration, video track, readiness and current atomic candidate commit | 02-04.2 | COVERED |
| RESEARCH | Pattern 4 | Cancel provider Progress/metadata task and guard late successes/errors; picker dismissal differs from cancellation | 02-04.1–2 | COVERED |
| RESEARCH | Pattern 5 | Copy inside provider lifetime; unique destination and external/owned distinction | 02-04.1 | COVERED |
| RESEARCH | Pattern 5 | Leases survive cancelled consumers; delete after teardown; preserve unknown legacy files | 02-04.1–3 | COVERED |
| RESEARCH | Resource table | Original player/item token/output pairs, weak events/link target, explicit owner shutdown | 02-02.2, 02-03.2, 02-04.3 | COVERED |
| RESEARCH | Test seams | Inject before real model/camera/audio creation; production controls and held completions, rational CMTime | 02-01.1–2 and new manager tests | COVERED |
| RESEARCH | Positive recovery | Fresh successful camera/clip cue after negative stale tests | 02-01.1–2, 02-02.2, 02-03, 02-04.2 | COVERED |
| RESEARCH | Native UI checks | Permission/current status, pending seek Pause, Ended/Replay, import recovery, visible clearing | 02-02, 02-03, 02-04.3 | COVERED |
| RESEARCH | A1/platform integration | Fake effects do not fully prove platform timing; real AV integration and physical checks needed | 02-04.3 generated local movie plus explicit human checks | COVERED; hardware evidence pending execution |
| RESEARCH | Security | ASVS 5.0 L1 applicable native boundaries; high findings block; validate media, permission, identity and ownership | Every plan threat_model | COVERED |
| RESEARCH | Preserved scope | Native Apple stack/iOS 18.5/target/bundle; model/preprocessing; strict fallback above 0.70/four-second cooldown; local-only processing | Every plan constraints and Phase 1 full regression | COVERED |
| RESEARCH | Evidence limits | Real Settings/interruption/capture/device/audio/clip checks not inferred from unit tests | 02-02 human checks, 02-04.3 ledger and prohibition | COVERED |
| RESEARCH | Open question 1 | Hardware planning treatment resolved as execution-evidence obligation; availability/results remain unknown | 02-02.1–2 human checks; 02-04.3 ledger/review | RESOLVED planning disposition; hardware evidence pending |
| RESEARCH | Open question 2 | Native camera status wording and corresponding actionable controls adopted | 02-02.1–2 | RESOLVED planning disposition |
| RESEARCH | Open question 3 | Unknown legacy temp files remain untouched; cleanup requires explicit ownership | 02-04.1, 02-04.3/T-02-16 | RESOLVED planning disposition |
| RESEARCH | Open question 4 | Cancelled consumers retain file leases until actual completion/retirement and final release | 02-04.1–3 | RESOLVED planning disposition |
| CONTEXT | Absent by user choice | No D-NN decision coverage to fabricate; preserve approved PROJECT/REQUIREMENTS | All plans | NOT APPLICABLE; explicit absence |

Exclusions are approved scope boundaries, not omissions: Phase 3 owns overlay coordinate placement; Phase 4 owns final labeled-clip accuracy, sustained device/process-memory and physical-audio scoring. No new cues, strokes, left-handed/multiplayer support, landscape app UI, cloud services, model replacement, threshold controls or UI redesign are planned. Existing manual Test Beep remains separate from automatic-cue scoring. No unknown legacy temporary-file migration is authorized.

## Task dependencies and ownership

| Plan | Wave | Needs | Produces | Tasks | Checkpoints |
|---|---:|---|---|---:|---|
| 02-01 | 1 | Phase 1 scheduler/window/association contracts | Verified control-to-cue ingress/invalidation tracer, mode/context ownership | 2 | None |
| 02-02 | 2 | 02-01 lifecycle boundary | Camera access/state controls and DEBUG UI effect-injection path | 2 | None; end-of-phase human checks |
| 02-03 | 3 | 02-02 shared ContentView/UI harness, 02-01 analysis boundary | Completion-gated seek/end/replay | 2 | None; end-of-phase human checks |
| 02-04 | 4 | 02-03 player identity/effects, 02-01 lifecycle tests | Import/candidate ownership, complete teardown and evidence ledger | 3 | None; end-of-phase human checks |

Each plan's first task is a production vertical tracer and must pass before expansion. ContentView overlaps all four plans; VideoPlayerManager overlaps 02-01/03/04, and test files overlap their dependent plans. Serial waves deliberately prevent concurrent writers. Each task modifies at most five files; 02-04 has three bounded vertical expansions instead of a single oversized playback task. All decisions concern reversible local runtime code; the shared admission/media-handle contracts are marked costly, not one-way. No new external setup blocks deterministic execution.

Estimate calibration run with installed GSD runtime returned factor 1, sample_count 0, confidence low. Raw/calibrated projections: 28,000 / 25,000 / 26,000 / 34,000 tokens. Estimates describe executor context/implementation effort, not measured actuals.

## Edge Coverage — canonical spec-less fallback

Input: `/tmp/tennis-phase2-edge-coverage.json`, produced by the deterministic edge probe from all eight approved requirement texts. Both SPEC sections were confirmed absent. Fallback is enabled. Original report: applicable 8, resolved 0, unresolved 8. Preserve the original categories; never relabel an unclassified item as a test success.

| Probe item | Original category/status | Authored disposition | Explicit acceptance or flagged assumption | Owner |
|---|---|---|---|---|
| EDGE-LIFE-01 | unclassified / unresolved | FLAGGED UNRESOLVED | Human must classify the undefined edge or explicitly accept control-intent invalidation through both held stages and ingress races; deterministic tests do not resolve the unknown classifier row | 02-01 verification; 02-04.3 ledger/UAT |
| EDGE-LIFE-02 | unclassified / unresolved | FLAGGED UNRESOLVED | Human must classify/accept fresh-window and no-retrospective-cue semantics, including partial toss loss across reset | 02-01 verification; 02-04.3 ledger/UAT |
| EDGE-CAM-01 | concurrency / unresolved | RESOLVED, verification: explicit (acceptance authored; implementation unverified) | Overlapping authorization/Settings-return callbacks preserve current intent/context; late grant never starts after Stop; fresh authorized Start works | 02-02 must_haves.truths and Task 1 |
| EDGE-CAM-02 | unclassified / unresolved | FLAGGED UNRESOLVED | Human must classify/accept actual-state versus requested-intent and Stop dominance during startup/interruption/recovery; injected events alone do not establish hardware delivery | 02-02 verification; 02-04.3 ledger/UAT |
| EDGE-PLAY-01 | unclassified / unresolved | FLAGGED UNRESOLVED | Human must classify/accept latest successful current seek plus current play intent, including latest false completion and retry | 02-03 verification; 02-04.3 ledger/UAT |
| EDGE-PLAY-02 | unclassified / unresolved | FLAGGED UNRESOLVED | Human must classify/accept Ended, Replay zero-seek and fresh-window/cooldown semantics | 02-03 verification; 02-04.3 ledger/UAT |
| EDGE-PLAY-03 | unclassified / unresolved | FLAGGED UNRESOLVED | Human must classify/accept prior usable selection paused after failed/cancelled replacement and current-ready-candidate commit | 02-04 verification; 02-04.3 ledger/UAT |
| EDGE-PLAY-04 | concurrency / unresolved | RESOLVED, verification: explicit (acceptance authored; implementation unverified) | Overlapping imports/callbacks maintain one active link; original-owner resource cleanup and unique owned-copy release settle to current selection only; external originals survive | 02-04 must_haves.truths and Task 3 |

No-silent-drop equality: 8 surfaced = 2 explicit predicates lifted into plan truths + 6 surfaced flagged assumptions. Dismissed 0; backstop 0; unclassified auto-resolved 0. Six unresolved rows require explicit end-of-phase human disposition and must be copied into verification/UAT rather than silently sealed.

## Prohibitions — recall, precision and projection

The per-requirement adversarial recall considered stale feedback, implicit resume, misleading permission actions, false running state, seek supersession, hidden failed selection, repeated loops, overwritten/deleted originals, local-media leakage and overstated test evidence. The first eight behavior/ownership concerns are ordinary correctness already assigned to task acceptance, not bespoke prohibitions. Permission consent, local storage retention/path traversal and generic privacy concerns are canon: covered by the plans' threat registers and `$gsd-secure-phase`, not minted again.

One retained bespoke transparency prohibition applies to the phase's evidence claims:

> MUST NOT present injected lifecycle tests or software cue callbacks as proof of real camera permission recovery, physical capture behavior, clip accuracy, or audible timing.

Canonical projection was actually run via `projectProhibitions` exported from the installed `gsd-core/bin/lib/probe-core.cjs`, with requirement_id LIFE-01, category transparency, status unresolved, null verification/resolution/reason, and the exact statement above. Output is the `statement` + `status: unresolved` entry copied into 02-04's `must_haves.prohibitions`. No check descriptor was authored. It remains flagged-unverified and needs explicit human evidence-limit review; automated lifecycle tests cannot clear it. No-silent-drop equality: 1 retained = 1 projected prohibition + 0 omitted. No auto-dismissal.

## Planner contribution decisions

Contributions were applied in registry order: API coverage, assumption-delta, schema push, security.

- API: detector ran on all plan bodies plus the Phase 2 roadmap section and returned detected:false, signals:[], exit 1 (the documented negative result, not a skipped probe). Reasoned no-integration declaration remains above.
- Assumption delta: detector reported detected:true solely for alongside in the roadmap testing sentence. 02-01 records noun `analysis source/session identity`, decision `no-change`, rationale that Phase 1 identity remains primary and new adapter operation tokens refine it. No new external identity model.
- Schema push: phase/research/plan paths match none of the configured ORM schema/migration patterns. No schema push task applies.
- Security: every plan has concrete trust boundaries, STRIDE IDs, severity and disposition under ASVS Level 1 with block-on-high. No package-manager install exists, so no package-legitimacy checkpoint is required.

## Discovery and source grounding

Current Level 1 platform research is provided in full by 02-RESEARCH.md, including official Apple completion/lifetime sources and installed SDK/environment evidence. No new dependency choice needs deeper discovery. Pattern map is complete and its current source anchors supersede the older codebase map for Phase 1 behavior. Project skill directories, configured agent_skills and knowledge graph were absent; no hidden local skill or graph instruction is assumed.

Tracked existing paths were verified with git ls-files: CameraManager.swift, VideoPlayerManager.swift, BallDetectionManager.swift, ContentView.swift, PoseDetectionManager.swift, VideoPickerView.swift, VideoPlayerView.swift, AppRuntime.swift, AnalysisFrame.swift, AudioManager.swift, GridTrackNetDetector/Decoder/ServeTossApexDetector, AnalysisAssociationTests.swift, BallDetectionManagerTests.swift, existing UI test file, both shared schemes and docs/references/toss-cue-validation.md. All proposed new paths/types/functions/fields appear in each plan's Artifacts this phase produces inventory. Prior-plan SUMMARYs and PracticeLifecycleTests/VideoPlayerManagerTests references are explicitly expected upstream outputs, not existing-at-planning claims.

Plan authoring used the available apply_patch file-edit tool because no separate Write tool is exposed. No source implementation, dependency installation, build or test run occurred during planning.

Planner self-checks: all four frontmatter validations and plan-structure validations passed with no errors/warnings; nine tasks have read_first/action/acceptance_criteria/verify, at most five modified files each, and an immediate fails_when for every automated command. git diff --check passed.

Independent planning review passed after one focused revision, with zero blockers or warnings. The revision added same-item timeline ownership and held end/error-event regressions to 02-03/04, and recorded all four research planning dispositions while preserving unknown hardware evidence. Parent-run structure checks passed for all four plans; all 14 failure-direction checks passed. The command-path resolver reports not_applicable for xcodebuild, not proven target resolution; the existing schemes and proposed test targets remain grounded in the plan/source inventory. The post-planning gap check covers 8/8 requirement IDs, with none missing. These results validate planning documents only, not application behavior or physical-device evidence.

## Verification contract and pending evidence

Inherited full unit command (proven in Phase 1, not rerun while planning):

`xcodebuild test -scheme 'Tennis Trainer' -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' '-only-testing:Tennis TrainerTests'`

Research confirmed that destination available on 2026-09-26; execution must recheck. Focused commands retain scheme/destination and use existing or explicitly created class names. The tracked `Tennis Trainer UI Tests` scheme runs `Tennis TrainerUITests`; new named methods are created in its existing `Tennis_TrainerUITests` class. Every automated task command has an immediate fails_when sibling including nonzero exit and non-vacuous test execution. Cold Xcode builds may exceed 60 seconds; focused behavior runs should remain bounded and real AV waits use bounded XCTest expectations. Do not substitute a no-op source grep for behavioral acceptance.

DEBUG-only scenario injection is created in 02-02, before real effects instantiate, and reused in later plans. It drives production managers and real controls while faking authorization/player/provider effect delivery. It does not bypass controls with direct lower-level frame submissions. The real local-movie integration test in 02-04 additionally exercises AV readiness, seek, end/replay and teardown without requiring personal footage. Neither is a physical camera/audio test.

Outstanding until actually performed: physical camera authorization/Settings return including revocation; available restriction/interruption/startup/Stop scenarios; current-state and visible overlay checks; six undefined edge dispositions; transparency/evidence-limit review. Record device/OS/build and unsupported scenarios. Clip scoring, sustained process memory and physical sound-onset timing remain Phase 4 acceptance, not synthetic-test claims. No Phase 2 requirement is marked complete by these planning artifacts.
