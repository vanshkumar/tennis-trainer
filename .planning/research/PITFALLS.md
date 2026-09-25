# Pitfalls Research

**Domain:** Existing iOS 18.5 tennis toss-apex cue; live camera and saved-video reliability
**Researched:** 2026-09-24
**Confidence:** MEDIUM — GSD `classify-confidence --provider websearch --verified`; Apple API contracts cross-checked against local source. Recommendations below are project inferences, not measured runtime failures.

Scope preserves the bundled GridTrackNet model, portrait UI, right-handed solo practice, and local processing. Source evidence: [project scope](../PROJECT.md), [concerns](../codebase/CONCERNS.md), and [test map](../codebase/TESTING.md). No builds, tests, clip trials, or device measurements were performed. Phase names below describe dependencies for roadmap creation, not existing numbered phases.

## Critical Pitfalls

### Pitfall 1: A serial queue masquerades as bounded inference

**What goes wrong / why:** `BallDetectionManager.process` checks and clears `isInFlight` inside each serially executed closure; later closures see a cleared flag. `GridTrackNetDetector.pushFrame` also waits on the prediction lock. Serial execution neither bounds pending requests nor guarantees responsive frame admission.
**How to avoid:** Make admission atomic before expensive processing/enqueueing. Specify a fixed active/pending bound and a deliberate drop/coalescing policy; preserve five-frame temporal order. Keep session lifecycle separate and measure preprocessing wait separately from inference. Apple explicitly assigns downstream queue memory bounds to the app. [A1]
**Warning signs:** Increasing input-to-result age, repeated inference on the same window, growing retained buffers, or blocked playback controls despite stable reported FPS.
**Phase to address:** Pipeline integrity first; lifecycle and timing validation depend on this boundary.
**Targeted validation:** Hold a fake inference open while submitting a burst; assert the chosen active/pending bounds, dropped/coalesced identities, bounded retained buffers, and immediate invalidation on stop. Do not claim a measured throughput threshold from this test.

### Pitfall 2: Correct predictions are attached to the wrong frame window

**What goes wrong / why:** Prediction, `times`, and `frameMappings` are read in separate synchronized operations. A concurrent push can relabel a prediction with newer timestamps or transforms; a queue fix alone does not close this race.
**How to avoid:** Snapshot pixels, timestamps, orientation/source mappings, frame IDs, and generation as one immutable request; return that identity with outputs. Retain buffer ownership through prediction. Remove the missing-timestamp fallback to `CACurrentMediaTime()` from result decoding; reject malformed metadata instead of mixing clock domains.
**Warning signs:** Ball position moves with a later frame's dimensions, duplicate window IDs, or media-time samples unexpectedly resembling host uptime.
**Phase to address:** Pipeline integrity before geometry and cue calibration.
**Targeted validation:** Pause prediction, append differently timestamped/sized frames, then release it; every decoded sample must retain its original window's timestamp and mapping. Test all five temporal indices and metadata-count failures.

### Pitfall 3: Reset clears storage but allows stale effects to escape

**What goes wrong / why:** Inference and main-queue callbacks already scheduled before stop, pause, seek, replacement, or mode switching can repopulate overlays and fire a beep. Cancellation or clearing a buffer alone cannot invalidate those callbacks.
**How to avoid:** Increment an analysis generation immediately at every invalidating transition; check it at admission, completion, and the final UI/audio effect boundary. Serialize cue reset with cue consumption. During seek, suspend admission until the current seek completes successfully; superseded seek completion must not resume analysis. [A3]
**Warning signs:** Beeps while paused, an old-mode pose appearing in the new mode, or a brief old ball dot after clearing overlays.
**Phase to address:** Establish generations in pipeline integrity; apply them to every lifecycle transition before end-to-end validation.
**Targeted validation:** Suspend work both before inference completion and after main-queue dispatch, perform each transition, then release work; assert zero stale effects. Repeat overlapping seeks with reversed completion order and verify only the current generation resumes.

### Pitfall 4: Display ticks are mistaken for unique, uniformly spaced frames

**What goes wrong / why:** `VideoPlayerManager` samples on `CADisplayLink`, supplies `player.currentTime()`, ignores `itemTimeForDisplay`, and does not check `hasNewPixelBuffer`. Display refresh, media cadence, and analysis cadence differ; an irregular/repeated sample stream can distort a five-frame model window and apex timing. Camera timestamps currently use host time after pose work rather than capture presentation time.
**How to avoid:** Acquire only new player output, use the returned frame display time, and preserve camera sample presentation timestamps. Keep media time separate from monotonic performance time. Deduplicate overlapping model outputs by frame identity/time; reset at discontinuities and define gap handling from measured cadence. Apple's output API distinguishes previously acquired output. [A2]
**Warning signs:** Five nominal samples contain repeated images, apparent velocity depends on display refresh, or replay/seek changes cue count for the same toss.
**Phase to address:** Pipeline integrity and playback lifecycle before clip baselines; gap tolerance needs focused phase research.
**Targeted validation:** Feed repeated timestamps, unequal intervals, dropped frames, backward jumps, and overlapping five-sample batches. Compare repeated normal-speed runs of explicitly acquired clips; do not assume five accepted frames represent a fixed duration.

### Pitfall 5: Source, model, and display coordinates are conflated

**What goes wrong / why:** Correct source-normalized points still drift when multiplied by full view bounds. Model preprocessing currently uses portrait aspect-fit and other-source aspect-fill; camera preview uses fill and playback uses fit. The blanket aspect-fill note in `AGENTS.md` differs from current code/project scope and must not silently dictate a preprocessing change.
**How to avoid:** Define an explicit oriented-source coordinate contract, preserve each frame's model transform, and compose source-to-display transforms including crop/padding and one bottom-left-to-top-left conversion. Use the actual player image rectangle, whose size/position depends on gravity and media aspect. [A4]
**Warning signs:** Overlay is accurate centrally but wrong at edges, portrait tosses enter black bars, or pose and ball agree with each other but miss the displayed player.
**Phase to address:** Geometry after immutable frame metadata; preserve current preprocessing until a deliberate, clip-validated decision changes it.
**Targeted validation:** Map corners/center and known joint/ball fixtures through portrait, landscape, rotated, fit, and fill cases; verify model-to-source round trips and displayed placement separately. Visually check real layer layout after sizing, not only the transform helper.

### Pitfall 6: A high-confidence pose is stale for the ball candidate

**What goes wrong / why:** `PoseDetectionManager` returns early on no observation, leaving old joints. `ServeTossApexDetector` reads the latest mutable nose/neck baseline while consuming historical ball samples. Confidence does not establish temporal or session association.
**How to avoid:** Timestamp and generation-tag pose snapshots; explicitly expire/clear missing observations. Associate the apex candidate with a valid pose from its own source/time or deliberately use the existing fallback gate. Choose maximum pose age and gap behavior during validation; do not invent them here.
**Warning signs:** Height gate remains tied to a departed player, jumps after mode switch, or changes when inference delays change despite identical ball samples.
**Phase to address:** Temporal association during pipeline integrity, then cue regression validation; avoid adding multi-player tracking to this milestone.
**Targeted validation:** Delay pose relative to ball, remove observations, swap generations, and vary a later pose's height. Assert candidate decisions use the eligible historical pose or declared fallback, and no stale pose overlay survives reset.

### Pitfall 7: Callback timing is reported as audible cue latency

**What goes wrong / why:** `AudioManager.playBeep()` only schedules audio, while tests skip audio setup. Apex confirmation itself requires a later descending sample; a passing callback-count test cannot establish onset accuracy or the player's perceived delay. Nil-time audio scheduling can follow earlier scheduled audio. [A5]
**How to avoid:** Record capture/media sample time, candidate apex time, confirmation, inference completion, scheduling, and physical beep onset with explicit clock mapping. Distinguish consumed/rendered/played-back completion; played-back marks completion, not beep onset. Record audio route and interruptions alongside trials. [A5, A6]
**Warning signs:** Good callback latency with a late/silent beep, buffered beeps after transitions, or a route-dependent timing change hidden by one aggregate number.
**Phase to address:** Instrumentation starts with pipeline integrity; audible clip/device acceptance follows lifecycle and geometry fixes.
**Targeted validation:** Use deterministic tests for event counts and invalidation, then synchronized video/audio observation on an available real device for apex-to-sound onset and missed/extra cues. Cover supported audio routing and interruption recovery. Define devices, clips, annotation method, and acceptance limits before declaring success; none are established yet.

### Pitfall 8: Permission granted is treated as capture running

**What goes wrong / why:** The visible permission action is empty; capture UI state is set before session start succeeds. Permission, configuration, user intent, and actual running state can diverge after denial, Settings changes, or setup failure.
**How to avoid:** Model authorization and capture state separately. Request only from undetermined state, provide Settings recovery for denial, explain restriction, and recheck on foreground return. Make configuration idempotent and publish actual success/failure; keep session operations on the dedicated session queue. Apple's authorization decision persists. [A7]
**Warning signs:** Enabled Stop control without capture, a dead permission button, or duplicate configuration attempts after returning from Settings.
**Phase to address:** Lifecycle recovery after generation-safe stop is available.
**Targeted validation:** Inject authorization/configuration outcomes for every state; test repeated foreground/start/stop. Perform actual deny → Settings grant → return flow when a device is available; simulator or stub success is not device evidence.

### Pitfall 9: A replaced clip keeps its asynchronous owners alive

**What goes wrong / why:** Natural completion is unobserved; repeated play can create another display link. Old asset-loading tasks can update duration or seek the replacement player. Picker copies use source basenames, risking collisions, and cleanup never deletes owned copies.
**How to avoid:** Give each clip/load a token and owned unique local URL; guard task completion by item identity. Scope end/failure observers to the active item, marshal state updates appropriately, make play/cleanup idempotent, and release observers/output/display link before deleting owned files. Copy the provider's temporary file before its callback returns. [A8, A9]
**Warning signs:** Wrong duration after rapid selection, work continuing at end-of-video, double callbacks after repeated Play, or accumulated/colliding temporary files.
**Phase to address:** Playback lifecycle after generation handling; permission UI may proceed independently once the shared contract exists.
**Targeted validation:** Exercise A → B selection with A completing last, same-basename imports, end → replay, repeated play/pause, failed/cancelled loads, and disposal. Assert one display link, correct item state, no old events, owned-copy deletion, and preservation of externally owned files.

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Tune confidence/cooldown before fixing identity | Changes demo behavior quickly | Masks association bugs; unreliable clip comparisons | Only after temporal invariants pass |
| Use latest UI pose as detector input | No sample store | Nondeterministic candidate gating | Only with an explicit valid time/generation contract |
| Treat launch tests as reliability evidence | Cheap green CI | Cue, lifecycle, and geometry regressions remain invisible | Smoke coverage only |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Core ML tensors | Assume output layout or reuse confidence strides for offsets | Validate names/types/shapes, preserve each tensor's strides and FP16 decoding; fixture-test independent strides and malformed outputs |
| Vision/Core ML | Correct orientation twice or apply model padding to pose coordinates | Declare oriented-source geometry once; transform pose and decoded ball through the same display map |
| AVFoundation | Adopt newer/beta overloads from current docs during a reliability fix | Keep iOS 18.5-compatible calls; verify availability separately if changing API surface |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Core Image/Vision work on playback's main display-link callback | Stuttering controls and frame sampling gaps | Move expensive work behind bounded admission | When processing exceeds available display time; measure on chosen devices |
| Assume configured 120 FPS equals analyzed 120 FPS | Timing claims diverge from actual input | Measure capture PTS, drops, accepted windows, and result age | Under load or unsupported capture formats; no fixed device threshold established |

## Security and UX Pitfalls

| Mistake | Impact | Prevention |
|---------|--------|------------|
| Cleanup removes URLs without ownership | Deletes a caller's clip or another active import | Unique owned copies, scoped deletion, replacement-race tests |
| Retain stale pose/ball as if current | Player trusts feedback from an old toss | Clear/invalidate visibly with source transitions and missing observations |
| Add cloud telemetry to diagnose timing | Changes the approved local-processing scope | Use bounded local diagnostics and explicitly chosen validation clips |

## "Looks Done But Isn't" Checklist

- [ ] Work is bounded at admission, not merely serialized; immutable frames and metadata survive concurrent pushes.
- [ ] Every reset/seek/mode transition rejects stale main-queue callbacks as well as worker results.
- [ ] Unique frame timestamps, tensor decoding, display transforms, and pose age have observable regression coverage.
- [ ] Permission recovery, completion/replay, replacement races, and owned-file cleanup work beyond the happy path.
- [ ] Repeatable clip evidence reports misses, extra cues, and timing; physical audio onset/device checks are completed or explicitly outstanding.

## Recovery Strategies and Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase / Dependency | Recovery and Verification |
|---------|------------------------------|---------------------------|
| Queue/window/clock mismatch | Pipeline integrity first | Invalidate generation, drop pending work, rebuild a fresh five-frame window; rerun burst and interleaving fixtures |
| Stale effects/pose, seek/load races | Lifecycle after generation contract | Stop admission, clear affected state, resume only current source; rerun delayed-callback transition matrix |
| Geometry mismatch | Geometry after immutable metadata | Restore proven preprocessing; verify separate model/source/display fixtures before tuning model behavior |
| Unproven audible timing | Validation after preceding correctness | Keep acceptance unverified; acquire documented clips/devices and establish measured baseline before choosing limits |

## Sources

All Apple links checked 2026-09-24; living API pages do not establish app performance or iOS availability of every linked overload. MEDIUM confidence applies throughout; failure mechanisms are source-grounded, while frequency/severity on devices remains unmeasured.
- [A1: Apple capture delegate queue responsibility](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput/setsamplebufferdelegate(_:queue:)) and [late-frame dropping](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput/alwaysdiscardslatevideoframes).
- [A2: New player output](https://developer.apple.com/documentation/avfoundation/avplayeritemvideooutput/hasnewpixelbuffer(foritemtime:)) and [frame/output display-time API](https://developer.apple.com/documentation/avfoundation/avplayeritemvideooutput).
- [A3: Seek completion and interruption](https://developer.apple.com/documentation/avfoundation/avplayer/seek(to:tolerancebefore:toleranceafter:completionhandler:)).
- [A4: Rendered video rectangle](https://developer.apple.com/documentation/avfoundation/avplayerlayer/videorect).
- [A5: Audio scheduling and player timeline](https://developer.apple.com/documentation/avfaudio/avaudioplayernode); [A6: Played-back completion](https://developer.apple.com/documentation/avfaudio/avaudioplayernodecompletioncallbacktype/dataplayedback) and [output latency](https://developer.apple.com/documentation/avfaudio/avaudiosession/outputlatency).
- [A7: Camera authorization](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media).
- [A8: Item completion notification](https://developer.apple.com/documentation/avfoundation/avplayeritem/didplaytoendtimenotification); [A9: Provider temporary-file lifetime](https://developer.apple.com/documentation/foundation/nsitemprovider/loadfilerepresentation(fortypeidentifier:completionhandler:)).
- Local inspection: `BallDetectionManager.swift`, `Detectors/GridTrackNetDetector.swift`, `Detectors/ServeTossApexDetector.swift`, `PoseDetectionManager.swift`, `VideoPlayerManager.swift`, `VideoPickerView.swift`, `CameraManager.swift`, and `AudioManager.swift` under `Tennis Trainer/`; mapped overlay evidence in `.planning/codebase/CONCERNS.md`.
