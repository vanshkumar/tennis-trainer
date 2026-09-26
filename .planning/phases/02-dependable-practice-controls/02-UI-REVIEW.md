# Phase 2 — UI Review

**Audited:** 2026-09-26
**Baseline:** Abstract six-pillar standards adapted to the existing native SwiftUI practice controls; no UI-SPEC exists.
**Screenshots:** Not captured. This is a code-only audit; independent simulator verification belongs to the parent workflow. No browser, Xcode, simulator or screenshot commands were run by this reviewer.
**Scope:** Phase 2 permission, capture, seeking, replay and import controls. Existing media geometry belongs to Phase 3. No visual, hardware, measured contrast or physical audio evidence is claimed.

The existing `.planning/ui-reviews/.gitignore` covers PNG/WebP/JPEG/GIF/BMP/TIFF; directory existence and `git check-ignore` for PNG/WebP were verified before any possible capture. Native project: web dev-server detection, web breakpoints, Tailwind rules, 60/30/10 quotas and shadcn registry checks are not applicable. No `components.json` exists. Project skill directories are absent and `agent_skills` is empty.

## Incremental Recheck — 2026-09-26

**Current source assessment: 23/24 (original: 17/24).** Seven original findings are resolved in the inspected code, including the conditional-removal correction in `212f17e`. UI-05 remains an inherited layout recommendation requiring rendered confirmation. The parent subsequently reproduced an empty pose-group regression in the first UI-02 fix; its failed attempt and corrective source recheck are recorded below. No tests, simulator, browser or screenshot commands were run by this reviewer; the parent owns the final full gates, whose rerun remains pending. A 4/4 below means no remaining issue found within this pillar's inspected source scope; it is not a visual, accessibility-device or hardware pass.

### Current Pillar Scores

| Pillar | Original | Current | Evidence and disposition |
|--------|----------|---------|--------------------------|
| Copywriting | 3/4 | 4/4 | UI-01 resolved: selection-aware recovery messages match preserved/empty selection |
| Visuals | 3/4 | 4/4 | UI-02 resolved: each mode groups pose markers into one named tracking summary |
| Color | 3/4 | 4/4 | UI-03 resolved: routine permission states use primary; denied/unavailable use red |
| Typography | 3/4 | 4/4 | UI-04 resolved: capture status now uses callout, distinct from caption diagnostics |
| Spacing | 3/4 | 3/4 | UI-05 remains: fixed action rows have no large-text alternative; actual fit remains unmeasured |
| Experience Design | 2/4 | 4/4 | UI-06–08 resolved: slider has spoken semantics, loading disablement and actual-duration range |

### Resolution Evidence

- **UI-01 — RESOLVED IN CODE.** `VideoPlayerManager.swift:327` selects `Your previous video is ready to play.` when `hasLoadedItem` is true and retains the Choose prompt when empty. Cancellation (`:205`), provider failure (`:216`) and candidate failure (`:324`) all use the helper. UI test source now asserts the two distinct cases (`Tennis_TrainerUITests.swift:21`, `:29`, `:48`).
- **UI-02 — RESOLVED IN CORRECTED CODE; FINAL RERUN PENDING.** Both pose ZStacks ignore individual child accessibility elements, expose `Right arm tracking` with the visible joint count and keep the overlay identifier. The initial fix relied on `.accessibilityHidden(true)` for an empty group. The parent-reported gate `/tmp/tennis-phase2-post-review-checks/ui-46767432.xcresult` failed `testVisibleOverlayClearOnStopAndPause` at `Tennis_TrainerUITests.swift:87`: after Stop, the empty pose group still existed in the XCTest UI tree. This failed attempt is retained as evidence and is not a passing gate. Commit `212f17e`, inspected in source, now conditionally constructs the entire camera group only when a right-arm joint exists (`ContentView.swift:150`) and does the same for playback (`:289`); the former accessibility-hidden fallback is removed. Clearing pose therefore removes the group from the SwiftUI view structure. Marker coordinates/sizes and populated-group semantics remain unchanged. This addresses the reproduced cause in code; the complete gate is rerunning and no successful result is claimed yet. Physical VoiceOver traversal remains a separate human check.
- **UI-03 — RESOLVED IN CODE.** `ContentView.swift:242` applies red only to denied/unavailable access and `.primary` otherwise. This closes the routine-state semantic inconsistency. It does not establish contrast of the rest of the existing colored controls.
- **UI-04 — RESOLVED IN CODE.** The actual capture status uses `.callout` (`ContentView.swift:188`); neighboring FPS/Frames/Joints remain captions. The hierarchy change directly addresses the original finding. Current explicit font inventory is seven captions, one callout, two title2 and one body; all are native semantic sizes. Rendered wrapping remains unmeasured.
- **UI-05 — REMAINS, WARNING / HUMAN CHECK.** Current action rows are `ContentView.swift:209` and `:369`, circular primary clipping is at `:225` and `:385`, and the bottom safe-area inset is at `:422`. The layout is unchanged in the relevant respect. Inspect smallest supported portrait and accessibility text sizes before deciding whether an adaptive row/scrolling change is necessary. No clipping or unreachable-action failure has been reproduced; this is not a phase blocker.
- **UI-06 — RESOLVED IN CODE.** `ContentView.swift:356` names the native adjustable slider `Playback position`; `:357` supplies elapsed and total seconds to one decimal. It retains the native Slider and its adjustment binding. `testShortClipSliderUsesActualDurationAndAccessibleTime` asserts the label and time value (`Tennis_TrainerUITests.swift:57`). Source review verifies the semantics exist, not their physical spoken delivery or locale-specific pronunciation.
- **UI-07 — RESOLVED IN CODE.** `.disabled(videoPlayerManager.isLoading)` now applies to the slider (`ContentView.swift:358`) consistently with Play (`:381`). Import UI test source checks disabled during a pending replacement and re-enabled after failure, success and cancellation (`Tennis_TrainerUITests.swift:28`, `:35`, `:42`, `:50`). No execution result is claimed here.
- **UI-08 — RESOLVED IN CODE.** The positive-duration branch now uses `0...videoPlayerManager.duration` (`ContentView.swift:353`), with its getter bounded to that same duration (`:349`). DEBUG `playback-short` supplies 0.5 seconds (`AppRuntime.swift:85`). The new test seeks to normalized midpoint and end, checks a midpoint within 0.1…0.4 seconds and the exact 0.5-second endpoint (`Tennis_TrainerUITests.swift:65`). This checks the intended regression in test source; the parent must establish that the test runs successfully.

### Current Priority Disposition

All three original priority fixes (UI-06, UI-07, UI-08) are resolved in source. **Open concrete priority defects: 0. Remaining recommendation: 1 (UI-05). Proven blockers: 0.** Do not invent replacement defects to fill a top-three list. The next checks are the parent-owned full test gates, small-screen/large-text fit, and physical VoiceOver/light-dark/contrast review. The pending human checks below remain pending in full.

## Original Audit Record — Before Incremental Fixes

The remainder preserves the original eight findings, scores and source line references for traceability. Statements describing absent semantics or old copy below are historical observations, superseded by the resolution evidence above; they are not claims about current source. Original additional recommendations numbered five; only UI-05 remains after this recheck.

## Original Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | Cancellation directs players to another video even when the prior clip is preserved |
| 2. Visuals | 3/4 | Pose markers become multiple identically named accessibility elements |
| 3. Color | 3/4 | Routine permission/requesting states inherit the same red treatment as denial |
| 4. Typography | 3/4 | Important new camera failure/status text uses the diagnostic caption tier |
| 5. Spacing | 3/4 | Fixed action rows lack a large-text layout alternative; actual fit is unmeasured |
| 6. Experience Design | 2/4 | Slider semantics, loading enablement and short-clip range do not match its operation |

**Overall: 17/24**

Scores describe the reviewed source, not visual acceptance. No code-proven task-completion blocker was found. All eight recommendations below are WARNING findings; unmeasured rendering concerns are not shipping blockers by themselves. Strong lifecycle test evidence does not raise unrelated pillar scores.

## Top 3 Priority Fixes

1. **Name and describe the playback slider (UI-06)** — VoiceOver has no app-supplied purpose or elapsed/total time for the adjustable control. Add a `Playback position` accessibility label and a localized spoken elapsed/total value; verify adjustment and announcement in the rendered accessibility tree.
2. **Disable seeking during replacement (UI-07)** — After choosing a replacement while an old clip exists, the slider remains enabled while its setter is ignored. Apply `.disabled(videoPlayerManager.isLoading)` and verify re-enablement after success, cancellation and failure.
3. **Use the actual valid clip duration (UI-08)** — A valid 0.5-second clip is represented by a 0…1 slider, although the manager clamps seeks at 0.5. Use `0...duration` inside the existing positive-duration branch; check halfway and end positions for a sub-second clip.

## Detailed Findings

### Pillar 1: Copywriting (3/4)

**UI-01 — WARNING, Phase 2 copy; code-proven mismatch.** `Tennis Trainer/VideoPlayerManager.swift:203` always says `Video selection cancelled. Choose another video.` Trigger: cancel a replacement with a previously loaded usable clip. The existing selection remains paused and Play is available, but the message only directs the player away from it. `:214` and `:322` similarly omit the preserved-clip option after failure. Use selection-aware copy such as `Selection cancelled. Your previous video is ready to play.` for replacements; keep a Choose prompt for the empty state. Do not frame an intentional cancellation as a failure. Current UI tests assert the old string at `Tennis TrainerUITests/Tennis_TrainerUITests.swift:21` and `:41`; update these with the copy.

Positive evidence: Request Permission, Open Settings, Start/Stop/Retry and Play/Pause/Replay express concrete actions. Restricted access has an explanatory next step (`ContentView.swift:240`). Seek/playback errors explicitly offer Play to retry. Contextual `Cancel` beneath `Loading video…` is adequate and is not flagged merely for being a generic word.

### Pillar 2: Visuals (3/4)

**UI-02 — WARNING, Phase 2 accessibility additions; code-proven semantics gap.** The three possible joint markers are each accessibility elements named `Pose overlay`, with no joint identity or useful value (`Tennis Trainer/ContentView.swift:150`, `:155`, `:285`, `:289`). Trigger: a pose with multiple detected joints. The accessibility tree can contain several indistinguishable noninteractive elements before the controls. Consolidate the markers into one meaningful tracking summary or hide decorative markers from assistive navigation while preserving a testable overlay-container identifier. Keep the visual overlay and clearing behavior intact. This finding concerns the semantics attached to visuals, not a claim about observed VoiceOver focus movement.

Positive evidence: text-labeled control actions, segmented mode picker and clear empty/loading/error state branches exist. No unlabeled icon-only button was found. Media is structurally the primary display. Rendered focal balance and overlay legibility were not inspected.

### Pillar 3: Color (3/4)

**UI-03 — WARNING, inherited styling applied to new Phase 2 states; code-proven semantic inconsistency.** All permission messages receive `.foregroundColor(.red)` at `Tennis Trainer/ContentView.swift:238`, including normal `Camera permission required` and `Requesting access…` strings (`CameraManager.swift:11`). Use a neutral semantic foreground for routine/requesting states and reserve error emphasis for denied/unavailable conditions. Restriction remains explained in words. This is not a measured contrast violation.

Code inventory: five filled custom action backgrounds use state/action colors: capture red/green (`:219`), Test Beep blue (`:228`), playback orange/green (`:372`), replacement blue (`:380`) and first selection blue (`:403`). Media/status panels use black or translucent black and white text; the empty-state helper uses `.secondary`. Text labels distinguish actions independently of color. Native named colors are not hex literals or third-party brand tokens; no web accent quota is imposed. White-on-green/orange button text, the white slider, translucent panels and disabled appearance still need rendered light/dark and Increase Contrast inspection.

### Pillar 4: Typography (3/4)

**UI-04 — WARNING, new Phase 2 status in inherited diagnostic layout; code-proven hierarchy weakness.** `Tennis Trainer/ContentView.swift:181` renders actual capture state and failure explanation using the same `.caption` at `:184` as FPS/Frames/Joints (`:175`, `:178`, `:193`). Trigger: configuration/start failure or interrupted recovery, when the state message is the actionable explanation for Retry or waiting. Promote that status to the native body/callout tier and separate it from diagnostic text; retain concise captions for counters. No measured readability failure is claimed.

Font inventory: three explicit semantic styles (`caption`, `title2`, `body`), with eight caption declarations, two title2 declarations and one explicit body declaration; other labels inherit native defaults. No explicit custom font weight or fixed-point text size occurs in ContentView. This supports Dynamic Type in principle. Actual wrapping, truncation and larger accessibility sizes remain untested; semantic fonts alone do not establish layout fit.

### Pillar 5: Spacing (3/4)

**UI-05 — WARNING, inherited layout exposed to Phase 2 labels; structural risk requiring rendered confirmation.** The capture action/Test Beep row (`Tennis Trainer/ContentView.swift:205`) and playback action/Choose New Video row (`:358`) have no vertical fallback. The latter uses 20-point spacing, outer default padding and a circular clipped primary button (`:374`). The screen has no ScrollView or accessibility-size layout branch, while loading/error content consumes a bottom safe-area inset (`:411`). Longer Retry/Replay/error text and larger Dynamic Type can compete for the available portrait width/height. This is a code-visible lack of adaptation, **not a reproduced clipping or unreachable-control defect**. Inspect the smallest supported portrait size at accessibility text sizes; use a fitting/vertical action layout and scrollable controls where evidence shows it is needed. Do not redesign the media geometry in this phase.

Spacing inventory: native default padding plus explicit 8-point panel padding, 16/12-point replacement-button padding, and stack spacing 0/8/20. The 6-point joint markers and 14-point ball ring are visual marks, not undersized touch targets. No UI-SPEC spacing scale exists, so these native values are not arbitrary-token violations. Actual button hit regions and safe-area reachability are human checks.

### Pillar 6: Experience Design (2/4)

**UI-06 — WARNING, inherited slider semantics omitted while Phase 2 adds control identifiers; code-proven omission.** `Tennis Trainer/ContentView.swift:340` constructs a label-less Slider. Its only accessibility modifier is an identifier at `:347`; identifiers support tests, not a spoken user-facing name. Neighboring time Text views do not explicitly label or provide the slider's spoken value. Trigger: navigating to the seek control using VoiceOver. Add a label and elapsed/total accessibility value, preserving native adjustable behavior. Existing seek UI tests query the identifier and never assert a meaningful slider label/value; source evidence does not establish exactly what the OS currently announces.

**UI-07 — WARNING, Phase 2 loading/control integration; code-proven behavior mismatch.** With a committed clip, begin a replacement and return from the picker while the provider/candidate remains pending. The slider at `ContentView.swift:340` remains enabled, but `VideoPlayerManager.seek(to:)` returns immediately when `isLoading` is true (`VideoPlayerManager.swift:544`). Play correctly disables at `ContentView.swift:370`, making the inconsistency explicit. Disable the slider for the same loading interval and test enablement recovery for successful, failed and cancelled replacements. This affects a temporary control state, not selection preservation or file ownership.

**UI-08 — WARNING, inherited range retained in Phase 2 seek path; code-proven short-clip mismatch.** `ContentView.swift:345` uses `0...max(duration, 1)`, whereas valid metadata accepts every finite positive duration (`VideoPlayerManager.swift:30`) and seeks clamp at the actual duration (`:545`). For a 0.5-second video, the end position occupies only half the slider and the upper half requests values the backend clamps to the same endpoint. Use the actual positive duration; no one-second floor is required inside this branch. Add a focused short-duration control/range check. The 30-second DEBUG scenarios do not expose this case.

Positive state coverage: empty selection offers Choose; loading shows progress and Cancel; failed/cancelled imports preserve the previous paused selection; permission requests disable duplicates; denied access offers Settings; restriction omits misleading actions; Stop stays available during requested startup/recovery; Replay is distinct from Play; scene suspension invalidates current intent. No destructive action requiring a confirmation was found. Existing tests exercise these real SwiftUI controls through injected effects, including overlay clearing, but were not rerun by this reviewer.

## Pending Human and Rendered Checks

- VoiceOver slider name, elapsed/total value and adjustable behavior; tracking-overlay focus order.
- Smallest supported portrait device and accessibility Dynamic Type: Start/Stop/Retry, Play/Pause/Replay, replacement, loading Cancel and long error messages remain readable and reachable.
- Light/dark, Increase Contrast, disabled slider/buttons, and bright/dark live-preview backgrounds; measure contrast before claiming a failure or pass.
- Physical permission/Settings/revocation, startup/interruption/recovery, and representative permitted-video scrubbing/end/Replay remain pending under `docs/references/practice-controls-validation.md`. No source inspection or injected scenario closes those obligations.

There are **3 priority fixes and 5 additional recommendations**, eight unique WARNING findings total, and zero proven BLOCKER findings. Rendering checks do not count as additional defects. Existing summary test results are prior implementation evidence, not independently executed audit results.

## Files Audited

- `LEARNINGS.md`, `AGENTS.md`, `docs/README.md`, `ARCHITECTURE.md`, `.planning/config.json`
- All four `02-01` through `02-04` PLAN and SUMMARY files in this phase directory
- `Tennis Trainer/ContentView.swift`
- `Tennis Trainer/VideoPickerView.swift`
- `Tennis Trainer/VideoPlayerView.swift`
- `Tennis Trainer/CameraPreview.swift`
- `Tennis Trainer/AppRuntime.swift`
- `Tennis Trainer/CameraManager.swift`
- `Tennis Trainer/VideoPlayerManager.swift`
- `Tennis TrainerUITests/Tennis_TrainerUITests.swift`
- `docs/references/practice-controls-validation.md`
- `.planning/ui-reviews/.gitignore`

Report-only audit: no source/test/learning changes or commits. The parent owns final test evidence, any fixes and shared learning updates.
