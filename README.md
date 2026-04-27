# Tennis Trainer

Tennis Trainer is an iPhone app that gives real-time audio cues while you practice, so you can groove a motion without watching a screen.

It currently focuses on the **serve**, and beeps at the **apex of your toss** — the moment the ball reaches its peak before you swing. Matching each toss to the same beep moment is one of the simplest ways to build a consistent toss, which is the single biggest serve fundamental.

What it does today:
- Tracks the tennis ball and your body in real time, on-device.
- Detects the apex of each toss and plays a short beep at that instant.
- Works with the live camera or a saved video (so you can test it against pro serves you've downloaded).

Why it's useful:
- Fast, audio-only feedback during solo practice — no wearables, no internet, no looking at the phone mid-rep.
- On-device processing for privacy and low latency.

What's next:
- **Trophy position** cue (peak of the load before you uncoil into the ball).
- More serve cues, then expand to other strokes.

Current scope:
- Solo serve practice. Right-handed only for now.
- Recommended camera placement: side-on, toss-arm side. Behind-the-player still works for the toss apex but won't carry forward to richer cues.

Status: work in progress. The active beep cue in the codebase is being pivoted from a forehand contact heuristic to the serve toss apex described above; see `PRD.MD` for the spec and `SERVE_PIVOT_IMPL.md` for the in-flight engineering work.
