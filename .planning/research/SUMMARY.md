# Project Research Summary

**Project:** Tennis Trainer — toss-apex reliability
**Domain:** On-device iPhone live-camera and saved-video analysis
**Researched:** 2026-09-24
**Confidence:** MEDIUM — official platform documentation and static source inspection; no runtime validation

## Executive Summary

Keep the existing SwiftUI, AVFoundation, Vision, Core ML, and bundled GridTrackNet stack. This milestone needs stronger timing, ownership, lifecycle, and geometry contracts rather than a new model or framework. The current source exposes concrete paths for mismatched inference metadata, outdated callbacks after reset, stale pose data, and incorrect overlay projection.

Make every accepted frame and five-frame window carry its own source identity, timestamp, geometry, pose value, and session generation. Bound expensive work before enqueueing it, keep prediction away from UI/session-control operations, and reject invalidated results at the final publication/audio boundary. Extend that identity handling to asynchronous clip loads, seeks, notifications, and imported-file ownership. These are design recommendations to validate, not completed fixes.

Use deterministic regression tests for strict invariants, then labeled clips and physical-device trials for detection quality and audible timing. The PRD's frame-interval estimate does not measure capture-to-speaker delay. No representative corpus, device matrix, accuracy target, or audible-latency budget has been established; those remain explicit acceptance work.

## Key Findings

### Recommended Stack

Retain the iOS 18.5 deployment target and Swift 5 language mode. Installed Xcode 27 is distinct from project creation metadata for Xcode 16.4. Newer Apple samples are useful references but may require a later OS; check individual API availability before implementation. See [STACK.md](STACK.md).

- **AVFoundation and PhotosUI:** existing capture, video selection/playback, permissions, item notifications, and audio output.
- **Vision and Core ML:** existing pose and ball models, with serialized model access and explicit immutable input ownership.
- **Dispatch/Foundation and Core Media:** bounded scheduling, source timestamps, generation checks, and media lifecycle ownership.
- **Core Image/Core Video and AV layers:** tested model-to-source transforms and projection into actual displayed image geometry.
- **XCTest and device instrumentation:** existing test target plus targeted fakes, local event traces, and physical audio/video observation.

No package installation, project-format migration, or model conversion is a prerequisite.

### Expected Features

See [FEATURES.md](FEATURES.md). Required behaviors are correctly associated current-toss feedback; no new stale automatic cue after invalidation; no duplicate cue from overlapping frames; aligned ball/pose overlays; actionable permissions; truthful capture state; reliable pause/seek/end/replay/replacement; and repeatable verification.

Optional setup reminders, audio-route hints, and polished diagnostic UI are deferred unless evidence justifies a later scope change. Trophy/contact cues, other strokes, handedness expansion, rally detection, cloud features, and planned retraining remain outside this milestone.

### Architecture Approach

See [ARCHITECTURE.md](ARCHITECTURE.md). Preserve existing managers and the `BallDetectionManager` integration boundary:

1. Media managers own source identity, timestamps, authorization/player state, and immediate invalidation.
2. Bounded preparation creates owned frame records with matching pose and geometry; inference consumes a five-record snapshot.
3. A validated decoder returns positions associated with that same snapshot, using each output tensor's strides.
4. A serial publication boundary checks generation and eligibility before pose/ball updates, apex consumption, or automatic audio scheduling.
5. Shared source-to-display geometry projects both pose and ball into the actual layer image rectangle, accounting for fit/fill, orientation, and origin.

Begin with the simplest bounded policy that meets measurements. A serial queue alone does not cap pending requests, and cancellation alone does not prevent an already queued UI callback from taking effect. An already audible beep is distinct from a newly scheduled stale beep.

### Critical Pitfalls

See [PITFALLS.md](PITFALLS.md).

1. **Prediction metadata can drift:** snapshot pixels, time, geometry, and identity together; never substitute host uptime for missing media timestamps.
2. **Reset can leave future effects queued:** invalidate immediately and check identity inside final publication, including load/seek completions and audio scheduling.
3. **Display cadence is not frame cadence:** acquire distinct player output frames, preserve returned media times, handle repeated timestamps/gaps explicitly, and keep performance clocks separate.
4. **Confident pose can still be stale:** pair pose to the candidate's source frame or apply a declared fallback; clear missing observations.
5. **Correct source coordinates can still render incorrectly:** separate model preprocessing from source-to-display projection. Older blanket aspect-fill guidance conflicts with current portrait-fit code and approved scope; resolve deliberately with fixtures.
6. **Callback timing is not physical audio timing:** measure software stages and audible onset separately, with audio route and measurement uncertainty recorded.

## Implications for Roadmap

The following are proposed groupings, not an approved roadmap or chosen project structure mode.

### Trustworthy current-toss feedback

Establish source/window identity, bounded processing, paired pose, decoder validation, and generation-safe publication across both modes. Add deterministic burst/interleaving tests and define local evidence instrumentation. Begin fixture acquisition and the baseline protocol early, before final tuning or scoring.

### Dependable capture and clip controls

Apply the shared identity/reset contract to camera authorization, startup/interruption/recovery, pause/seek, end/replay, clip replacement, and resource cleanup. Adversarial tests should release old completions after a new source is active. This grouping depends on the generation contract; permission UI and clip controls can otherwise be separate plans.

### Correct visible tracking

Unify ball/pose display transforms using source geometry and the actual rendered image region. Verify corners, center, rotation, padding, cropping, and real AV-layer layout. This depends on trustworthy frame geometry, but can proceed alongside lifecycle work once that contract is fixed.

### Evidence-based reliability acceptance

Run the frozen clip protocol and sustained live-device trials after fixes, reporting misses, extra/duplicate/stale cues, geometry errors, and actual audio timing. Set measurable bounds before final scoring; do not retroactively move them to pass. Earlier phases should supply regression evidence and baseline data rather than postponing all testing here.

### Research Flags

- **Focused phase research:** frame admission versus five-frame sampling cadence; precise camera preview coordinate adaptation; timestamp/pose freshness limits; physical apex-to-audio measurement method.
- **Established platform patterns:** state-specific authorization, current-item completion notification, observer ownership, generation-checked load/seek completion, and owned temporary-file cleanup. Verify overload availability during implementation without repeating the full ecosystem survey.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Official Apple API contracts support the existing stack; deployment availability still needs implementation checks |
| Features | MEDIUM | Derived from approved scope and observed code gaps, not user studies |
| Architecture | MEDIUM | Recommendations address identified boundaries; concurrency and geometry require regression/device validation |
| Pitfalls | MEDIUM | Source-grounded failure mechanisms; actual frequency and severity unmeasured |

### Gaps to Address

- Acquire permitted representative clips, label apex intervals and cooldown eligibility, and reserve confirmation cases where possible.
- Identify actual devices, OS/build configuration, audio routes, and sustained-session conditions.
- Establish cue accuracy, geometry tolerance, sampling-gap/freshness, and audible-latency criteria from baseline evidence before final verification.
- Record missing device or physical-audio evidence as pending; passing synthetic tests cannot close those acceptance gates.

## Sources

Primary Apple sources checked by the four researchers; project-specific designs above are inferences. Detailed references and source associations are retained in each research document.

- [Capture queue responsibility](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput/setsamplebufferdelegate(_:queue:)) and [TN2445](https://developer.apple.com/library/archive/technotes/tn2445/_index.html): capture backlog and buffer retention.
- [Core ML prediction guidance, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10049/): synchronous serialization, asynchronous prediction, cancellation and memory tradeoffs.
- [AVPlayerItemVideoOutput](https://developer.apple.com/documentation/avfoundation/avplayeritemvideooutput): distinct frame acquisition and display times.
- [Seek completion](https://developer.apple.com/documentation/avfoundation/avplayer/seek(to:tolerancebefore:toleranceafter:completionhandler:)) and [item completion](https://developer.apple.com/documentation/avfoundation/avplayeritem/didplaytoendtimenotification): playback lifecycle.
- [AVPlayerLayer.videoRect](https://developer.apple.com/documentation/avfoundation/avplayerlayer/videorect) and [preview coordinate conversion](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer/capturedevicepointconverted(fromlayerpoint:)): rendered-image geometry.
- [Capture authorization](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media): permission behavior.
- [AVAudioPlayerNode](https://developer.apple.com/documentation/avfaudio/avaudioplayernode) and [device execution](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices): audio scheduling and hardware validation boundaries.

---
*Research completed: 2026-09-24*
*Ready for requirements and roadmap definition: yes; empirical acceptance remains unverified*
