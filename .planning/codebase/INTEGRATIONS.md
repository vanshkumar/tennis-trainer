---
last_mapped_commit: 23b280cf14465d0418d5447422e949b1591f9024
last_mapped_at: 2026-09-19
---
# External Integrations

**Analysis Date:** 2026-09-19

## APIs & External Services

**Apple device media APIs:**

- AVFoundation - live back-camera capture, preview, offline AVPlayer playback, video frame extraction, and audio feedback in `Tennis Trainer/CameraManager.swift`, `Tennis Trainer/VideoPlayerManager.swift`, and `Tennis Trainer/AudioManager.swift`.
  - SDK/Client: Apple AVFoundation framework.
  - Auth: device camera and microphone permissions declared in `Tennis Trainer.xcodeproj/project.pbxproj`.
- Vision - on-device human pose detection in `Tennis Trainer/PoseDetectionManager.swift`.
  - SDK/Client: Apple Vision framework, `VNDetectHumanBodyPoseRequest` revision 1.
  - Auth: none; it operates on local pixel buffers.
- PhotosUI - user-selected local video import in `Tennis Trainer/VideoPickerView.swift`.
  - SDK/Client: Apple PhotosUI framework and `PhotosPicker`.
  - Auth: user selection through the system picker; no service credential.

**On-device machine learning:**

- GridTrackNet - five-frame tennis-ball detector in `Tennis Trainer/Detectors/GridTrackNetDetector.swift`.
  - SDK/Client: Apple Core ML framework and generated `GridTrackNet5` model type.
  - Auth: none; model is bundled at `Tennis Trainer/Models/GridTrackNet5.mlpackage/`.
- GridTrackNet conversion toolchain - offline conversion from Keras/TensorFlow weights in `convert_gridtracknet.py`.
  - SDK/Client: Python packages pinned in `requirements-convert.txt`.
  - Auth: none detected; source model/weights are external inputs documented in `GRIDTRACKNET_COREML.md` and are not bundled in this repository.

## Data Storage

**Databases:**

- None detected. The app has no Core Data, CloudKit, SQLite, or remote database client imports.

**File Storage:**

- Local device temporary directory - selected videos are copied to `FileManager.default.temporaryDirectory` by `Tennis Trainer/VideoPickerView.swift` before playback.
- App bundle resources - the Core ML model and asset catalog are packaged locally under `Tennis Trainer/Models/` and `Tennis Trainer/Assets.xcassets/`.
- User Photos library - source videos are selected through PhotosUI; no repository code uploads or synchronizes them.

**Caching:**

- In-memory only - temporal frame buffers and detector state live in `Tennis Trainer/Detectors/GridTrackNetDetector.swift` and `Tennis Trainer/Detectors/ServeTossApexDetector.swift`.
- No persistent cache service or third-party caching library detected.

## Authentication & Identity

**Auth Provider:**

- None detected. `Tennis Trainer/` contains no account, login, OAuth, token, or identity-provider implementation.

## Monitoring & Observability

**Error Tracking:**

- None detected. There is no Sentry, Crashlytics, analytics SDK, or remote telemetry client.

**Logs:**

- Local diagnostic `print` calls are used for model loading, frame conversion, and prediction failures in `Tennis Trainer/Detectors/GridTrackNetDetector.swift`; no centralized logging backend is configured.

## CI/CD & Deployment

**Hosting:**

- iOS app distribution through Xcode/App Store tooling. The repository includes an Xcode Cloud manifest at `Tennis Trainer.xcodeproj/xcshareddata/xcodecloud/manifest.json`, but workflow trigger and TestFlight distribution settings are not represented in the repository.

**CI Pipeline:**

- No repository `ci_scripts/` directory or external CI configuration was detected. Build and test targets are defined in `Tennis Trainer.xcodeproj/project.pbxproj`.

## Environment Configuration

**Required env vars:**

- None detected for the app runtime.
- Conversion tooling uses Python package versions from `requirements-convert.txt`, not secret environment variables.

**Secrets location:**

- No application secrets or credential files are part of the integration path. Signing configuration is managed by Xcode project settings and Apple tooling; signing identifiers are intentionally omitted from this document.

## Webhooks & Callbacks

**Incoming:**

- None. No HTTP server, webhook route, URL session client, or push notification handler was detected.

**Outgoing:**

- None. `README.md` and `PRIVACY.md` describe local, on-device processing without uploads of camera frames, selected videos, or analysis results.

---

*Integration audit: 2026-09-19*
