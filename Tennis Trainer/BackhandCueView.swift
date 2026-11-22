import SwiftUI
import Vision

struct BackhandCueView: View {
  @ObservedObject var manager: BackhandCueManager
  let isLive: Bool
  let isRunning: Bool
  let canCaptureVideo: Bool
  var readVideoPose: () async throws -> PoseDetectionManager.FrameObservation
  var cancelAudio: () -> Void
  @State private var captureTask: Task<Void, Never>?
  @State private var countdown: Int?
  @State private var readingFrame = false
  @State private var captureID = UUID()

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("Drive through").font(.headline)
          Text("Experimental · right-handed").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Toggle("Sound", isOn: $manager.soundEnabled).fixedSize()
          .accessibilityIdentifier("backhand.sound")
      }

      HStack {
        Text(manager.status.rawValue).font(.subheadline.bold())
          .foregroundStyle(manager.status == .reached ? .green : .primary)
          .accessibilityIdentifier("backhand.status")
        Spacer()
        Text("\(manager.cueCount) cues").monospacedDigit()
          .accessibilityIdentifier("backhand.count")
      }

      if let countdown {
        Text("Hold the selected pose · capturing in \(countdown)")
          .font(.headline).monospacedDigit()
      } else if readingFrame {
        ProgressView("Reading this frame…")
      }

      HStack {
        Button(manager.readyReference == nil ? "1. Set ready" : "1. Ready saved ✓") {
          capture(.ready)
        }
        .accessibilityIdentifier("backhand.ready")
        Button(manager.calibration == nil ? "2. Set checkpoint" : "2. Checkpoint saved ✓") {
          capture(.checkpoint)
        }
        .disabled(manager.readyReference == nil)
        .accessibilityIdentifier("backhand.checkpoint")
      }
      .buttonStyle(.bordered)
      .font(.subheadline)
      .disabled(captureTask != nil || (isLive ? !isRunning : !canCaptureVideo))

      BackhandDiagramView(current: manager.currentSample, ready: manager.readyReference,
                          calibration: manager.calibration)
        .frame(height: 100)
        .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
      Text("Blue: top arm · orange: bottom arm · purple: your checkpoint")
        .font(.caption2).foregroundStyle(.secondary)

      if let message = manager.message {
        Text(message).font(.caption).foregroundStyle(.secondary)
      }
      Text("The beep marks your movement checkpoint, not a good hit. Compare a few feeds with Sound off.")
        .font(.caption).foregroundStyle(.secondary)
      DisclosureGroup("Setup help") {
        Text(isLive
          ? "Start the camera. Use a fixed side-oblique view with one player and both arms visible. Each setup button gives you 5 seconds to pose."
          : "Pause on your ready position and set it. Then pause just through the strike to set your checkpoint. Rewind and play from ready to test.")
          .font(.caption).foregroundStyle(.secondary)
      }.font(.subheadline)
      if manager.readyReference != nil || captureTask != nil {
        Button("Recalibrate") {
          cancelCapture()
          cancelAudio()
          manager.clearCalibration()
        }.accessibilityIdentifier("backhand.recalibrate")
      }
    }
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal)
    .padding(.bottom)
    .onChange(of: manager.soundEnabled) { _, enabled in if !enabled { cancelAudio() } }
    .onChange(of: isRunning) { _, _ in cancelCapture() }
    .onChange(of: canCaptureVideo) { _, _ in if !isLive { cancelCapture() } }
    .onDisappear { cancelCapture() }
  }

  private func capture(_ reference: BackhandCueManager.Reference) {
    cancelAudio()
    manager.resetAttempt()
    manager.isCalibrating = true
    let id = UUID()
    captureID = id
    captureTask = Task { @MainActor in
      defer {
        if captureID == id {
          countdown = nil; readingFrame = false; captureTask = nil
          manager.isCalibrating = false
        }
      }
      do {
        if isLive {
          for remaining in (1...5).reversed() {
            countdown = remaining
            try await Task.sleep(for: .seconds(1))
          }
          try Task.checkCancellation()
          manager.captureLiveReference(reference)
        } else {
          readingFrame = true
          let pose = try await readVideoPose()
          try Task.checkCancellation()
          manager.capture(reference, from: pose)
        }
      } catch is CancellationError {
        // Source/mode changes retire the setup operation silently.
      } catch {
        if captureID == id { manager.setMessage(error.localizedDescription) }
      }
    }
  }

  private func cancelCapture() {
    captureTask?.cancel()
    captureID = UUID()
    captureTask = nil
    countdown = nil
    readingFrame = false
    manager.isCalibrating = false
  }
}

private struct BackhandDiagramView: View {
  let current: BackhandCueManager.Sample?
  let ready: BackhandCueManager.Sample?
  let calibration: BackhandCueManager.Calibration?

  var body: some View {
    Canvas { context, size in
      let samples = [ready, calibration?.checkpoint, current].compactMap { $0 }
      let points = samples.flatMap { Array($0.points.values) }
      guard !points.isEmpty else {
        context.draw(Text("Your arm tracking will appear here").font(.caption).foregroundColor(.secondary),
                     at: CGPoint(x: size.width / 2, y: size.height / 2))
        return
      }
      let minX = (points.map(\.x).min() ?? 0) - 0.05
      let maxX = (points.map(\.x).max() ?? 1) + 0.05
      let minY = (points.map(\.y).min() ?? 0) - 0.05
      let maxY = (points.map(\.y).max() ?? 1) + 0.05
      let scale = min(size.width / (maxX - minX), size.height / (maxY - minY))
      func map(_ point: CGPoint) -> CGPoint {
        CGPoint(x: size.width / 2 + (point.x - (minX + maxX) / 2) * scale,
                y: size.height / 2 - (point.y - (minY + maxY) / 2) * scale)
      }
      func draw(_ sample: BackhandCueManager.Sample, color: Color?, opacity: Double) {
        let arms: [[VNHumanBodyPoseObservation.JointName]] = [
          [.leftShoulder, .leftElbow, .leftWrist], [.rightShoulder, .rightElbow, .rightWrist]
        ]
        for arm in arms {
          let vertices = arm.compactMap { sample.points[$0].map(map) }
          var path = Path()
          path.addLines(vertices)
          let tint = color ?? (arm.first == .leftShoulder ? .blue : .orange)
          context.stroke(path, with: .color(tint.opacity(opacity)), lineWidth: 3)
          for point in vertices {
            context.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                         with: .color(tint.opacity(opacity)))
          }
        }
      }
      if let ready { draw(ready, color: .gray, opacity: 0.25) }
      if let checkpoint = calibration?.checkpoint { draw(checkpoint, color: .purple, opacity: 0.4) }
      if let calibration {
        let center = map(calibration.checkpoint.hand)
        context.stroke(Path(ellipseIn: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16)),
                       with: .color(.purple), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
      }
      if let current { draw(current, color: nil, opacity: 1) }
    }
    .accessibilityLabel("Body-relative arm diagram and calibrated checkpoint")
  }
}
