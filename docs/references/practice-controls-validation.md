# Practice controls validation — 2026-09-26

This ledger records Phase 2 implementation evidence. The user deferred physical-device checks to phase end; that decision changes timing only. It does not approve the unperformed checks or the six undefined edge contracts.

## Automated commands and evidence

Host: Xcode 27.0, arm64 iPhone 17 Pro simulator, iOS 26.5 (23F77), UDID `75781558-668B-412B-A9BD-5DBB1CE13CF4`. Deployment target remains iOS 18.5. All runs disable parallel simulator testing because this host previously failed to launch a parallel clone.

```sh
xcodebuild test -scheme 'Tennis Trainer' \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -parallel-testing-enabled NO -collect-test-diagnostics never '-only-testing:Tennis TrainerTests' \
  -resultBundlePath /tmp/tennis-0204-verified-final.xcresult

xcodebuild test -scheme 'Tennis Trainer UI Tests' \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  '-only-testing:Tennis TrainerUITests/Tennis_TrainerUITests/testVideoImportRecoveryControls' \
  '-only-testing:Tennis TrainerUITests/Tennis_TrainerUITests/testVisibleOverlayClearOnStopAndPause' \
  -resultBundlePath /tmp/tennis-0204-ui-final.xcresult

xcodebuild build -scheme 'Tennis Trainer' -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO
```

Raw logs use the same result basename with `.log`; Release log is `/tmp/tennis-0204-release-final.log`. Exact counts are read with `xcrun xcresulttool get test-results summary --path <bundle> --compact`. Final outcome is recorded in 02-04-SUMMARY.md after all commands finish.

The first final attempt (`tennis-0204-verified`) printed 145 passing tests, then stalled collecting simulator diagnostics. After about four minutes the owned xcodebuild process was terminated (exit 143); its incomplete bundle is not counted as command success. A stack sample at `/tmp/tennis-0204-xcodebuild-sample.txt` identifies `XCTHRunDestinationAllocator.collectSimulatorDiagnostics`. The complete suite was rerun with the supported `-collect-test-diagnostics never` flag; no test was excluded or retried selectively.

| Evidence | Executed result | What it establishes |
|---|---|---|
| Import tracer and committed feedback gate | 5/5 each, zero skips | Synchronous provider-lifetime copy, unique names, cancellation, partial cleanup and accepted paused player |
| Candidate focused final | 51/51, zero skips | Metadata/readiness ordering, stale errors, context cancellation, delayed leases and fresh cue recovery |
| Final full unit target | 145/145, zero failures/skips | Phase 1 regression plus current Phase 2 camera, playback, import and lifecycle tests |
| Required rendered recovery/clear UI | 2/2 in both initial and final runs, zero failures/skips | Real SwiftUI buttons and observable state under explicitly injected effects |
| Generated movie integration | 1 real AV test in every final full run | Framework readiness, seek completion, native end, Replay and original-owner teardown |
| Final Release build | Exit 0; BUILD SUCCEEDED | Production configuration compiles with DEBUG-only scenario implementations excluded |

Final unit inventory: AnalysisAssociationTests 10, BallDetectionManagerTests 22, CameraManagerTests 21, GridTrackNetDecoderTests 6, PoseDetectionManagerTests 4, PracticeLifecycleTests 23, ServeTossApexDetectorTests 23, VideoImportManagerTests 9, VideoPlayerManagerTests 26, Swift Testing scaffold 1. No required class or named integration is replaced by the scaffold.

## Ownership and lifecycle results

- One hundred import/play/pause/seek/replacement cycles retain at most one active extraction loop, one periodic observer and one timeline event registration. Every installed injected observer removal runs once; repeated shutdown is idempotent. Delayed old callbacks cannot take over the current session. Weak probes confirm they do not retain the manager.
- After all delayed consumer closures drain, all 100 uniquely owned copies are removed exactly once and no external path appears in the removal ledger. While consumers are intentionally held, their leases remain; cancellation is not completion. Separate tests hold metadata, seek and reentrant output-reader consumption across retirement.
- Real filesystem tests preserve an external original and an unknown legacy file. Copies live under `PracticeImports` with generated UUID names and allowed media extensions. No legacy sweep is performed. A destination-exists copy error never authorizes removal of the existing file.
- Metadata requires playability, a video track and finite positive duration. Only the current candidate with ready status commits. Production readiness notifications reread current item state after dispatch. Old callbacks cannot alter current duration, position, error/loading state or selection. Failed/cancelled replacements preserve the previous selection paused.
- PlaybackSession removes periodic tokens from their registering player, output from its attached item, disconnects its layer, detaches the player's item and releases its file handle. Metadata and queued callbacks keep independent leases until they return. Timeline events retain 02-03's originating load/run identity and fresh backend reconciliation; old native events are not relabeled as current.
- Stop, Pause, seek, replacement, completion, mode exit and scene suspension exercise both held analysis stages across the lifecycle suite. Fresh five-frame warmup and a subsequent synthetic toss cue are positive controls. The UI clear test seeds active-mode ball/pose publishers, taps actual Stop/Pause and observes both overlays disappear without any frame-counter tick.

## Evidence boundaries

The DEBUG import UI scenario supplies synthetic provider outcomes and injected player effects. Its three-byte file is only an import-boundary fixture and never serves as codec, tennis or physical-device evidence. The generated AV movie is a separate one-second 64×64 H.264 local movie created by AVAssetWriter during the test and deleted by that test afterward. It contains no personal footage and does not exercise toss detection quality. Production parsing and playback remain AVFoundation.

No target/bundle, model weights, tensor contract, preprocessing, geometry formula, confidence gate, strict missing-pose fallback above 0.70, or rational four-second cooldown changed. Both source modes retain Phase 1 admission/buffer invariants. Phase 3 owns displayed coordinate alignment; Phase 4 owns labeled clips, frozen empirical bounds, sustained device/process memory and physical sound-onset timing. The controlled semaphore-test QoS warning remains WINDOWS entry 1 and is not a production timing measurement.

## Pending phase-end review

All rows below remain pending until actually performed or explicitly dispositioned; automated success does not silently close them.

| Obligation | Required evidence / owner |
|---|---|
| Physical permission and Settings | Request; denial → Settings grant → return; revocation → return; available restriction cases. Record device/OS/build and unsupported scenarios. WINDOWS 3 |
| Physical capture lifecycle | Actual startup, Stop during startup, interruption, Stop during recovery, foreground return and explicit Retry. WINDOWS 4 |
| Representative playback inspection | Real personal/permitted clip selection, repeated scrubbing, Pause during seek, end and Replay. Generated AV test is additional framework evidence, not this inspection. WINDOWS 5 |
| EDGE-LIFE-01 | Unclassified/unresolved: human must classify or explicitly accept control-intent invalidation through both held stages and ingress races |
| EDGE-LIFE-02 | Unclassified/unresolved: human must classify or accept fresh-window/no-retrospective-cue semantics, including partial toss loss |
| EDGE-CAM-02 | Unclassified/unresolved: actual state versus requested intent and Stop dominance during startup/interruption/recovery |
| EDGE-PLAY-01 | Unclassified/unresolved: latest successful current seek, current intent, false completion and explicit retry |
| EDGE-PLAY-02 | Unclassified/unresolved: Ended, zero-seek Replay and fresh-window/cooldown semantics |
| EDGE-PLAY-03 | Unclassified/unresolved: prior usable selection paused after failed/cancelled replacement and current ready candidate commit |
| Transparency prohibition | Descriptor-less projected prohibition remains flagged/unverified until explicit human evidence-limit review; WINDOWS 6 |
| Phase 4 empirical acceptance | Permitted labeled corpus, independent annotations, criteria frozen before scoring, raw missed/extra/duplicate/stale counts and denominators, accepted frame gaps, sustained process memory and physical audio timing with synchronization uncertainty |

The two defined concurrency predicates EDGE-CAM-01 and EDGE-PLAY-04 have deterministic implementation evidence. The six unclassified rows retain their original category and status. Eight surfaced edge items = two explicit tested predicates + six pending human dispositions; none were auto-resolved.

The retained prohibition is unchanged:

> MUST NOT present injected lifecycle tests or software cue callbacks as proof of real camera permission recovery, physical capture behavior, clip accuracy, or audible timing.

See `.planning/phases/02-dependable-practice-controls/02-COVERAGE.md`, `02-02-CHECKPOINT.md`, `02-04-SUMMARY.md`, `.planning/WINDOWS.md` and [toss cue validation](toss-cue-validation.md). Requirement checkboxes are not modified by this ledger.
