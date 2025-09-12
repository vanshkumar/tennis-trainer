# Repository Guidelines

## Project Structure & Module Organization
- `Tennis Trainer/` — SwiftUI app code (views and managers). Examples: `ContentView.swift`, `CameraManager.swift`, `BallDetectionManager.swift`, assets in `Assets.xcassets`.
- `Tennis TrainerTests/` — unit tests (XCTest).
- `Tennis TrainerUITests/` — UI tests (XCTest).
- `Tennis Trainer.xcodeproj/` — Xcode project, schemes, and build settings.
- Root: `README.md`, `LICENSE`, `CLAUDE.md`.

## Build, Test, and Development Commands
- Open project: `open "Tennis Trainer.xcodeproj"` (or `xed .`).
- Build (CLI): `xcodebuild -scheme "Tennis Trainer" -destination 'platform=iOS Simulator,name=iPhone 15' build`.
- Run tests: `xcodebuild test -scheme "Tennis Trainer" -destination 'platform=iOS Simulator,name=iPhone 15'`.
- Run locally: select an iOS Simulator in Xcode and press Run. Prefer iPhone 15 or newer for consistent results.

## Coding Style & Naming Conventions
- Swift, 2‑space indentation; keep lines reasonably short and readable.
- Follow Swift API Design Guidelines: Types `UpperCamelCase`; methods/properties `lowerCamelCase`.
- Views end with `View` (e.g., `VideoPlayerView`); service/logic types end with `Manager` (e.g., `PoseDetectionManager`).
- Prefer `struct` for views; mark classes `final` when not subclassed; default to `private`/`fileprivate`.
- One primary type per file; filename matches type name.

## Testing Guidelines
- Framework: XCTest.
- Unit tests live in `Tennis TrainerTests/`; UI tests in `Tennis TrainerUITests/`.
- Name tests `test<Behavior_WhenCondition>` and focus on observable behavior.
- Run all tests via the CLI command above or Xcode’s Test action. Add/adjust tests when changing detection/processing logic.

## Commit & Pull Request Guidelines
- Commit subject in imperative mood (≤72 chars), e.g., `Fix crash in CameraManager init`.
- Add a brief body explaining why, not just what.
- PRs: link issues, describe approach, include screenshots/screen recordings for UI changes, and note test coverage/manual QA.
- Ensure tests pass; avoid unrelated formatting churn.

## Security & Configuration Tips
- Confirm Info.plist contains `NSCameraUsageDescription` and `NSMicrophoneUsageDescription`; update messages if behavior changes.
- Never commit signing certs/profiles or personal identifiers. Keep build artifacts out of Git (see `.gitignore`).

## Agent‑Specific Notes
- Do not rename the `Tennis Trainer` target/folder or change the bundle identifier.
- Add features as `*Manager` (logic) and `*View` (UI); integrate via `ContentView` as needed.
- Keep public surface area minimal; document decisions in the PR description.

