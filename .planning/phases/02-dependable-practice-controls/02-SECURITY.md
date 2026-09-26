---
phase: "02"
slug: dependable-practice-controls
status: verified
threats_open: 0
asvs_level: 1
created: "2026-09-26"
---

# Phase 2 — Security

Scoped verification of the 16 threats authored in the four Phase 2 plans. This is an ASVS Level 1 mitigation review of the on-device boundaries, not a compliance certification or physical-device validation. No risks were silently accepted.

## Trust Boundaries

| Boundary | Data and control crossing |
|---|---|
| User intent → queued capture/playback work | Start/Stop/Play/Pause and current context |
| OS authorization/session → app state | Permission, actual running/interruption/failure state |
| Capture/player frames → scheduler/publication | Local pixels, source identity, pose and cue callbacks |
| Slider/framework events → current timeline | Seek targets and delayed readiness/end/error/time events |
| Picker representation → owned copy → consumers | Temporary local media and deletion authority |
| DEBUG scenarios → release binary | Injected test effects versus production construction |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation evidence | Status |
|---|---|---|---|---|---|---|
| T-02-01 | Tampering | Capture admission | high | mitigate | BallDetectionManager compares expected generation under the admission lock; CameraManager stops/detaches/drains before reopening. PracticeLifecycleTests hold both acquired and queued old buffers. | closed |
| T-02-02 | Tampering | Pose/ball/cue publication | high | mitigate | Immediate generation invalidation retains the active lease; publication rechecks generation after observable callbacks. ContentView has separate pose presenters and directly observed ball overlays; held-stage and mode-crossing tests pass. | closed |
| T-02-03 | Denial of service | Repeated controls | medium | mitigate | The analysis manager admits one lease and coalesces resets. VideoPlayerManager guards loopActive and retires each registration. Burst tests and 100 replacement cycles assert bounded owners. | closed |
| T-02-04 | Information disclosure | Inactive media context | medium | mitigate | ContentView closes both contexts on scene/mode exit; camera Stop and playback Pause close admission before framework teardown. Processing remains local. | closed |
| T-02-05 | Elevation of privilege | Camera authorization | high | mitigate | CameraManager queries current authorization before configuration and reopening; request identity is separate from capture intent. Late-grant, revoke and Settings-return fixtures cannot revive retired intent. | closed |
| T-02-06 | Tampering | Capture state/events | high | mitigate | A production-only immutable backend establishes one session/output identity before publication. Operation-owned observations reconcile current backend state after dispatch. Startup checks again before opening ingress; stale successful startup is stopped. Stop/start/recovery interleavings are tested. | closed |
| T-02-07 | Denial of service | Capture recovery/observers | medium | mitigate | Configuration is idempotent, partial setup rolls back, observers are removed, and automatic recovery is limited to one attempt per explicit Start. Failure exposes Retry. | closed |
| T-02-08 | Information disclosure | UI injection | medium | mitigate | Explicit fake scenarios and scenario-only controls are guarded by DEBUG. Injection precedes camera/model/audio construction. Release retains production defaults and no raw media/pose logs are added. | closed |
| T-02-09 | Tampering | Seek/end/Replay | high | mitigate | Immutable load/seek/timeline identities are checked after state dispatch. Native events trigger fresh stopped-at-end/failed reconciliation. Held same-item events and positive current playback/cue controls are tested. | closed |
| T-02-10 | Denial of service | Seek bounds/display links | medium | mitigate | Metadata requires finite positive duration; seek and backend positions are finite/numeric and clamped. loopActive and weak DisplayTarget prevent duplicate extraction loops; repetition tests track high-water counts. | closed |
| T-02-11 | Tampering | Old timeline effects | high | mitigate | Seek, Pause and end close playback and reset analysis before asynchronous effects. Lifecycle tests hold both inference and publication and require fresh post-reset evidence before a new cue. | closed |
| T-02-12 | Tampering | Import path/deletion | high | mitigate | VideoImportManager generates UUID destinations inside PracticeImports with allowlisted extensions. Only successful owned copies carry a deletion owner; collision errors preserve pre-existing paths. Tests preserve external and unknown legacy files. | closed |
| T-02-13 | Tampering | Candidate commit | high | mitigate | VideoPlayerManager requires current candidate/request identity, playable video, finite positive duration and readiness. Every metadata suspension/state hop is guarded; readiness is re-read before commit. Stale failure/success permutations preserve the committed session. | closed |
| T-02-14 | Denial of service | Playback resource retirement | high | mitigate | PlaybackSession pairs observer with its original player and output with its item, detaches layer/item and releases media. Candidate/status/event/tick owners retire explicitly; manager callbacks are weak. 100 cycles and generated AV movie teardown are tested. | closed |
| T-02-15 | Information disclosure | Temporary media | medium | mitigate | OwnedCopy removes only its own path on last release; failed partial copies are removed, stale outcomes release their handles, and consumers lease media through completion. No networking or media/path/pose payload logging is introduced. | closed |
| T-02-16 | Tampering | Cancellation/original files | high | mitigate | Provider copy occurs synchronously inside its representation callback. Cancellation retires intent while metadata, seek, time/event callbacks and frame reads retain leases until actual completion. External handles have no deletion owner; original/legacy preservation and delayed-consumer tests cover this boundary. | closed |

## Accepted Risks Log

No accepted risks. All 16 planned mitigations are present; no open threats remain at or below the configured high blocking threshold.

## Audit Trail

| Date | Total | Closed | Open | Method |
|---|---:|---:|---:|---|
| 2026-09-26 | 16 | 16 | 0 | Parent source/behavior-evidence review against all plan registers and summary threat flags |

The register was authored at planning time. With all threats closed and ASVS level 1 configured, the secure-phase workflow short-circuit applies; no additional security auditor was dispatched. Independent code review additionally found and fixed concurrent lazy capture initialization (d1af3ea) and a retired seek remaining visible after replacement failure (792d728). Those fixes preserve the planned authorization/identity/ownership controls; focused camera/player regressions passed 51/51. Final reviewer disposition is recorded in REVIEW.md.

## Evidence Limits

The relevant source is CameraManager, BallDetectionManager, VideoPlayerManager, VideoImportManager, VideoPickerView, ContentView and AppRuntime, with CameraManagerTests, PracticeLifecycleTests, VideoPlayerManagerTests and VideoImportManagerTests. The phase validation ledger and VERIFICATION report contain final command/result provenance.

Injected permission/session tests do not establish physical authorization recovery or actual camera delivery. Generated-media AV integration is not representative tennis accuracy, sustained device/process-memory or audible-onset evidence. The six undefined edge dispositions and evidence-limit review remain human obligations; this mitigation report does not resolve them.

## Sign-Off

- [x] All threats have a mitigation disposition.
- [x] Accepted risks log is explicit.
- [x] Zero open threats confirmed for the planned L1 scope.
- [x] Status is verified for that scope.

Approval: verified 2026-09-26 for planned software mitigations; phase acceptance remains pending human verification.
