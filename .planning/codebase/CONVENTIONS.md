---
last_mapped_commit: 23b280cf14465d0418d5447422e949b1591f9024
last_mapped_at: 2026-09-19
---
# Coding Conventions

**Analysis Date:** 2026-09-19

## Naming Patterns

**Files:**

- Name the file after its primary type, such as `ContentView.swift`, `CameraManager.swift`, `GridTrackNetDetector.swift`, and `ServeTossApexDetectorTests.swift`.
- Use `*View.swift` for SwiftUI/UIKit view adapters and `*Manager.swift` for runtime services, as prescribed in `AGENTS.md` and observed in `Tennis Trainer/`.
- Keep detector implementations under `Tennis Trainer/Detectors/`; archived feature code belongs under `Tennis Trainer/Archived/<Topic>/`.

**Functions:**

- Use lower camel case and descriptive verbs: `detectPose`, `processFrame`, `resetTrackingState`, `resizeAspectFill`, and `loadVideo`.
- Test names follow `test<Behavior_WhenCondition>` in the active detector tests, for example `testTwoTossesInsideCooldownFireOnce` in `Tennis TrainerTests/ServeTossApexDetectorTests.swift`.
- Framework callbacks retain their required signatures, such as `captureOutput(_:didOutput:from:)` and `picker(_:didFinishPicking:)`.

**Variables:**

- Use lower camel case for stored properties and locals: `poseDetectionManager`, `ballDetectionManager`, `currentMode`, and `frameMappings`.
- Boolean properties use an `is` or `has` prefix (`isRecording`, `isLoading`, `hasPermission`, `isReady`).
- Constants are declared with `let` and use the same lower camel case style (`cooldownSeconds`, `targetFrameIndex`).

**Types:**

- Use UpperCamelCase for classes, structs, enums, and protocols: `CameraManager`, `ContentView`, `BallDetectionMethod`, and `ServeTossApexHeightGateProviding`.
- SwiftUI views are structs conforming to `View`; services and observable runtime objects are classes.
- Mark non-subclassed implementation classes `final`, as in `GridTrackNetDetector`, `ColorKalmanBallDetector`, and `ServeTossApexDetector`. Existing `ObservableObject` managers are not consistently marked `final`.

## Code Style

**Formatting:**

- The repository guidance prescribes Swift with 2-space indentation and reasonably short, readable lines.
- No `.swiftformat`, `.swiftlint.yml`, `Package.swift`, or formatter configuration was detected. Formatting is therefore currently editor/contributor enforced.
- Source uses blank lines to separate stored properties, methods, extensions, and logical blocks. Several files contain trailing whitespace or extra blank lines, so treat the guidance as the target convention rather than a fully enforced invariant.

**Linting:**

- No lint configuration or lint command was detected in the repository.
- Keep production logging to error conditions, matching the GridTrackNet notes in `AGENTS.md`; current code uses `print` for camera, audio, pose, picker, and model errors in `Tennis Trainer/CameraManager.swift`, `Tennis Trainer/AudioManager.swift`, `Tennis Trainer/PoseDetectionManager.swift`, `Tennis Trainer/VideoPickerView.swift`, and `Tennis Trainer/Detectors/GridTrackNetDetector.swift`.

## Import Organization

**Order:**

1. Apple framework imports required by the file, typically starting with `Foundation` or the primary framework (`SwiftUI`, `AVFoundation`, or `XCTest`).
2. Related Apple frameworks, for example `CoreVideo`, `CoreGraphics`, `QuartzCore`, `ImageIO`, and `Vision`.
3. `@testable import Tennis_Trainer` in unit tests after test/framework imports.

Imports are generally grouped at the top with no third-party package imports. The exact ordering is not uniform: `Tennis Trainer/PoseDetectionManager.swift` places `Vision` before `AVFoundation`, while `Tennis Trainer/CameraManager.swift` starts with `AVFoundation`, `SwiftUI`, and `Vision`.

**Path Aliases:**

- No custom module or path aliases are used. Tests import the app module as `@testable import Tennis_Trainer`.

## Error Handling

**Patterns:**

- Prefer `guard` for required resources and early exits, as in `Tennis Trainer/CameraManager.swift`, `Tennis Trainer/PixelBufferScaler.swift`, and `Tennis Trainer/Detectors/GridTrackNetDetector.swift`.
- Use `do`/`catch` around AVFoundation, Vision, Core ML, and file operations; current failures generally log an error and return or leave state unchanged.
- Optional results are represented with `nil` and checked using `guard let` or `if let`, especially for camera buffers, player layers, model outputs, and Vision joints.
- Use `reset()` or `resetTrackingState()` methods to clear stateful detector/playback pipelines (`Tennis Trainer/Detectors/ServeTossApexDetector.swift`, `Tennis Trainer/BallDetectionManager.swift`, and `Tennis Trainer/VideoPlayerManager.swift`).
- Avoid force unwraps in new code. Existing examples include `previewLayer!` in `Tennis Trainer/CameraManager.swift` and `videoOutput!` in `Tennis Trainer/VideoPlayerManager.swift`; these are consistency and crash-risk exceptions to the preferred guarded style.

## Logging

**Framework:** `print` is the only logging mechanism detected.

**Patterns:**

- Log operational failures with a component prefix where useful, for example `GridTrackNetDetector: prediction error` in `Tennis Trainer/Detectors/GridTrackNetDetector.swift`.
- Do not add noisy per-frame or per-joint logs. Commented diagnostic prints in `Tennis Trainer/PoseDetectionManager.swift` show that detailed tracing is kept disabled.
- Preserve the project rule to retain error logs only in production paths.

## Comments

**When to Comment:**

- Use comments to explain non-obvious model, orientation, queueing, or coordinate-system decisions, such as the temporal frame window in `Tennis Trainer/Detectors/GridTrackNetDetector.swift` and the separate camera queues in `Tennis Trainer/CameraManager.swift`.
- Use `// MARK:` to divide major implementation sections, as in `Tennis Trainer/Detectors/GridTrackNetDetector.swift`.
- Comments may identify parked or future work, such as the retained angle helpers in `Tennis Trainer/PoseDetectionManager.swift`; keep those comments tied to a concrete file or behavior.

**JSDoc/TSDoc:**

- Swift documentation comments are used selectively for public-ish utility behavior, for example `resizeAspectFill`, `resizeAspectFit`, and `copyApplyingOrientation` in `Tennis Trainer/PixelBufferScaler.swift`.
- Document coordinate systems, units, frame ordering, and fallback behavior when changing detection code.

## Function Design

**Size:** Keep view composition and manager orchestration readable by splitting large flows into private computed views, helpers, or extensions. `Tennis Trainer/ContentView.swift` is an observed exception at 413 lines and contains several sizeable computed view sections.

**Parameters:** Prefer labeled parameters that state units or purpose (`timestamp:`, `orientation:`, `heightGateProvider:`). Use default arguments for stable frame-processing defaults, as in `PoseDetectionManager.detectPose` and `GridTrackNetDetector.pushFrame`.

**Return Values:** Use optionals for unavailable resources or failed processing (`CVPixelBuffer?`, `CGPoint?`, `AVPlayerLayer?`). Use `Bool` for event-style detector results (`ServeTossApexDetector.consume`) and `Void` callbacks for notifications.

## Module Design

**Exports:**

- Keep implementation types and helpers internal by default; explicitly mark implementation details `private` or `fileprivate` where practical.
- Managers expose only the observable state and callback seams needed by `ContentView` and sibling managers. The current code still exposes several mutable manager references and callbacks, so preserve minimal public surface when adding APIs.

**Barrel Files:**

- No barrel files or package-level re-export modules are used. Add new files directly under the owning feature directory; the synchronized Xcode root group picks them up automatically.

---

*Convention analysis: 2026-09-19*
