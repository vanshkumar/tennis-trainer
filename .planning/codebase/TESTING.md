---
last_mapped_commit: 23b280cf14465d0418d5447422e949b1591f9024
last_mapped_at: 2026-09-19
---
# Testing Patterns

**Analysis Date:** 2026-09-19

## Test Framework

**Runner:**

- The project uses Xcode test targets configured in `Tennis Trainer.xcodeproj/project.pbxproj`.
- The shared `Tennis Trainer` scheme runs the `Tennis TrainerTests` target, as configured in `Tennis Trainer.xcodeproj/xcshareddata/xcschemes/Tennis Trainer.xcscheme`.
- The shared `Tennis Trainer UI Tests` scheme runs the `Tennis TrainerUITests` target, as configured in `Tennis Trainer.xcodeproj/xcshareddata/xcschemes/Tennis Trainer UI Tests.xcscheme`.
- The unit target contains both XCTest and Swift Testing source: `Tennis TrainerTests/ServeTossApexDetectorTests.swift` imports XCTest, while `Tennis TrainerTests/Tennis_TrainerTests.swift` imports Testing.

**Assertion Library:**

- XCTest assertions (`XCTAssertEqual`, `XCTAssertTrue`) are used in `Tennis TrainerTests/ServeTossApexDetectorTests.swift`.
- Swift Testing uses the scaffolded `@Test` entry point in `Tennis TrainerTests/Tennis_TrainerTests.swift`, but that test currently contains no assertion.
- UI tests use XCTest APIs from `Tennis TrainerUITests/Tennis_TrainerUITests.swift` and `Tennis TrainerUITests/Tennis_TrainerUITestsLaunchTests.swift`.

**Run Commands:**

```bash
xcodebuild test -scheme "Tennis Trainer" -destination 'platform=iOS Simulator,name=iPhone 15'              # Unit tests via shared app scheme
xcodebuild test -scheme "Tennis Trainer UI Tests" -destination 'platform=iOS Simulator,name=iPhone 15'    # UI tests via UI scheme
```

The repository guidance also provides this build command, which is a build check rather than a test command:

```bash
xcodebuild -scheme "Tennis Trainer" -destination 'platform=iOS Simulator,name=iPhone 15' build
```

No build or test commands were run during this mapping pass. No watch-mode or coverage command is configured in the repository.

## Test File Organization

**Location:**

- Unit tests live in the separate `Tennis TrainerTests/` target directory.
- UI tests live in the separate `Tennis TrainerUITests/` target directory.
- Tests are not co-located with implementation files.

**Naming:**

- Xcode-generated target files use `Tennis_TrainerTests.swift`, `Tennis_TrainerUITests.swift`, and `Tennis_TrainerUITestsLaunchTests.swift`.
- Behavior tests use the `test<Behavior_WhenCondition>` convention prescribed by `AGENTS.md`; `ServeTossApexDetectorTests.swift` follows this with names such as `testPeakBelowHeightGateDoesNotFire`.

**Structure:**

```
Tennis TrainerTests/
├── Tennis_TrainerTests.swift                 # Swift Testing scaffold
└── ServeTossApexDetectorTests.swift          # XCTest detector coverage
Tennis TrainerUITests/
├── Tennis_TrainerUITests.swift                # launch/performance scaffold
└── Tennis_TrainerUITestsLaunchTests.swift     # launch screenshot test
```

## Test Structure

**Suite Organization:**

```swift
final class ServeTossApexDetectorTests: XCTestCase {
    private final class StubHeightGateProvider: ServeTossApexHeightGateProviding { ... }

    private func sample(t: CFTimeInterval, y: CGFloat, conf: Float = 0.9)
        -> GridTrackNetDetector.Sample { ... }

    private func runDetector(samples: [GridTrackNetDetector.Sample], ...)
        -> [Int] { ... }

    func testSingleParabolicTossAboveFallbackGateFiresExactlyOnce() {
        let samples = (0..<30).map { ... }
        let firings = runDetector(samples: samples)
        XCTAssertEqual(firings, [3])
    }
}
```

**Patterns:**

- Keep reusable test setup private within the test type. `ServeTossApexDetectorTests` provides a sample factory, a provider stub, and a batch runner.
- Drive the detector with deterministic synthetic data rather than wall-clock time or camera frames. The tests use a sinusoidal toss trajectory and explicit timestamps.
- Assert observable outcomes: exact firing batches, firing counts, or an empty result. This covers cooldown, height gates, confidence filtering, and repeated toss behavior.
- UI tests set `continueAfterFailure = false` in `setUpWithError()`, launch `XCUIApplication()`, and use `@MainActor` on test methods that interact with the app.
- The launch screenshot test stores an `XCTAttachment` named `Launch Screen` with `.keepAlways` lifetime in `Tennis TrainerUITests/Tennis_TrainerUITestsLaunchTests.swift`.

## Mocking

**Framework:** No mocking library is configured. Tests use a hand-written protocol stub.

**Patterns:**

```swift
private final class StubHeightGateProvider: ServeTossApexHeightGateProviding {
    let serveTossApexGateBaselineY: CGFloat?

    init(baselineY: CGFloat?) {
        self.serveTossApexGateBaselineY = baselineY
    }
}
```

**What to Mock:**

- Mock narrow protocol seams that control detector decisions, such as `ServeTossApexHeightGateProviding` in `Tennis TrainerTests/ServeTossApexDetectorTests.swift`.
- Prefer deterministic values and pure sample streams for signal-processing tests.

**What NOT to Mock:**

- Do not introduce a broad mock for Core ML, AVFoundation, Vision, or SwiftUI unless a test specifically needs an injectable boundary. There is currently no test double for `CameraManager`, `VideoPlayerManager`, `GridTrackNetDetector`, or UI navigation.

## Fixtures and Factories

**Test Data:**

```swift
let samples = (0..<30).map { i in
    let y = 0.5 + 0.4 * sin(.pi * Double(i) / 30.0)
    return sample(t: Double(i) * 0.033, y: y)
}
```

**Location:**

- No shared fixture directory or external fixture files were detected.
- Synthetic samples are built inline through the private `sample` helper in `Tennis TrainerTests/ServeTossApexDetectorTests.swift`.

## Coverage

**Requirements:** No coverage target, threshold, or CI coverage gate was detected in `Tennis Trainer.xcodeproj`, the shared schemes, or repository configuration.

**View Coverage:** Use Xcode’s test coverage UI or add an explicit Xcode test/coverage invocation when coverage reporting is required. No repository command is documented for it.

## Test Types

**Unit Tests:**

- The strongest current unit coverage targets the stateful serve-toss signal detector in `Tennis Trainer/Detectors/ServeTossApexDetector.swift`.
- Covered behaviors include a single valid toss, two tosses separated by cooldown, two tosses within cooldown, fallback height rejection, pose-relative height rejection, and low confidence around the apex.

**Integration Tests:**

- Not detected. There are no tests that exercise the camera/video manager to detector pipeline, Core ML tensor decoding, orientation/scaling, audio callback wiring, or `AppRuntime.isRunningTests` behavior.

**E2E Tests:**

- UI tests provide launch smoke coverage only. `Tennis TrainerUITests/Tennis_TrainerUITests.swift` launches the app and contains a launch performance measurement, but it has no element assertions or interaction flow.

## Common Patterns

**Async Testing:**

- The Swift Testing scaffold declares `@Test func example() async throws`, but does not await work or assert a result in `Tennis TrainerTests/Tennis_TrainerTests.swift`.
- Production async work uses `DispatchQueue`, `Task`, and `MainActor.run`; no test helper for async callbacks or queue synchronization is present.

**Error Testing:**

- Error paths are not directly tested. Existing tests assert only detector outputs for valid and rejected sample streams.
- When adding behavior tests, prefer an observable return value or callback count over inspecting `print` output. Relevant untested failure paths include camera permission/configuration in `Tennis Trainer/CameraManager.swift`, video loading in `Tennis Trainer/VideoPlayerManager.swift`, and model output failures in `Tennis Trainer/Detectors/GridTrackNetDetector.swift`.

## Coverage Gaps and Priorities

- High: Add tests around `Tennis Trainer/Detectors/GridTrackNetDetector.swift` tensor shape/stride indexing, FP16 decoding, temporal sample mapping, and portrait/landscape scaling; these paths are model-sensitive and currently untested.
- High: Add manager-level tests for reset and callback behavior in `Tennis Trainer/BallDetectionManager.swift` and `Tennis Trainer/VideoPlayerManager.swift`.
- Medium: Add tests for `Tennis Trainer/PoseDetectionManager.swift` confidence filtering and `ServeTossApexHeightGateProviding` baseline selection.
- Medium: Expand UI coverage beyond launch to mode switching, video picker presentation, playback controls, and camera permission states in `Tennis Trainer/ContentView.swift`.
- Low: Replace the empty Swift Testing scaffold in `Tennis TrainerTests/Tennis_TrainerTests.swift` with an assertion or remove it if XCTest remains the project standard.

---

*Testing analysis: 2026-09-19*
