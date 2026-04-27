# LEARNINGS

## 2026-04-27

- Signpost: Treat `SERVE_PIVOT_IMPL.md` at the repo root as the active handoff brief before changing serve-related code.
- Repo reality: Product docs (`README.md`, `PRD.MD`) describe a serve toss-apex beep, but live Swift code still wires the older `ForearmHorizontalDetector` cue in `CameraManager`, `VideoPlayerManager`, and `ContentView`.
- Detection seam: `BallDetectionManager` already emits 5-sample GridTrackNet tracks through `onBallTrack`, which is the intended integration point for a future serve apex detector.
- Testing gap: Unit tests are effectively empty (`Tennis_TrainerTests.swift` is a placeholder); UI tests are default launch scaffolds.
- Workspace note: The repo currently has pre-existing `.DS_Store` changes (`.DS_Store`, `Tennis Trainer/.DS_Store`). Do not treat them as task-related changes.
- Organization principle: keep `AGENTS.md` short and navigational; put durable repository knowledge in a lightweight `docs/` map plus focused source-of-truth files such as `ARCHITECTURE.md`.
- Signpost: when the user says `.DS_Store` must not be pushed, update `.gitignore` and remove any tracked `.DS_Store` from the git index with `git rm --cached` rather than leaving it staged as a normal modification.
