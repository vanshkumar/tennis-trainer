import SwiftUI

/// An in-app quick start for the current two-reference experiment.
struct BackhandGuideView: View {
  let isLive: Bool
  @Environment(\.dismiss) private var dismiss
  @State private var step = 0
  private let steps = ["Camera", "Two poses", "Swing", "Compare"]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text(isLive ? "LIVE CAMERA · QUICK START" : "SAVED VIDEO · QUICK START")
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
          HStack(spacing: 8) {
            ForEach(steps.indices, id: \.self) { index in
              Button { step = index } label: {
                VStack(spacing: 5) {
                  Text("\(index + 1)")
                    .font(.headline).frame(width: 32, height: 32)
                    .background(step == index ? Color.accentColor : Color.secondary.opacity(0.12), in: Circle())
                    .foregroundStyle(step == index ? .white : .primary)
                  Text(steps[index]).font(.caption)
                }.frame(maxWidth: .infinity)
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Step \(index + 1): \(steps[index])")
              .accessibilityAddTraits(step == index ? .isSelected : [])
              .accessibilityIdentifier("backhand.guide.step.\(index)")
            }
          }
          Group {
            switch step {
            case 0: cameraStep
            case 1: calibrationStep
            case 2: swingStep
            default: comparisonStep
            }
          }
          Text("Right-handed two-handed backhand · controlled feeds")
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
      }
      .id(step)
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Backhand visual guide")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Close") { dismiss() }.accessibilityIdentifier("backhand.guide.close")
        }
      }
      .safeAreaInset(edge: .bottom) {
        HStack {
          if step > 0 {
            Button("Back") { step -= 1 }.buttonStyle(.bordered)
          }
          Spacer()
          Button(step == 3 ? "Start setup" : "Next") {
            if step == 3 { dismiss() } else { step += 1 }
          }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("backhand.guide.next")
        }
        .padding().background(.regularMaterial)
      }
    }
  }

  private var cameraStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      title("Give the camera a clear view", detail: "One player. Both shoulders, elbows and hands in frame.")
      BackhandCameraDiagramView().frame(height: 210).card()
      instruction("iphone", "Fixed phone, portrait", isLive
        ? "Use a stable support to the side and slightly in front of you. Leave room for the whole swing."
        : "Choose a fixed-camera clip from a side-oblique view, with the whole swing visible.")
      instruction(isLive ? "play.fill" : "photo.on.rectangle", isLive ? "Start + check tracking" : "Choose + pause", isLive
        ? "Tap Start. Try a slow shadow swing; both colored arms should stay visible in the tracking diagram."
        : "Choose a video, then pause before the backswing. Use the slider and ±0.03s buttons to find a frame.")
      note("If one arm hides the other, shift the camera angle. Recalibrate after moving the phone or changing your position.")
    }
  }

  private var calibrationStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      title("Save two poses from your swing", detail: "Use a comfortable drive through the ball toward your target.")
      HStack(alignment: .top, spacing: 10) {
        poseCard(.ready, title: "1 · Ready", detail: "Hands together, before taking them back.")
        poseCard(.checkpoint, title: "2 · Checkpoint", detail: "Hands farther through, early in the follow-through.")
      }
      Text("Blue = left / top arm   ·   Orange = right / bottom arm")
        .font(.caption).foregroundStyle(.secondary)
      instruction(isLive ? "timer" : "pause.fill", isLive ? "Tap, then hold for 5 seconds" : "Save each paused frame", isLive
        ? "Tap Set ready, step into place and hold pose 1. Once saved, tap Set checkpoint and hold pose 2."
        : "Pause at pose 1 and tap Set ready. Find pose 2 in the same clip and tap Set checkpoint.")
      note("The drawings show the idea. Use your own arm shape; a bent top elbow is fine. Keep both hands on the racket and avoid forcing a straight arm.")
      Text("Live and video have separate setups. A new clip or reopening the app needs setup again.")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  private var swingStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      title("Ready → back → through", detail: "Start with a few easy shadow swings, then predictable feeds.")
      VStack(spacing: 8) {
        HStack(spacing: 0) {
          sequencePose(.ready, "Ready")
          Image(systemName: "arrow.right").foregroundStyle(.secondary)
          sequencePose(.backswing, "Take back")
          Image(systemName: "arrow.right").foregroundStyle(.secondary)
          sequencePose(.checkpoint, "Through")
        }
        Label("BEEP · checkpoint reached", systemImage: "speaker.wave.2.fill")
          .font(.subheadline.bold()).foregroundStyle(.purple)
      }.padding(12).card()
      instruction("arrow.counterclockwise", "Reset each swing", isLive
        ? "Return to your saved ready pose until the status says Ready. Take the hands back, then swing through your checkpoint."
        : "Rewind before your saved ready pose and press Play. The clip needs ready, a backswing and the forward swing in order.")
      note("The beep means your tracked hands and top arm reached your saved checkpoint. It follows the movement; keep swinging naturally. It does not detect impact or score the hit.")
      DisclosureGroup("No cue, or an unexpected cue?") {
        VStack(alignment: .leading, spacing: 10) {
          Text("Tracking lost → show all six arm joints, keep hands together, improve lighting or try another camera angle.")
          Text("Return to ready → briefly settle at the saved ready pose before taking the hands back.")
          Text("Still no cue → choose a clearer checkpoint farther through the swing and recalibrate.")
          Text("Cue count rises but no sound → turn Sound on, raise media volume and check the audio output. Live Camera has Test Beep.")
          Text("Extra or late beeps → stop, check the view and recalibrate. If they persist, use Sound off and keep the clip for review.")
        }.font(.callout).padding(.top, 8)
      }.font(.subheadline.bold())
    }
  }

  private var comparisonStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      title("Keep the ball target the same", detail: "Try one target zone and one comfortable feed height and pace.")
      VStack(spacing: 14) {
        Image(systemName: "target").font(.system(size: 48)).foregroundStyle(.green)
        Text("Same depth + direction goal").font(.subheadline.bold())
        HStack(spacing: 12) {
          trialBlock("A", icon: "speaker.slash.fill", title: "Sound off", detail: "10 feeds\nAim only at the target")
          Image(systemName: "arrow.left.arrow.right").foregroundStyle(.secondary)
          trialBlock("B", icon: "speaker.wave.2.fill", title: "Sound on", detail: "10 similar feeds\nSame target")
        }
      }.padding(16).card()
      instruction("checkmark.circle", "Count useful shots", "Count balls reaching your target zone in each block. Repeat in the opposite order. Keep the cue only if your shots improve without added strain or distraction.")
      note(isLive
        ? "Cue count is a movement count, not a score. Sound off still counts checkpoints; focus only on the ball target in the silent block."
        : "Replay the same clip with Sound off and on to check where cues happen. Test coaching value later on court with the two feed blocks above.")
      Text("Early experiment: tracking accuracy and sound delay still need real-device testing. Keep a short clip of misses or extra cues to guide the next iteration.")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  private func title(_ text: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(text).font(.title2.bold()).accessibilityAddTraits(.isHeader)
      Text(detail).font(.callout).foregroundStyle(.secondary)
    }
  }

  private func instruction(_ icon: String, _ title: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon).font(.title3).foregroundStyle(.blue).frame(width: 26)
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.headline)
        Text(detail).font(.callout).foregroundStyle(.secondary)
      }
    }
  }

  private func note(_ text: String) -> some View {
    Text(text).font(.callout).padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
  }

  private func poseCard(_ pose: BackhandPoseIllustration.Phase, title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      BackhandPoseIllustration(phase: pose).frame(height: 140)
      Text(title).font(.headline)
      Text(detail).font(.caption).foregroundStyle(.secondary)
    }.padding(10).frame(maxWidth: .infinity, alignment: .topLeading).card()
  }

  private func sequencePose(_ pose: BackhandPoseIllustration.Phase, _ title: String) -> some View {
    VStack {
      BackhandPoseIllustration(phase: pose).frame(height: 100)
      Text(title).font(.caption.bold())
    }.frame(maxWidth: .infinity)
  }

  private func trialBlock(_ letter: String, icon: String, title: String, detail: String) -> some View {
    VStack(spacing: 6) {
      Text(letter).font(.caption.bold()).foregroundStyle(.secondary)
      Image(systemName: icon).font(.title2).foregroundStyle(.blue)
      Text(title).font(.subheadline.bold())
      Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }.frame(maxWidth: .infinity)
  }
}

private extension View {
  func card() -> some View {
    background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
  }
}

private struct BackhandCameraDiagramView: View {
  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      ZStack {
        Canvas { context, size in
          let court = CGRect(x: size.width * 0.12, y: 24, width: size.width * 0.58, height: 162)
          context.fill(Path(roundedRect: court, cornerRadius: 4), with: .color(.green.opacity(0.09)))
          context.stroke(Path(court), with: .color(.green.opacity(0.65)), lineWidth: 2)
          var net = Path()
          net.move(to: CGPoint(x: court.minX, y: 66)); net.addLine(to: CGPoint(x: court.maxX, y: 66))
          context.stroke(net, with: .color(.secondary), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
          var view = Path()
          view.move(to: CGPoint(x: size.width * 0.82, y: 118))
          view.addLine(to: CGPoint(x: size.width * 0.31, y: 134))
          view.addLine(to: CGPoint(x: size.width * 0.50, y: 180)); view.closeSubpath()
          context.fill(view, with: .color(.blue.opacity(0.10)))
        }
        Text("TOP VIEW").font(.caption2.bold()).foregroundStyle(.secondary)
          .position(x: width * 0.41, y: 14)
        Text("Net").font(.caption).foregroundStyle(.secondary).position(x: width * 0.41, y: 51)
        Image(systemName: "arrow.up").font(.title2.bold()).foregroundStyle(.green)
          .position(x: width * 0.41, y: 100)
        ZStack {
          Capsule().fill(.primary.opacity(0.35)).frame(width: 38, height: 12).offset(y: 7)
          Circle().fill(.primary).frame(width: 20, height: 20)
        }.position(x: width * 0.41, y: 151)
        Text("You").font(.caption.bold()).position(x: width * 0.41, y: 193)
        Image(systemName: "iphone").font(.system(size: 34)).foregroundStyle(.blue)
          .rotationEffect(.degrees(-25)).position(x: width * 0.83, y: 113)
        Text("Phone").font(.caption.bold()).foregroundStyle(.blue).position(x: width * 0.83, y: 151)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Top-down court diagram. Player faces the net. A portrait phone is on a fixed support to the side and slightly toward the net, angled back at the player.")
  }
}
