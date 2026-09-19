---
last_mapped_commit: 23b280cf14465d0418d5447422e949b1591f9024
last_mapped_at: 2026-09-19
---
# Codebase Structure

**Analysis Date:** 2026-09-19

## Directory Layout

```text
tennis-trainer/
├── Tennis Trainer/                 # SwiftUI app target
│   ├── Detectors/                  # Ball and serve-toss analysis algorithms
│   ├── Models/                     # Bundled Core ML model package
│   ├── Archived/                   # Parked forehand code and archive notes
│   └── Assets.xcassets/            # App icon and accent color assets
├── Tennis TrainerTests/            # Unit tests
├── Tennis TrainerUITests/          # UI/XCTest launch tests
├── Tennis Trainer.xcodeproj/       # Xcode project and synchronized groups
├── docs/                           # Documentation map, ramp-up, plans, references
├── .planning/codebase/             # Generated GSD mapper documents
├── convert_gridtracknet.py         # Model conversion utility
├── GRIDTRACKNET_COREML.md          # Model/decode reference
├── PRD.MD                          # Product behavior specification
└── ARCHITECTURE.md                 # Short repository architecture guide
```

## Directory Purposes

**`Tennis Trainer/`:**

- Purpose: All production Swift and bundled app resources.
- Contains: SwiftUI views, observable managers, AV/Vision/Core ML services, assets, and model resources.
- Key files: `Tennis Trainer/ContentView.swift`, `Tennis Trainer/CameraManager.swift`, `Tennis Trainer/VideoPlayerManager.swift`, `Tennis Trainer/BallDetectionManager.swift`, `Tennis Trainer/PoseDetectionManager.swift`.

**`Tennis Trainer/Detectors/`:**

- Purpose: Algorithm implementations independent of the top-level view.
- Contains: `GridTrackNetDetector.swift`, `ColorKalmanBallDetector.swift`, and `ServeTossApexDetector.swift`.
- Key files: `Tennis Trainer/Detectors/GridTrackNetDetector.swift` owns temporal Core ML decoding; `Tennis Trainer/Detectors/ServeTossApexDetector.swift` owns cue detection.

**`Tennis Trainer/Models/`:**

- Purpose: Model resources loaded by Core ML.
- Contains: `Tennis Trainer/Models/GridTrackNet5.mlpackage` and its generated model data/weights.
- Key files: `Tennis Trainer/Models/GridTrackNet5.mlpackage/Manifest.json` and packaged model data. Do not hand-edit generated model Swift; regenerate via `convert_gridtracknet.py` when the model changes.

**`Tennis Trainer/Archived/`:**

- Purpose: Parked code that remains in the target but is unwired from live paths.
- Contains: `Tennis Trainer/Archived/ARCHIVED.md` and `Tennis Trainer/Archived/Forehand/` with the forehand detector and archive notes.
- Key files: `Tennis Trainer/Archived/Forehand/FOREHAND_ARCHIVE.md`, `Tennis Trainer/Archived/Forehand/ForearmHorizontalDetector.swift`.

**`Tennis TrainerTests/`:**

- Purpose: Unit test target for detector behavior and app scaffolding.
- Contains: `Tennis TrainerTests/ServeTossApexDetectorTests.swift`, `Tennis TrainerTests/Tennis_TrainerTests.swift`.

**`Tennis TrainerUITests/`:**

- Purpose: XCTest UI and launch coverage.
- Contains: `Tennis TrainerUITests/Tennis_TrainerUITests.swift`, `Tennis TrainerUITests/Tennis_TrainerUITestsLaunchTests.swift`.

**`docs/`:**

- Purpose: Knowledge-base navigation and durable documentation pointers.
- Contains: `docs/README.md`, `docs/RAMPUP.md`, and category indexes under `docs/plans/`, `docs/product/`, and `docs/references/`.

## Key File Locations

**Entry Points:**

- `Tennis Trainer/Tennis_TrainerApp.swift`: SwiftUI `@main` application entry.
- `Tennis Trainer/ContentView.swift`: runtime composition root and visible mode UI.
- `Tennis Trainer/CameraManager.swift`: camera sample-buffer delegate entry.
- `Tennis Trainer/VideoPlayerManager.swift`: display-link frame-analysis entry.

**Configuration:**

- `Tennis Trainer/Config.swift`: active ball detector enum/configuration.
- `Tennis Trainer/AppRuntime.swift`: test-environment detection used to avoid hardware setup.
- `Tennis Trainer.xcodeproj/project.pbxproj`: target settings and filesystem-synchronized root groups.
- `Tennis Trainer/Assets.xcassets/`: icon and color assets.

**Core Logic:**

- `Tennis Trainer/PoseDetectionManager.swift`: Vision pose state and toss baseline.
- `Tennis Trainer/BallDetectionManager.swift`: detector selection, inference gate, published ball state, and event seam.
- `Tennis Trainer/Detectors/GridTrackNetDetector.swift`: five-frame model inference and coordinate mapping.
- `Tennis Trainer/Detectors/ServeTossApexDetector.swift`: apex state machine.
- `Tennis Trainer/PixelBufferScaler.swift`: orientation and model-canvas conversions.

**Presentation and platform adapters:**

- `Tennis Trainer/CameraPreview.swift`: hosts `AVCaptureVideoPreviewLayer` in SwiftUI.
- `Tennis Trainer/VideoPlayerView.swift`: hosts `AVPlayerLayer` in SwiftUI.
- `Tennis Trainer/VideoPickerView.swift`: bridges `PHPickerViewController` and temporary video files.
- `Tennis Trainer/AudioManager.swift`: generated beep output.

**Testing:**

- `Tennis TrainerTests/`: unit tests, especially `Tennis TrainerTests/ServeTossApexDetectorTests.swift`.
- `Tennis TrainerUITests/`: UI and launch tests.

## Naming Conventions

**Files:**

- Match the primary Swift type: `ContentView.swift`, `CameraManager.swift`, `GridTrackNetDetector.swift`.
- Use `*View.swift` for SwiftUI/UIKit presentation adapters and `*Manager.swift` for runtime services.
- Detector algorithms live in `Tennis Trainer/Detectors/` and use `*Detector.swift`.

**Directories:**

- Use title-cased target directories with spaces for the app and test targets (`Tennis Trainer/`, `Tennis TrainerTests/`, `Tennis TrainerUITests/`).
- Use focused lower-level category directories such as `Detectors/`, `Models/`, and `Archived/`.
- Keep parked topic code under `Tennis Trainer/Archived/<Topic>/` with a topic README/archive note.

## Where to Add New Code

**New Feature:**

- Primary orchestration/service: add a focused `*Manager.swift` under `Tennis Trainer/`, then wire it in `Tennis Trainer/ContentView.swift`.
- UI: add a `*View.swift` under `Tennis Trainer/` and keep rendering/state binding in the view.
- Tests: put unit behavior in `Tennis TrainerTests/`; put user-flow coverage in `Tennis TrainerUITests/`.

**New Component/Module:**

- Detection/inference/signal processing: `Tennis Trainer/Detectors/`.
- Core ML resources: `Tennis Trainer/Models/`; update the source/conversion path in `convert_gridtracknet.py` and reference documentation in `GRIDTRACKNET_COREML.md`.
- AV/vision runtime service: `Tennis Trainer/<Feature>Manager.swift`.
- SwiftUI/UIKit bridge: `Tennis Trainer/<Feature>View.swift`.

**Utilities:**

- Shared frame conversion belongs in `Tennis Trainer/PixelBufferScaler.swift` or a narrowly named utility beside it; keep coordinate conversion centralized rather than duplicating it in views.

The project uses `PBXFileSystemSynchronizedRootGroup` for the app and test roots (`Tennis Trainer.xcodeproj/project.pbxproj:32-48`). New files placed under those directories are picked up by the corresponding target without manual `.pbxproj` file-reference edits.

## Special Directories

**`Tennis Trainer/Models/GridTrackNet5.mlpackage/`:**

- Purpose: Bundled Core ML model package used by `GridTrackNetDetector`.
- Generated: Yes, from the conversion workflow.
- Committed: Yes, as app resources.

**`Tennis Trainer/Archived/`:**

- Purpose: Parked/archived algorithms and revival guidance.
- Generated: No.
- Committed: Yes; keep archived code unwired from live paths.

**`Tennis Trainer/Assets.xcassets/`:**

- Purpose: Compiled app image/color resources.
- Generated: No; managed asset catalog.
- Committed: Yes.

**`.planning/codebase/`:**

- Purpose: GSD-generated current-state maps consumed by planning/execution agents.
- Generated: Yes, by mapping workflows.
- Committed: Repository workflow decides whether to retain generated maps; do not place production source here.

**`docs/`:**

- Purpose: Durable repository knowledge and navigation.
- Generated: No.
- Committed: Yes.

---

*Structure analysis: 2026-09-19*
