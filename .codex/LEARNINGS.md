# LEARNINGS

## 2026-04-27

- Repo reality: the serve toss-apex cue is now live; the old `ForearmHorizontalDetector` path has been parked under `Tennis Trainer/Archived/Forehand/FOREHAND_ARCHIVE.md`.
- Friction point: under `PBXFileSystemSynchronizedRootGroup`, archive docs placed inside the app target tree are copied as bundle resources. Two different `README.md` files under `Tennis Trainer/Archived/` collided at build time, so archive docs need unique filenames.
- Detection seam: `BallDetectionManager` already emits 5-sample GridTrackNet tracks through `onBallTrack`, which is the intended integration point for a future serve apex detector.
- Testing state: `ServeTossApexDetectorTests` covers the serve-apex detector; UI tests are still default launch scaffolds.
- Workspace note: The repo currently has pre-existing `.DS_Store` changes (`.DS_Store`, `Tennis Trainer/.DS_Store`). Do not treat them as task-related changes.
- Organization principle: keep `AGENTS.md` short and navigational; put durable repository knowledge in a lightweight `docs/` map plus focused source-of-truth files such as `ARCHITECTURE.md`.
- Signpost: when the user says `.DS_Store` must not be pushed, update `.gitignore` and remove any tracked `.DS_Store` from the git index with `git rm --cached` rather than leaving it staged as a normal modification.
- Friction point: `xcodebuild` initially failed before compilation because Xcode first-launch components were incomplete; `xcodebuild -runFirstLaunch` repaired that part of the local toolchain.
- Friction point: after first-launch repair, simulator verification was temporarily blocked until the iOS 26 simulator runtime was installed. Once installed, `xcodebuild -showdestinations -scheme "Tennis Trainer"` exposed valid simulator destinations again.
- Signpost: when CLI build/test fails in this repo, separate three classes of issues before changing code: Xcode first-launch/plugin health, sandbox/CoreSimulator access, and actual scheme destination availability.
- Friction point: on this machine, `xcodebuild test -scheme "Tennis Trainer"` reaches app and test-runner packaging, then goes silent before any executed-test summary appears. The same thing happens with `-only-testing:Tennis TrainerTests`; the scheme still builds `Tennis TrainerUITests-Runner.app`, so `only-testing` does not isolate the unit-test harness here.
- Fix: split the shared schemes so `Tennis Trainer.xcscheme` contains only `Tennis TrainerTests`, and `Tennis Trainer UI Tests.xcscheme` contains `Tennis TrainerUITests`. This removes the UI-test runner from the default CLI unit-test path.
- Friction point: the first boot of the iOS 26.3 simulator can make `xcodebuild test` look hung before any tests launch. `xcrun simctl bootstatus <UDID> -b` exposed that the simulator was still in data migration and then waiting on system apps.
- Signpost: if `xcodebuild test` is silent and no `xctest` process appears, check simulator first-boot state with `simctl bootstatus` before assuming the scheme or test code is broken.
- Friction point: even after the simulator finished first-boot migration and the default scheme was narrowed to unit tests, the hosted `Tennis TrainerTests` bundle still hangs after packaging and codesigning, before any XCTest execution output appears.
- Fix: once the simulator finished first-boot migration, hosted XCTest launched correctly. The remaining red tests were real detector logic failures, not harness failures.
- Root cause: `ServeTossApexDetector.consume` only evaluated `buffer[count - 2]` once per batch, so 5-sample batches could skip the true apex entirely. Walking each newly eligible triplet once fixed the missed-apex behavior and made the detector tests pass.
