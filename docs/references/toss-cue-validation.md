# Toss cue validation protocol v1

Recorded 2026-09-25 before Phase 01 production edits. This is a reproducible
source reference and evaluation protocol, not a measured accuracy baseline.

## Source and settings

- Research baseline: `1bae995d96650b2619faeebe568a36715f50db0d` (verified commit).
- Pre-execution HEAD: `2a1da7e613b8bcb9268a9cdd767436e84b8c967c`.
- `git diff` from baseline over app, unit tests and Xcode project was empty.
  Planning state/config changes are separate from app behavior.
- SHA-256, bundled `Tennis Trainer/Models/GridTrackNet5.mlpackage/`:
  - `Manifest.json`: `19e2a486f9c3f6b7695270467f7177a3ec968effcd266a854941d7a7443c613d`
  - `Data/com.apple.CoreML/model.mlmodel`: `f573c0bf2b2b5f2a64885b7b24a9d0959821711c70b335325e4379e7dc50fb42`
  - `Data/com.apple.CoreML/weights/weight.bin`: `2c5ebf00f413c05ec91b7d1ec7e0c0c762edb636aef3fac9ba847cf618ed1866`
- GridTrackNet: RGB 768×432; five oldest-to-newest frames; portrait aspect-fit,
  other orientations aspect-fill after orientation; independent tensor strides;
  FP16 heads `conf`, `x_off`, `y_off`; grid 48×27; confidence ≥0.5;
  source-normalized bottom-left origin; live/playback overlay index 4.
- Apex: strict three-point local maximum, confidence ≥0.5, horizon 1.5 s,
  cooldown 4.0 s in candidate source time, height strictly above nose then neck
  (confidence >0.3) +0.05; missing-pose fallback strictly above 0.70.
- Color fallback: stride 4; green ≥150, red ≥105, blue ≤100; brightness sum ≥380,
  green-red ≥20, green-blue ≥60; shoulder margin 0.02; radius 0.06;
  lead 1/60 s, at most 3 predicted misses; Kalman q=30, r=0.0003;
  dt clamped to 1/240…1/15 s. No automatic apex cue from this backend.
- Existing capture requests 120 FPS where supported; actual cadence is unknown.
  Keep iOS 18.5 target and existing audio tone (800 Hz, 0.2 s, amplitude 0.3).
- Old admission checks run inside queued inference; this is not a bounded queue.
  Old camera timestamps use host time after pose; old playback uses requested
  player time. Neither old callback timestamps nor simulator runs prove sound timing.

## Permitted media inventory v1

No `.mov` or `.mp4` fixtures were found in the repository file inventory.
Permission for outside media is unknown; no footage was downloaded or acquired.
No pre-change empirical run was possible with established permitted inputs.

For each future clip record: stable ID, local path, SHA-256, permission evidence,
provenance/owner, whether the app owns its local copy, acquisition date,
dimensions, preferred transform/orientation, nominal and actual frame cadence,
duration, rational media timebase and PTS discontinuities. Current status:
**unavailable / pending permission and inventory**. Never delete externally owned media.

Independent annotators label apex intervals in source time before inspecting
detector output. Record label uncertainty, full observation versus partial or
ambiguous toss, body/ball framing, confidence/height eligibility, and cooldown
eligibility. Keep ambiguous, partial and ineligible events separate, with reasons.
Assign tuning and confirmation partitions before tuning; confirmation clips must
remain unseen during tuning. If too few clips exist, report that limitation.

## Physical device inventory v1

Supported physical iPhone, OS/build, camera/tripod setup, lighting, available
storage, thermal conditions, audio route/volume, recording equipment and permission
are **unknown / pending**. Simulator iPhone 17 Pro iOS 26.5 is a software test
destination only. Physical live/playback, sustained-run and audible timing checks
are unperformed; they remain required Phase 4 evidence.

## Trial and scoring rules

Use original media at 1× playback, three repeat trials per clip/build; log any
departure as a separate condition. Record build revision, model hashes, complete
settings, device/OS, accepted source times and gaps, admitted/dropped counts,
resets and source/generation identities. Diagnostics stay explicit, local and
bounded; ordinary production diagnostics retain scalar counts only, no media logs.

Freeze a numeric matching tolerance from baseline evidence before confirmation
scoring (currently **pending**, no numeric accuracy/gap/latency acceptance limit).
Match eligible labels and automatic callbacks one-to-one in source-time order,
using the frozen tolerance and minimum interval distance; break ties by earlier
label. Never reuse a label or callback. Unmatched eligible labels are missed;
additional callbacks near an already matched toss are duplicates; other unmatched
callbacks are extras. Any callback after invalidation from its obsolete source or
generation is stale, even if near a label. Record overlapping classifications
explicitly without counting a single callback twice in total callback counts.

Report raw eligible-label, matched, missed, extra, duplicate and stale counts;
recall denominator = fully observed eligible labels; precision denominator = all
automatic callbacks; repetition-level and aggregate results separately. Report
partial/ambiguous/ineligible counts outside the eligible denominator. Manual Test
Beep is excluded. A zero denominator is unavailable, never a perfect score.

Separate clocks: labeled source apex interval, source confirmation frame,
monotonic worker completion, monotonic callback scheduling, and physical sound
onset. Do not subtract source CMTime from host time. Physical latency requires
synchronized audiovisual measurement, explicit clock mapping and uncertainty,
device/build/audio-route details; callback timing alone is insufficient.

## Resource ledger and pending evidence

Planned policy: one admitted job through publication per manager, zero pending
inputs, at most one publication; two retained media managers double those bounds.
These are targets until deterministic tests pass. Distinct prepared-buffer and
apex-history accounting belongs to 01-03; immutable window and candidate-pose
association belongs to 01-02. Sampling sufficiency, accepted-gap bounds, accuracy,
overlay error and physical sound latency remain unmeasured. Freeze final criteria
with version/date and rationale before Phase 4 scoring; never tune on confirmation
results without declaring a new protocol version and a fresh confirmation set.

## Phase 01 execution evidence — 2026-09-25

The source/settings and protocol above remain the before-change reference. This
entry adds deterministic results; it does not freeze new empirical acceptance
bounds or claim a measured clip/audio baseline.

Test host: Xcode 27.0, arm64 iPhone 17 Pro simulator, iOS 26.5 build 23F77.
The deployment target remains iOS 18.5. Implementation starts from `e3c845d`;
decoder commits are `6267b54` and `6a182bf`, and ownership RED is `b496c04`.
The final scoped autorelease-pool fix and tests are committed with this entry.
For precise tested contents, SHA-256 over each UTF-8 path + NUL + file bytes,
in the following order, is
`b79d6c791a11dae2185bbca847ce760f0078479b08e840711b7c333fca43ab73`:
`Tennis Trainer/AnalysisFrame.swift`,
`Tennis Trainer/Detectors/GridTrackNetDetector.swift`,
`Tennis Trainer/Detectors/GridTrackNetDecoder.swift`,
`Tennis TrainerTests/GridTrackNetDecoderTests.swift`,
`Tennis TrainerTests/AnalysisAssociationTests.swift`,
`Tennis TrainerTests/BallDetectionManagerTests.swift`.
All three model file checksums above were rechecked and are unchanged.

Commands (logs and result bundles remain local under `/private/tmp`):

```sh
xcodebuild test -scheme 'Tennis Trainer' -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' '-only-testing:Tennis TrainerTests/GridTrackNetDecoderTests' -resultBundlePath /private/tmp/tennis-01-03-task1-final.xcresult
xcodebuild test -scheme 'Tennis Trainer' -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' '-only-testing:Tennis TrainerTests' -resultBundlePath /private/tmp/tennis-01-03-final-regression.xcresult
xcrun xcresulttool get test-results summary --path /private/tmp/tennis-01-03-final-regression.xcresult --format json
xcrun xcresulttool get test-results tests --path /private/tmp/tennis-01-03-final-regression.xcresult --compact
```

| Run | Executed | Pass | Fail | Skip | Bundle basename |
|---|---:|---:|---:|---:|---|
| Decoder intentional RED | 2 | 0 | 2 | 0 | `tennis-01-03-task1-red` |
| First decoder/model run | 4 | 3 | 1 | 0 | `tennis-01-03-task1-green` |
| Decoder/model corrected contract | 5 | 5 | 0 | 0 | `tennis-01-03-task1-final` |
| Adapter/ownership RED | 4 | 3 | 1 | 0 | `tennis-01-03-task2-characterization` |
| Initial full regression | 64 | 64 | 0 | 0 | `tennis-01-03-full-regression` |
| Final full regression | 65 | 65 | 0 | 0 | `tennis-01-03-final-regression` |

Final class counts: BallDetectionManagerTests 21, AnalysisAssociationTests 10,
GridTrackNetDecoderTests 6, PoseDetectionManagerTests 4,
ServeTossApexDetectorTests 23, existing Swift Testing scaffold 1. The scaffold
does not substitute for any required test. The controlled semaphore stalls emit
one Thread Performance Checker priority warning in the manager tests; there are
no failed or skipped tests. This is not a production timing measurement.

### Actual bundled model and decoder contract

The separate real-model smoke **passed**, loading the bundle and predicting from
five owned uniform frames. Inputs are `f1`…`f5`, 768×432 images. Every output
(`conf`, `x_off`, `y_off`) returned FP16 (raw dtype 65552), shape
`[1, 5, 48, 27]`, and strides `[7680, 1536, 32, 1]`. The first smoke failed only
because its assertion expected the older three-axis reference shape; the allowed
leading singleton form was already supported by the implementation. No asset or
numeric threshold changed. Uniform-frame output establishes interface/runtime
compatibility, not tennis-ball detection quality.

The pure decoder validates each head's dtype, exact semantic dimensions, positive
nonoverlapping strides, checked offset arithmetic and scoped accessible byte span.
It accepts `[5,48,27]` / `[5,27,48]` and their leading singleton forms; each head
may use its own valid layout. It rejects unsupported types, malformed ranks or
dimensions, disagreement, zero/negative/overflowing/overlapping/out-of-storage
strides, and any nonfinite tensor value. Valid confidence below 0.5 keeps real
metadata with a missing position. Row-then-column first argmax tie behavior,
threshold equality, all five times, padding/out-of-source rejection, bottom-left
conversion and portrait-fit/nonportrait-fill geometry have strict fixtures.
Nonuniform pixel quadrants verify actual `.up`, `.right`, `.left`, `.down`
preparation; these tests do not establish displayed overlay alignment.

### Final ownership ledger

Scope: app pipeline buffers retained for admitted work. A caller's rejected
offer is not adopted or queued. Capture/player source pools and framework-private
Core Image/Core ML allocations are outside this object ledger; process-memory
and sustained-device measurements remain pending.

| Owner/state | One manager | Two retained managers |
|---|---:|---:|
| Active lease / worker, including held publication | 1 | 2 |
| Pending input | 0 | 0 |
| Prepared ring | 5 | 10 |
| Immutable prediction snapshot | shares the same 5 | shares the same 10 |
| Admitted raw input | 1 | 2 |
| Oriented intermediate during preparation | 1 | 2 |
| New prepared buffer before ring insertion/eviction | 1 | 2 |
| **Peak distinct app-visible buffers** | **8** | **16** |
| Distinct buffers during prediction | 6 | 12 |
| Distinct buffers while publication is held | 5 | 10 |
| Publication payload | 1, values only | 2, values only |
| Pixel buffers / tensors owned by publication | 0 / 0 | 0 / 0 |
| Retained cue entries | 3 | 6 |
| Production trace history | 0 | 0 |

Five model feature values reference the same prepared pixels; the snapshot adds
no unique buffers. Scoped preparation drains temporary Core Image owners before
prediction; scoped prediction drains model input/output temporaries before
returning detached samples. The decoder holds three fixed 6,480-element Float
arrays transiently (77,760 scalar bytes), never in publication. No optional
production trace was added; diagnostics retain scalar counters only.

The ownership fixture observes distinct CVPixelBuffer identities through weak
references, plus `CVPixelBufferCreateWithBytes` destruction callbacks for raw
storage. Two simultaneous preparation stalls reach exactly 8 each / 16 total;
prediction stalls reach exactly 6 each / 12 total. One thousand additional
offers per manager at preparation, prediction, and publication stalls are
rejected without growing pending input, workers, publication or retained pixels.
Reset during prediction clears prepared storage on worker completion; reset at
publication invalidates effects immediately and leaves at most the five idle
ring pixels until next worker reset or teardown. Raw release callbacks all fire;
owner teardown releases remaining ring pixels. The initial prediction observation
was 14 total because two oriented images survived through autoreleases. The
scoped pool fix makes the original 12/16 assertions pass; the cap was not loosened.

Terminal cases exercise real preparation/decoder/cue and injected boundaries for
warmup, missing model, missing/failed pose, orientation/resize allocation failure,
prediction error, malformed tensors, pre-worker invalidation, reset inside
prediction, publication discard and teardown before worker/publication. Lease
release counts match every accepted job exactly once. Separate tests prove old
duplicate completions cannot free a new lease and publication retains no tensors.

### Callback/requirement evidence and handoff

Both real source adapters (`submitSampleBuffer` and the returned-time playback
output reader) feed nine acquired frames through real orientation/resize, owned
windows, synthetic raw tensors, strict decoding, associated pose and apex logic.
Each emits **one** forwarded callback for candidate sequence 3. All five identities,
source times, orientations, mappings and pose identities/baselines are asserted
in every window. The fixtures admit rational source times 10033…10297/1000,
with 33/1000-second gaps; these are controlled inputs, not measured live cadence.
An equivalent rational-time replay is rejected. Broader suites cover replay
after history eviction, overlaps, contradictory/mismatched pose, missing and
low-confidence candidates, invalid times, source/generation mismatch, checked
counter exhaustion, 1.5-second horizon and exact 3,999/4,000/4,001ms cooldown.

| Requirement | Deterministic evidence |
|---|---|
| CUE-01 | Real adapters + original five-record window + FP16/geometry fixtures |
| CUE-02 | Held preparation/prediction/publication, distinct-buffer/deallocation and lease tests |
| CUE-03 | One complete-path callback, rational replay/overlap/pruning and exact cooldown tests |
| CUE-04 | Candidate-own pose, contradictory later pose, all identity mismatches and strict fallback |

ContentView's two automatic `onApex` closures still call `AudioManager.playBeep`;
the manual Test Beep button remains separate. No physical audio ran in tests.
The first **consumed** estimate for each identity remains authoritative, including
missing and low-confidence estimates; later overlapping estimates cannot revise it.

A1 (real-toss sampling sufficiency) remains empirically unverified. A2 (eight
app-visible buffers) is proven for this implementation/test scope, with private
framework/process memory explicitly excluded. A3 (compact cue history) has the
preserved algorithm and adversarial deterministic characterization; representative
clip outcomes remain unscored. EDGE-CUE-01 and EDGE-CUE-04 remain the supplied
edge report's **unclassified/unresolved** items despite manual contract coverage.
The descriptor-less transparency prohibition remains flagged-unverified: synthetic
cue counts, bounded queues, and callback times must not be presented as measured
real-toss accuracy or physical sound latency.

Repository media inventory again contains no `.mov`, `.mp4`, or `.m4v` fixture;
external permission, physical iPhone and audio timing setup remain unestablished.
No baseline comparison was possible, and no criteria were retroactively tuned.
Phase 2 owns complete control transitions; Phase 3 owns displayed alignment;
Phase 4 owns permitted/labeled corpus acquisition, frozen numeric empirical
criteria, sustained device/memory testing and physical audio timing. Those missing
checks remain required evidence, not passes.

## Phase 01 human review — 2026-09-26

The user passed all three reviews in `.planning/phases/01-consistent-toss-cues/01-UAT.md`: evidence limits, original-five-frame association, and exact source/session/frame pose with the strict missing-pose fallback above 0.70. This explicitly resolves the earlier transparency-review flag and the two undefined edge items against their tested contracts. It does not claim that an unspecified probe ran, or establish any new clip, device, process-memory or physical-audio measurement. All Phase 4 evidence obligations above remain pending.
