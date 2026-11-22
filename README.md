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
- Complete the existing toss-apex reliability roadmap and physical-device checks.
- Try the opt-in backhand prototype below; its coaching value and audible timing are still unvalidated.

## Try the backhand prototype

Select **Backhand** for an experimental **Drive through** movement cue. It works with the live camera and saved videos, using both arms without ball inference.

1. Use one right-handed player and a fixed side-oblique view that shows both shoulders, elbows and hands. Keep the hands together on the racket.
2. In live mode, start capture and tap **Set ready**. You have five seconds to stand in your ready position. Then use **Set checkpoint** to capture a comfortable position just through your swing; the top arm may stay bent. In video mode, pause on each reference frame instead; the small time-step buttons help select it.
3. Return to ready, take the hands back and swing through. A beep means the hands reached the reference corridor with similar top-arm extension. The diagram shows both arms and the selected checkpoint; the cue count also updates with sound off.
4. Compare controlled feeds with **Sound** on and off. Use **Recalibrate** if the camera position, player or intended shot changes. Setup stays in memory for the current camera setup or clip; a new clip needs new calibration.

This first version detects a projected movement, **not impact or shot quality**. A shadow swing can trigger it. Missing arms or large analysis gaps reset the attempt. Phone/audio-route latency and on-court accuracy still need real-device trials. The original serve-reliability milestone remains open.

Current scope:
- Solo serve practice and the experimental backhand drill. Right-handed only for now.
- Portrait orientation only for now, so the full toss is easier to keep in frame.
- Recommended camera placement: side-on, toss-arm side. Behind-the-player still works for the toss apex but won't carry forward to richer cues.

Status: work in progress. Serve toss apex is the default cue; Backhand is an opt-in prototype. See `PRD.MD` for the serve specification and `Tennis Trainer/Archived/Forehand/FOREHAND_ARCHIVE.md` for the parked forehand heuristic.
