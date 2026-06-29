# Learnings

## What Has Worked

## Patterns and Preferences

## What Has Failed

## Task Notes

**2026-06-29 — Live camera stop responsiveness**
- Observation: `CameraManager` previously used the same serial queue for `AVCaptureVideoDataOutput` frame callbacks and `AVCaptureSession` start/stop calls, so stop requests could wait behind expensive Vision/Core ML frame processing.
- Action: Keep capture-session lifecycle work on a dedicated session queue, send frame analysis to a separate video-processing queue, and gate frame callbacks immediately when stop is requested.
- Confidence: high

**2026-06-29 — Xcode Cloud release trigger**
- Observation: The local release branch is `main` tracking `origin/main`; pushing a fix commit there is the available repo-level trigger for the already configured Xcode Cloud/TestFlight flow.
- Action: When asked to update TestFlight from this repo, commit only the intended files and push `main` without staging unrelated local worktree changes.
- Confidence: medium
