# SERVE_PIVOT_IMPL — engineering handoff

## Purpose

You're picking this up cold. Here's the situation:

The repo has been **pivoted from a forehand cue to a serve cue**. The active feedback signal is moving from "beep when the right forearm crosses horizontal" (a forehand contact heuristic) to **"beep at the apex of the player's toss on a serve."**

The **documentation has already been rewritten** to describe the serve pivot — `README.md`, `PRD.MD`, and `AGENTS.md` reflect the new product framing, and `PRD.MD` contains the full toss-apex spec. **The Swift code has not been touched yet.** The forearm-horizontal beep is still wired and active.

Your job, in this file, is to:
1. **Park** the forehand-specific code so it's preserved for future revival but doesn't clutter the live serve path.
2. **Implement** `ServeTossApexDetector` and rewire the beep so it fires at toss apex instead of forearm-horizontal crossing.
3. **Add** unit tests for the apex detector.
4. **Clean up** this file when done.

When this file is gone from the repo, the pivot is complete.

---

## Read these for context (in order)

- `PRD.MD` — current spec. The "Serve Toss Apex Detector" section is the contract you're implementing.
- `README.md` — user-facing pitch (don't edit).
- `AGENTS.md` — coding conventions, project structure, build commands.
- `GRIDTRACKNET_COREML.md` — model I/O reference for the ball detector. Read if you touch GridTrackNet decoding.

Then key Swift files:
- `Tennis Trainer/BallDetectionManager.swift` — owns the GridTrackNet pipeline; already exposes a `onBallTrack` callback that emits all 5 timestamped samples per inference. **This is your data source.**
- `Tennis Trainer/Detectors/GridTrackNetDetector.swift` — the model wrapper. Look at the `Sample` struct (`tIndex`, `timestamp`, `position`, `confidence`) and `detectAllSamplesIfReady()`.
- `Tennis Trainer/PoseDetectionManager.swift` — pose joint collection. You'll need to add `nose` and `neck` here.
- `Tennis Trainer/CameraManager.swift` and `Tennis Trainer/VideoPlayerManager.swift` — the two managers that drive frames through the pipeline. Both currently host a `ForearmHorizontalDetector` and a `(Bool) -> Void` `onFrameProcessed` callback that signals the beep.
- `Tennis Trainer/ContentView.swift` — wires the managers; sets `onFrameProcessed` to call `audioManager.playBeep()` and renders the HUD.
- `Tennis Trainer/ForearmHorizontalDetector.swift` — the file you're parking.
- `Tennis Trainer/AudioManager.swift` — `playBeep()` is the trigger you'll route the apex detector into.

---

## Existing seams to reuse (do not reinvent)

- `GridTrackNetDetector.detectAllSamplesIfReady()` returns `[Sample]?` covering the 5 frames in the current window. Each `Sample` has `tIndex`, `timestamp`, `position` (Vision-normalized, origin bottom-left, `nil` if below the 0.5 confidence threshold), and `confidence`.
- `BallDetectionManager.onBallTrack: (([GridTrackNetDetector.Sample]) -> Void)?` is already plumbed and called on the main thread from the inference queue. **No consumer is attached today.** Set it from inside `BallDetectionManager` itself (or from `setupBallDetection`) to feed the apex detector.
- `BallDetectionManager` already holds a weak ref to `PoseDetectionManager`. Use that for the height gate.
- `AudioManager.playBeep()` is the existing audio trigger; nothing audio-side needs to change.
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup`. **Any file or folder you create under `Tennis Trainer/` is automatically included in the build target** — no `.pbxproj` edits needed.
- Threading: `BallDetectionManager.process(...)` already offloads inference onto a dedicated `ml.ball.gridtracknet` queue with a single-flight gate, and it dispatches `onBallTrack` to main. Run the apex detector synchronously inside the `onBallTrack` consumer; it's already on main and is cheap.

---

## Step A — Park the forehand-cue code

Goal: future agents working on serves don't trip over forehand code, and a future agent reviving forehand work has a clear breadcrumb.

### A.1 Move

```bash
mkdir -p "Tennis Trainer/Archived/Forehand"
git mv "Tennis Trainer/ForearmHorizontalDetector.swift" "Tennis Trainer/Archived/Forehand/ForearmHorizontalDetector.swift"
```

The file still compiles into the target (per `PBXFileSystemSynchronizedRootGroup`) but is no longer referenced by live code after the edits below. That's intentional — it keeps the symbol available if you accidentally leave a reference and gives the future revival path a working starting point.

### A.2 Add `Tennis Trainer/Archived/README.md`

Contents (use this as a template, fill in the actual revival commit hash by running `git log -1 --format=%H` before the parking edits and pasting it):

```markdown
# Archived

This folder holds code that's been parked rather than deleted. Files here compile into the build target but should not be wired into live code paths.

## Forehand/

The original "beep when the right forearm crosses horizontal" cue, parked when the project pivoted to serves.

- `ForearmHorizontalDetector.swift` — state-machine detector. Zones: below (270–355°), above (5–90°), dead-zone (355–5°). Beeps on below→above crossing with 0.5s cooldown.

### Revival recipe

1. The angle math is still live in `Tennis Trainer/PoseDetectionManager.swift` (`forearmAngle`, `upperArmAngle`, `calculateAngles()`). It's unused but maintained.
2. Original wiring (pre-pivot): `CameraManager` and `VideoPlayerManager` each held a `ForearmHorizontalDetector` instance, called `checkForearmHorizontal(forearmAngle:)` per frame, and signaled the beep via `onFrameProcessed: ((Bool) -> Void)?`.
3. To revive: instantiate `ForearmHorizontalDetector` in whichever manager owns the relevant frame stream, feed it `poseDetectionManager.forearmAngle` per frame, and route the boolean into `AudioManager.playBeep()`.
4. The pre-pivot reference commit is `<INSERT_COMMIT_HASH>` — `git show <hash>:"Tennis Trainer/CameraManager.swift"` shows the original call sites (around the `processFrame` and `checkForearmHorizontal` methods).

### Known limitations of the parked code
- Right-handed only (uses right shoulder/elbow/wrist).
- Triggers on every below→above crossing — does not actually detect ball–racket contact, just an arm motion. False positives during warm-up swings are expected.
```

### A.3 Edit `Tennis Trainer/PoseDetectionManager.swift`

- **Add `nose` and `neck`** to the `jointNames` array in `processPoseObservation` so they get collected (with the same confidence > 0.3 filter). The toss-apex detector needs them for the height gate.
- **Keep** `forearmAngle`, `upperArmAngle`, and `calculateAngles()` as-is. They are unused after this pivot but remain harmless and useful for future stroke-analysis work. Add a one-line doc comment above `calculateAngles()`:

  ```swift
  // Currently unused. Kept for future stroke-analysis work (see Tennis Trainer/Archived/Forehand/).
  ```

### A.4 Edit `Tennis Trainer/CameraManager.swift`

- Remove the `private let horizontalDetector = ForearmHorizontalDetector()` line.
- Remove the `checkForearmHorizontal()` method.
- Remove the `let shouldBeep = checkForearmHorizontal()` line in `processFrame` and the `shouldBeep` argument from the `onFrameProcessed` dispatch.
- Change the callback type:
  - From: `var onFrameProcessed: ((Bool) -> Void)?`
  - To: `var onFrameProcessed: (() -> Void)?` (kept for FPS bookkeeping)
- Add: `var onApex: (() -> Void)?` (the new beep trigger; set by `ContentView`).
- In `setupBallDetection(with:)`, after creating the `BallDetectionManager`, set `ballDetectionManager?.onApex = { [weak self] in self?.onApex?() }` (see Step B for the new `onApex` on `BallDetectionManager`).

### A.5 Edit `Tennis Trainer/VideoPlayerManager.swift`

Same pattern as `CameraManager`:
- Remove `horizontalDetector`, `checkForearmHorizontal()`, the call from `processCurrentFrame`, and the `horizontalDetector.reset()` line in `cleanup()`.
- Change `onFrameProcessed: ((Bool) -> Void)?` to `(() -> Void)?` and add `onApex: (() -> Void)?`.
- In `setupBallDetection(with:)`, forward `onApex` from the ball manager just like `CameraManager`.

### A.6 Edit `Tennis Trainer/ContentView.swift`

- In `liveCameraView` (around the existing lines that render `Forearm:` and `Upper Arm:` Text rows in the right-hand HUD VStack), **remove those two Text rows**. Keep the `Joints:` row (it's still useful as a pose-detection sanity indicator).
- In `videoPlaybackView` (the analogous block for the video HUD), **remove the same two Text rows**.
- In `.onAppear`, change the `cameraManager.onFrameProcessed` and `videoPlayerManager.onFrameProcessed` closures so they no longer take a `shouldBeep` argument and no longer call `audioManager.playBeep()` from inside. They should only do the FPS-counter math.
- Add new wiring: `cameraManager.onApex = { audioManager.playBeep() }` and `videoPlayerManager.onApex = { audioManager.playBeep() }`.

### A.7 Verify Step A in isolation

Run a build before moving to Step B:
```
xcodebuild -scheme "Tennis Trainer" -destination 'platform=iOS Simulator,name=iPhone 15' build
```
At this point the app should build cleanly, run, and produce **no beeps at all** (the apex detector hasn't been added yet). The forearm/upper-arm angles in the HUD should be gone. Pose joints and ball overlay should still render. **Don't proceed to Step B until this is true.**

---

## Step B — Implement `ServeTossApexDetector` and wire the beep

### B.1 New file `Tennis Trainer/Detectors/ServeTossApexDetector.swift`

Sketch (adapt to repo style — Swift, 2-space indent, `final class`, prefer `private`, see `AGENTS.md`):

```swift
import Foundation
import CoreGraphics
import QuartzCore
import Vision

/// Detects the apex of a serve toss from the GridTrackNet sample stream.
/// Apex = local-max in vertical position (Vision-normalized, origin bottom-left)
/// that exceeds a height gate and a confidence threshold, with a cooldown
/// between beeps.
final class ServeTossApexDetector {
    // Tunables. See PRD.MD "Serve Toss Apex Detector" for rationale.
    private let cooldownSeconds: CFTimeInterval = 4.0
    private let bufferHorizonSeconds: CFTimeInterval = 1.5
    private let confidenceThreshold: Float = 0.5
    private let poseHeightMargin: CGFloat = 0.05    // ball.y must exceed nose.y + this
    private let frameRelativeFallback: CGFloat = 0.70 // ball.y must exceed this if no pose

    private struct Entry {
        let timestamp: CFTimeInterval
        let y: CGFloat
        let confidence: Float
    }
    private var buffer: [Entry] = []
    private var lastBeep: CFTimeInterval = -.greatestFiniteMagnitude

    /// Feed all 5 samples from one inference. Returns true exactly once per
    /// detected apex (cooldown-respecting). Caller should play the beep on `true`.
    func consume(samples: [GridTrackNetDetector.Sample],
                 poseProvider: PoseDetectionManager?) -> Bool {
        // 1. Append new samples (only those with a position above the conf threshold).
        // 2. Dedup by timestamp (overlapping inference windows can repeat samples).
        // 3. Drop entries older than bufferHorizonSeconds relative to the newest entry.
        // 4. Scan for a local max: an entry e at index i where
        //    buffer[i-1].y < e.y && buffer[i+1].y < e.y, and e is the most recent
        //    candidate not yet beeped. (You only need to check the second-most-recent
        //    entry against its two neighbors each call — a peak is detected one
        //    sample after it occurred.)
        // 5. Apply height gate (pose-relative if PoseDetectionManager has nose/neck
        //    above conf 0.3, else frame-relative).
        // 6. Apply cooldown.
        // 7. On success, update lastBeep, return true. Otherwise false.
    }

    func reset() {
        buffer.removeAll(keepingCapacity: true)
        lastBeep = -.greatestFiniteMagnitude
    }
}
```

**Implementation notes**:

- The 5 samples per inference cover 5 consecutive frames; across two consecutive inferences they may overlap (e.g., samples at `t=2..6` then `t=4..8`). Dedup by timestamp before scanning. The simplest dedup: when appending, skip any incoming sample whose timestamp is `<= buffer.last?.timestamp`. Sort defensively if you ever feed in non-monotonic input, but the inference pipeline produces monotonic timestamps.
- Skip samples where `position` is `nil` (below GridTrackNet's 0.5 conf threshold) — they don't contribute usable y data. You may want to be slightly more lenient here (the threshold is also enforced inside `GridTrackNetDetector`), but err on strict.
- "Local max" detection on a stream: each time you append, look at the entry that is now `buffer[buffer.count - 2]` and check whether `buffer[count-3].y < buffer[count-2].y > buffer[count-1].y`. That's a 1-sample-late detection of an apex — exactly the real-time-with-confirmation behavior the PRD calls for.
- For the pose-relative gate, read `poseProvider?.detectedPose[.nose]?.location.y` (Vision normalized, origin bottom-left, same coordinate space as the ball). If absent, fall back to `.neck`. If both absent, use the frame-relative fallback.
- Make this class **not thread-safe**. The caller (`BallDetectionManager.onBallTrack`) is on main; that's the only call site.

### B.2 Edit `Tennis Trainer/BallDetectionManager.swift`

- Add a private property: `private let apexDetector = ServeTossApexDetector()`.
- Add a public callback: `var onApex: (() -> Void)?`.
- In the `gridTrackNet` branch of `process(pixelBuffer:timestamp:)`, where the existing `onBallTrack` callback is dispatched on main, also call:

  ```swift
  if self.apexDetector.consume(samples: samples, poseProvider: self.poseDetectionManager) {
      self.onApex?()
  }
  ```

  The simplest place is inside the existing `if let cb = self.onBallTrack { DispatchQueue.main.async { cb(samples) } }` block — wrap it so both the `onBallTrack` consumer and the apex detector run on main, in order.
- In the `colorKalman` branch, optionally call `apexDetector.reset()` so a backend swap mid-session doesn't leak state. (`ColorKalman` doesn't produce GridTrackNet samples, so the detector would otherwise just go idle.)

### B.3 Forward `onApex` through `CameraManager` and `VideoPlayerManager`

Already covered in Steps A.4 and A.5: each manager exposes `var onApex: (() -> Void)?` and forwards from the ball manager's callback in `setupBallDetection`.

### B.4 Verify Step B end-to-end

Build and run. With a downloaded pro serve video (or live camera + manual toss), confirm:
- One beep per toss, near the visible apex.
- No beeps during the rest of the serve (windup, swing, contact, follow-through).
- A second toss within ~4 s does not double-fire; a second toss after the cooldown does fire.

---

## Step C — Tests

New file `Tennis TrainerTests/ServeTossApexDetectorTests.swift` (XCTest).

You'll be feeding the detector synthetic `GridTrackNetDetector.Sample` arrays. Helper to construct them:

```swift
private func sample(t: CFTimeInterval, y: CGFloat, conf: Float = 0.9) -> GridTrackNetDetector.Sample {
    GridTrackNetDetector.Sample(
        tIndex: 0, // not used by the detector
        timestamp: t,
        position: CGPoint(x: 0.5, y: y),
        confidence: conf
    )
}
```

(If `GridTrackNetDetector.Sample` initializer access is `internal` it should be reachable from the test target; add `@testable import Tennis_Trainer` if needed.)

### Required test cases

1. **Single parabolic toss above the frame-relative gate fires exactly once.**
   - Generate 30 samples following `y = 0.5 + 0.4 * sin(π * i / 30)` (peaks at `i=15` with `y=0.9`), dt = 0.033 s.
   - Pass to `consume` in groups of 5 (mimicking inference batching) with `poseProvider: nil`.
   - Assert exactly one `true` return, returned at the inference batch covering the peak (not before).

2. **Two tosses spaced > cooldown fire twice; spaced < cooldown fire once.**
   - Two parabolic peaks separated by 5 s → 2 beeps.
   - Same shape separated by 2 s → 1 beep.

3. **Peak below the height gate does not fire.**
   - Parabola peaking at `y = 0.65` (below 0.70 frame-relative fallback) with `poseProvider: nil` → 0 beeps.

4. **Pose-relative gate suppresses an otherwise-valid apex when ball is below the nose.**
   - Build a stub or simple test double for `PoseDetectionManager` exposing a `nose` joint at `y = 0.95`. Parabola peaking at `y = 0.85` → 0 beeps even though the frame-relative fallback would have fired.
   - (If subclassing/stubbing `PoseDetectionManager` is awkward, refactor the detector to take a small `HeightGateProvider` protocol with `nose: CGFloat?` and `neck: CGFloat?` properties — that's cleaner anyway. Update the call site in `BallDetectionManager` to adapt.)

5. **Low-confidence samples around the peak suppress the apex.**
   - Parabola where the three samples nearest the peak have `confidence = 0.3` (below threshold) → 0 beeps.

### Run

```
xcodebuild test -scheme "Tennis Trainer" -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## End-state cleanup

Once all of the above is committed and verified:

1. **Delete this file**: `git rm SERVE_PIVOT_IMPL.md`.
2. **Update `PRD.MD` "Implementation status"** section: remove the paragraph that says the forearm-horizontal detector is still wired and that this file tracks the pivot. Replace with a one-line note that the toss-apex detector is implemented and the forearm code is parked under `Tennis Trainer/Archived/Forehand/`.
3. **Log learnings** in `.claude/LEARNINGS.md` if anything bit you that wasn't obvious from this brief — especially:
   - Anything about the GridTrackNet output shape, threading, or the inference cadence that surprised you.
   - Anything about `PBXFileSystemSynchronizedRootGroup` build-target behavior with new folders/files.
   - Any test-setup quirks (XCTest visibility into `Tennis_Trainer` types, etc.).

That last step matters — future sessions read `LEARNINGS.md` first and benefit from your scars.
