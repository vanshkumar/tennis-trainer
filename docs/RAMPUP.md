# Ramp-Up

Use this file when starting a fresh session in the repo. The goal is to answer four questions quickly:

1. What is this app?
2. What code paths matter right now?
3. What docs are source of truth?
4. What known frictions should I avoid rediscovering?

## Read Order

1. `../AGENTS.md`
   Repository rules, coding conventions, and task constraints.
2. `README.md`
   This docs map and the overall knowledge layout.
3. `../ARCHITECTURE.md`
   Current runtime flow and code boundaries.
4. `../README.md`
   Short product framing.
5. `../PRD.MD`
   Behavior/spec details and current serve-focused scope.
6. `plans/active/README.md`
   Active work pointer. Confirm whether a root `*_IMPL.md` brief actually exists before assuming one is checked in.
7. `references/README.md`
   Technical references. Read `../GRIDTRACKNET_COREML.md` before changing GridTrackNet conversion or decoding behavior.
8. `../.codex/LEARNINGS.md`
   Prior friction points, fixes, and signposts.

## Current Repo Reality

- Product focus is the serve.
- The live cue in the codebase is the serve toss-apex beep.
- `ServeTossApexDetector` is the first cue-specific detector wired onto `BallDetectionManager.onBallTrack`.
- The old forehand cue is archived, not deleted.
- GridTrackNet is the default ball detector backend; the color+Kalman path is fallback-only.

## Code Paths That Matter First

- `../Tennis Trainer/ContentView.swift`
  Wiring and high-level UI state.
- `../Tennis Trainer/CameraManager.swift`
  Live capture entry point.
- `../Tennis Trainer/VideoPlayerManager.swift`
  Offline analysis entry point.
- `../Tennis Trainer/BallDetectionManager.swift`
  Ball detection orchestration and cue seam.
- `../Tennis Trainer/Detectors/GridTrackNetDetector.swift`
  Model wrapper and sample emission.
- `../Tennis Trainer/Detectors/ServeTossApexDetector.swift`
  Current cue logic.

## Known Frictions

- Root-level active briefs are easy to reference implicitly but may not actually be checked in. Confirm the file exists before treating it as current source of truth.
- Under `PBXFileSystemSynchronizedRootGroup`, docs added under `Tennis Trainer/` can become bundle resources. Archive docs inside the app tree need unique filenames.
- `xcodebuild` failures in this repo are not always code failures. Check Xcode first-launch state, simulator availability, and first-boot status before debugging app logic.
- `Tennis TrainerTests` currently carries the meaningful automated coverage; UI tests are still mostly scaffolding.
- Pre-existing `.DS_Store` changes may appear in the worktree and are not task-related.

## Minimal Session Checklist

- Confirm the active work pointer in `plans/active/README.md` matches reality.
- Read `.codex/LEARNINGS.md` before repeating local environment investigation.
- If changing durable behavior or workflow assumptions, update docs rather than leaving them only in chat context.
