---
last_mapped_commit: 23b280cf14465d0418d5447422e949b1591f9024
last_mapped_at: 2026-09-19
---
# Technology Stack

**Analysis Date:** 2026-09-19

## Languages

**Primary:**

- Swift, with `SWIFT_VERSION = 5.0` language mode configured in `Tennis Trainer.xcodeproj/project.pbxproj` - iOS application, managers, views, and inference in `Tennis Trainer/`. This setting does not identify the installed compiler version.

**Secondary:**

- Python 3.11 recommended - GridTrackNet conversion tooling in `convert_gridtracknet.py`.
- Objective-C/C/C++ via Apple SDK modules - transitive platform implementation only; no project-owned source detected.

## Runtime

**Environment:**

- iOS 18.5 deployment target on iPhone; the app target is iPhone-only and portrait-only in `Tennis Trainer.xcodeproj/project.pbxproj`.

**Package Manager:**

- Xcode project build system (`Tennis Trainer.xcodeproj/project.pbxproj`); no Swift Package Manager, CocoaPods, or Carthage dependencies detected.
- Lockfile: missing/not applicable.

## Frameworks

**Core:**

- SwiftUI - application lifecycle and UI in `Tennis Trainer/Tennis_TrainerApp.swift` and `Tennis Trainer/ContentView.swift`.
- AVFoundation - live capture, video playback, audio session, and generated beep in `Tennis Trainer/CameraManager.swift`, `Tennis Trainer/VideoPlayerManager.swift`, and `Tennis Trainer/AudioManager.swift`.
- Vision - human body pose requests in `Tennis Trainer/PoseDetectionManager.swift`.
- Core ML - direct multi-frame GridTrackNet inference in `Tennis Trainer/Detectors/GridTrackNetDetector.swift`.
- PhotosUI - local video selection in `Tennis Trainer/VideoPickerView.swift`.
- Core Image/Core Video/Image I/O/QuartzCore - pixel-buffer conversion, resizing, timing, and coordinate processing in `Tennis Trainer/PixelBufferScaler.swift` and detector/manager files.

**Testing:**

- XCTest - unit and UI tests in `Tennis TrainerTests/` and `Tennis TrainerUITests/`.
- Swift Testing - the scaffold test in `Tennis TrainerTests/Tennis_TrainerTests.swift` imports `Testing`.

**Build/Dev:**

- Xcode 16.4 project format (`objectVersion = 77`, `CreatedOnToolsVersion = 16.4`) in `Tennis Trainer.xcodeproj/project.pbxproj`.
- Python conversion environment - pinned TensorFlow/Keras, NumPy, protobuf, coremltools, and h5py in `requirements-convert.txt`.

## Key Dependencies

**Critical:**

- Apple Core ML runtime - loads the bundled `Tennis Trainer/Models/GridTrackNet5.mlpackage` and runs the five-frame ball detector.
- Apple Vision - runs `VNDetectHumanBodyPoseRequest` for pose joints.
- Apple AVFoundation - provides camera frames, `AVPlayerItemVideoOutput`, and `AVAudioEngine` feedback.

**Infrastructure:**

- TensorFlow 2.13.1 and Keras 2.13.1 - source model conversion dependency in `requirements-convert.txt`.
- coremltools 7.2 - converts GridTrackNet to the bundled Core ML package via `convert_gridtracknet.py`.
- h5py, NumPy 1.24.3, protobuf 3.20.3, and typing-extensions 4.5.0 - pinned compatibility dependencies for conversion.

## Configuration

**Environment:**

- Runtime behavior is compile-time/static configuration in `Tennis Trainer/Config.swift`; `AppConfig.ballDetectionMethod` selects GridTrackNet by default or the color/Kalman fallback.
- The app uses generated Info.plist settings in `Tennis Trainer.xcodeproj/project.pbxproj`, including camera and microphone usage descriptions.
- No environment files or runtime API keys are required. `.env*` files are not used; any such files, if present, must remain unread and uncommitted.

**Build:**

- `Tennis Trainer.xcodeproj/project.pbxproj` contains app, unit-test, and UI-test targets, Swift 5.0 settings, iOS 18.5 deployment settings, asset catalog configuration, and generated Info.plist keys.
- `Tennis Trainer/Assets.xcassets/` contains the app icon and accent color resources.
- `Tennis Trainer/Models/GridTrackNet5.mlpackage/` is a checked-in Core ML model package; generated model Swift symbols are consumed by `GridTrackNetDetector`.

## Platform Requirements

**Development:**

- macOS with Xcode 16.4-compatible tooling and an iOS 18.5 simulator/device target; a Python 3.11 environment is recommended only for model conversion.
- A camera-capable iPhone is required for live capture; offline videos are selected through the system Photos picker in `Tennis Trainer/VideoPickerView.swift`.

**Production:**

- iPhone app distributed through Xcode/App Store tooling; processing is on-device and the product does not require a server or network connection for training feedback (`README.md`, `PRIVACY.md`).

---

*Stack analysis: 2026-09-19*
