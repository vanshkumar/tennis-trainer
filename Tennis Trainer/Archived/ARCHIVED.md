# Archived

This folder holds code that's been parked rather than deleted. Files here compile into the build target but should not be wired into live code paths.

## Forehand/

The original "beep when the right forearm crosses horizontal" cue, parked when the project pivoted to serves.

- `ForearmHorizontalDetector.swift` — state-machine detector. Zones: below (270–355°), above (5–90°), dead-zone (355–5°). Beeps on below→above crossing with 0.5s cooldown.

### Revival recipe

1. The angle math is still live in `Tennis Trainer/PoseDetectionManager.swift` (`forearmAngle`, `upperArmAngle`, `calculateAngles()`). It's unused but maintained.
2. Original wiring (pre-pivot): `CameraManager` and `VideoPlayerManager` each held a `ForearmHorizontalDetector` instance, called `checkForearmHorizontal(forearmAngle:)` per frame, and signaled the beep via `onFrameProcessed: ((Bool) -> Void)?`.
3. To revive: instantiate `ForearmHorizontalDetector` in whichever manager owns the relevant frame stream, feed it `poseDetectionManager.forearmAngle` per frame, and route the boolean into `AudioManager.playBeep()`.
4. The pre-pivot reference commit is `31f5a76bb1f7bad38a378f2559ac405748a1d4d5` — `git show <hash>:"Tennis Trainer/CameraManager.swift"` shows the original call sites (around the `processFrame` and `checkForearmHorizontal` methods).

### Known limitations of the parked code

- Right-handed only (uses right shoulder/elbow/wrist).
- Triggers on every below→above crossing — does not actually detect ball-racket contact, just an arm motion. False positives during warm-up swings are expected.
