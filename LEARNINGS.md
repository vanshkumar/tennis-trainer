# Learnings

## What Has Worked

## Patterns and Preferences

## What Has Failed

## Task Notes

**2026-09-26 — Camera startup and notification reconciliation**
- Observation: A failed physical start left captureRequested true and blocked every later Start. A successful start can also become obsolete before its state publication; the injected tests reproduce Stop during configure/start and backend changes before delivery.
- Action: Retire failed intent into a visible Retry state, inspect current backend state after dispatch, and physically stop a start whose operation was retired while AVFoundation was running. Keep one automatic recovery budget per explicit Start and reopen analysis only after the callback queue drain.
- Confidence: high

**2026-09-26 — Camera permission callback ownership**
- Observation: A held permission callback can report grant after the current authorization snapshot is denied, and one outstanding OS request can span Stop followed by a new explicit Start. The camera tests distinguish request identity from current capture intent and query authorization after state delivery.
- Action: Keep request coalescing separate from capture operation identity; let only current OS authorization and an active explicit Start reopen capture. A permission-only request or Settings grant must leave the camera stopped.
- Confidence: high

**2026-09-26 — Lifecycle regression simulator recovery**
- Observation: The full Phase 2 unit run passed its lifecycle tests but Xcode could not launch its second parallel simulator clone. Re-running the same complete unit target with `-parallel-testing-enabled NO` passed all 82 tests, including the Swift Testing scaffold.
- Action: If a future full run fails at parallel clone launch, retain that infrastructure evidence and rerun the complete target serially; require all class counts and zero skips before accepting the result.
- Confidence: medium

**2026-09-26 — Phase 2 playback plan review**
- Observation: Item/load identity alone in the draft end-event guard could not distinguish a queued notification from a previous playback timeline after seeking or replaying the same item. The independent checker caught this before implementation.
- Action: Bind end/error events to their originating playback run or reconcile fresh backend state after dispatch. Hold same-item notifications across a successful newer seek/Replay and verify the current run continues while valid current events still work.
- Confidence: high

**2026-09-26 — Phase 2 lifecycle planning**
- Observation: Source inspection found both media managers sharing one pose presenter while invalidated publications can clear it, and camera ingress checks its enabled flag separately from analysis admission. These expose old-mode clearing and Stop/Start admission races beyond Phase 1's manager-generation tests; they have not yet been reproduced by Phase 2 tests.
- Action: Test an old mode's delayed clear after the new mode publishes pose, plus acquired and queued camera callbacks crossing Stop/Start. Require mode-owned or source-gated presentation and an ingress boundary that cannot assign old frames to a fresh generation.
- Confidence: medium

**2026-09-26 — Phase 1 human acceptance**
- Observation: The user separately passed the evidence-limit review, original-five-frame association contract, and exact source/session/frame pose with the strict fallback above 0.70. These decisions resolve Phase 1's previously undefined edge obligations without adding runtime measurements.
- Action: Use `01-UAT.md` as the human acceptance record and preserve the Phase 4 clip/device/process-memory/audio obligations when describing Phase 1 as complete.
- Confidence: high

**2026-09-26 — Phase 1 UAT coverage precheck**
- Observation: The verify-work API gate parsed `01-COVERAGE.md`, which contains requirements coverage, as an API matrix and rejected it as empty. The phase only changes the existing on-device pipeline.
- Action: Keep the supported `No external API integration: <reason>` declaration in this phase's coverage document; preserve the requirements tables and enabled gate rather than inventing API rows.
- Confidence: high

**2026-09-25 — Phase 1 verification handoff**
- Observation: GSD rejected this roadmap's Phase 1 MVP goal until the existing goal was expressed as an "As a / I want to / so that" user story. After that correction, all deterministic checks passed, but the planned claims review and two unclassified edge items still required human resolution.
- Action: Validate MVP goal syntax before future phase execution, and preserve explicit human-review items in UAT even when implementation tests pass; do not mark an undefined edge probe as verified.
- Confidence: high

**2026-09-25 — Preparation buffer lifetimes**
- Observation: Two concurrent GridTrackNet preparations reached 16 distinct buffers as expected, but Core Image autoreleases kept two oriented intermediates alive into prediction (14 instead of 12). A scoped preparation autorelease pool released them before prediction without changing pixels or the eight-buffer cap.
- Action: Keep preparation and prediction temporary owners in scoped autorelease pools; verify weak buffer identities and raw-buffer destruction while worker and publication stages are held, rather than counting array entries alone.
- Confidence: high

**2026-09-25 — Bundled GridTrackNet output representation**
- Observation: The packaged model runs on the iOS 26.5 simulator and returns all three FP16 heads as `[1, 5, 48, 27]` with strides `[7680, 1536, 32, 1]`; the older reference omitted the singleton batch and spatial padding.
- Action: Accept only the explicit semantic five-frame/48×27 layouts and validate each head inside scoped byte access. Keep the bundled smoke separate from independently padded synthetic fixtures and from clip-accuracy claims.
- Confidence: high

**2026-09-25 — Rational cue boundary fixtures**
- Observation: Constructing the intended 4.1-second test timestamp with `CMTime(seconds:preferredTimescale:)` produced a value below the intended exact cooldown boundary; a seconds-based fixture obscured the distinction between a real rejection and rounding in test setup.
- Action: Build exact cooldown, equality, and horizon fixtures with integer `CMTime(value:timescale:)` values. Assert consumed/evaluated counts separately from cue counts.
- Confidence: high

**2026-09-25 — Owned prediction windows**
- Observation: The `.up`/768×432 preparation path retained the capture buffer directly; mutating its source changed the retained sentinel from 42 to 99. Allocating through the existing unit-scale resize path preserved the original pixels.
- Action: Keep preparation allocation unconditional for retained model frames and pass the same five-record snapshot through prediction and decoding; never re-read ring metadata after prediction.
- Confidence: high

**2026-09-25 — Bounded analysis publication**
- Observation: A track callback can synchronously reset its own `BallDetectionManager`; checking generation only when entering publication still allowed the pending apex callback to fire. The regression reproduces this without sleeps or model execution.
- Action: Recheck generation after observable pose/ball updates and track callbacks; hold the lease through the entire effect batch. Coalesce idle resets into one clearing publication and defer model clearing to its worker.
- Confidence: high

**2026-09-25 — Media ingress tracer**
- Observation: Adding a Swift overload to the display-link callback made its `#selector` reference ambiguous under Xcode 27; an explicitly named `processDisplayLinkFrame` callback compiles while the testable output-reader adapter retains `processCurrentFrame`.
- Action: Keep the Objective-C display-link selector unambiguous when extending the playback adapter; verify real capture PTS and copied display time through injected manager tests.
- Confidence: high

**2026-09-18 — Xcode Cloud manifest**
- Observation: `Tennis Trainer.xcodeproj/xcshareddata/xcodecloud/manifest.json` records project and target IDs, but does not define workflow triggers or TestFlight distribution.
- Action: Use the manifest for target association; continue checking Xcode Cloud workflow settings separately when verifying releases.
- Confidence: high

**2026-06-29 — Live camera stop responsiveness**
- Observation: `CameraManager` previously used the same serial queue for `AVCaptureVideoDataOutput` frame callbacks and `AVCaptureSession` start/stop calls, so stop requests could wait behind expensive Vision/Core ML frame processing.
- Action: Keep capture-session lifecycle work on a dedicated session queue, send frame analysis to a separate video-processing queue, and gate frame callbacks immediately when stop is requested.
- Confidence: high

**2026-06-29 — Xcode Cloud release trigger**
- Observation: The local release branch is `main` tracking `origin/main`, but Xcode Cloud workflow triggers and TestFlight distribution settings are not stored in this repo.
- Action: When asked to update TestFlight from this repo, commit only the intended files and push `main` without staging unrelated local worktree changes, then confirm the Xcode Cloud workflow has a `main` trigger, archive action, TestFlight distribution, and build-number handling.
- Confidence: medium

**2026-06-29 — Build numbering for cloud releases**
- Observation: This repo does not currently include `ci_scripts`, and `CURRENT_PROJECT_VERSION` is set to `1` in the Xcode project, so repo-side build-number bumping is not configured.
- Action: If Xcode Cloud uploads fail or no new TestFlight build appears, check whether the workflow manages build numbers server-side or add a `ci_post_clone.sh`/project setting flow to set a unique build number before archive.
- Confidence: medium

**2026-06-29 — App Store icon validation**
- Observation: The app is portrait-only, and setting the app target to `TARGETED_DEVICE_FAMILY = 1` makes Release asset compilation use `--target-device iphone` while the compiled product can still include the required `AppIcon60x60@2x.png` and `AppIcon76x76@2x~ipad.png` compatibility icon files.
- Action: For TestFlight validation fixes, keep `INFOPLIST_KEY_CFBundleIconName = AppIcon`, keep concrete PNG-backed `AppIcon.appiconset` entries, and verify the built Info.plist has `UIDeviceFamily = [1]` plus `CFBundleIconName = AppIcon`.
- Confidence: high

**2026-09-18 — GSD installation**
- Observation: GSD Core 1.14.0 was installed globally for Codex in `~/.codex`; this repository does not need a local GSD installation. The desktop shell did not expose `npx`, but the existing mise Node installation at `~/.local/share/mise/installs/node/24.16.0/bin` supplied it.
- Action: Use the global GSD skills for this project; when running npm tools from the desktop shell, include the installed mise Node bin directory in PATH.
- Confidence: high

**2026-09-19 — Codebase mapping**
- Observation: `BallDetectionManager` checks and resets `isInFlight` inside closures submitted to its serial inference queue, so the flag does not reject queued requests. `GridTrackNetDetector` also reads timestamps and frame mappings separately from the synchronized prediction, permitting input metadata to drift between those operations.
- Action: When planning inference reliability work, verify queue admission and capture frames, timestamps, and mappings together; do not assume the PRD's stated single-flight drop policy is implemented by this flag.
- Confidence: high

**2026-09-24 — GSD project initialization**
- Observation: The approved first milestone is reliability of the existing toss-apex cue in both live-camera and saved-video modes, including synchronization, stale-feedback prevention, overlay alignment, permission recovery, playback lifecycle, and clip/device validation.
- Action: Use `.planning/PROJECT.md` as the milestone scope; keep trophy/contact cues and other strokes deferred while retaining portrait, right-handed solo practice.
- Confidence: high

**2026-09-24 — GSD workflow preferences**
- Observation: This project uses automatic execution within approved scope, coarse phases, parallel work, Git-tracked planning docs, inherited agent models, full instructions, research, plan checks, verification, and source-drift checks. Extra PR sections are disabled.
- Action: Preserve these choices in `.planning/config.json` when resuming initialization or running phase workflows; do not re-prompt for preferences already approved.
- Confidence: high

**2026-09-25 — Reliability roadmap**
- Observation: The user approved all 17 reliability requirements and the four-phase roadmap organized around complete user outcomes. Clip/device evidence is not yet available, and the accepted requirements call for criteria fixed before final scoring.
- Action: Keep requirement ownership explicit in `.planning/ROADMAP.md`; begin validation protocol and baseline collection with the first implementation phase, then consolidate final evidence after the fixes instead of postponing all tests and fixture acquisition until the last phase.
- Confidence: high

**2026-09-25 — Phase 1 test planning**
- Observation: `AppRuntime.isRunningTests` suppresses camera/audio setup, but direct `BallDetectionManager` construction eagerly creates the Core ML detector, and `VideoPlayerManager.setupBallDetection` does not suppress that construction.
- Action: Inject fake inference and pose dependencies before production services are constructed when adding deterministic pipeline tests; do not assume the existing test guard makes every manager safe to instantiate.
- Confidence: high

**2026-09-25 — Local simulator preflight**
- Observation: This host currently has Xcode 27.0 and an available iPhone 17 Pro simulator on iOS 26.5; the repository's example iPhone 15 destination is absent. Reading CoreSimulator state succeeded after sandbox escalation.
- Action: Use the discovered iPhone 17 Pro/iOS 26.5 destination for Phase 1 test commands, recheck availability in future sessions, and distinguish sandbox service-access errors from app test failures. Keep the app's iOS 18.5 deployment target.
- Confidence: high

**2026-09-25 — Pose fallback plan review**
- Observation: The initial Phase 1 plan conflated invalid frame/window metadata, which rejects analysis, with mismatched per-sample pose, which must become missing and use the existing height fallback under CUE-04.
- Action: Keep these failure cases separate in implementation and tests. For mismatched pose, test a cue above 0.70 and suppression at/below 0.70 with valid frame metadata, cooldown satisfied, and all other eligibility conditions met.
- Confidence: high
