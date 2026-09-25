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
