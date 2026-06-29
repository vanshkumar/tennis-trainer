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
