//
//  ContentView.swift
//  Tennis Trainer
//
//  Created by Vansh Kumar on 8/20/25.
//

import SwiftUI
import Vision

enum AppMode: String, CaseIterable {
    case liveCamera = "Live Camera"
    case videoPlayback = "Video Playback"
}

enum PracticeDrill: String, CaseIterable {
    case serve = "Serve"
    case backhand = "Backhand"
}

struct ContentView: View {
    @StateObject private var cameraManager = AppRuntime.makeCameraManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var cameraPoseManager = PoseDetectionManager()
    @StateObject private var playbackPoseManager = PoseDetectionManager()
    @StateObject private var videoPlayerManager = AppRuntime.makeVideoPlayerManager()
    @StateObject private var cameraBackhand = BackhandCueManager()
    @StateObject private var playbackBackhand = BackhandCueManager()
    @State private var currentDrill: PracticeDrill = .serve
    @Environment(\.scenePhase) private var scenePhase
    @State private var frameCount = 0
    @State private var lastFrameTime = Date()
    @State private var fps: Double = 0
    
    @State private var currentMode: AppMode = .liveCamera
    @StateObject private var videoImporter = VideoImportManager()
    @State private var importRequest = UUID()
    @State private var showingVideoPicker = false
    @State private var showingBackhandGuide = false
    
    var body: some View {
        VStack {
            Picker("Drill", selection: $currentDrill) {
                ForEach(PracticeDrill.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("practice.drill")
            .padding(.horizontal)
            .onChange(of: currentDrill) { _, _ in handleDrillChange() }
            // Mode picker at the top
            Picker("Mode", selection: $currentMode) {
                ForEach(AppMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .accessibilityIdentifier("practice.mode")
            .padding()
            .onChange(of: currentMode) { _, newMode in
                handleModeChange(to: newMode)
            }
            
            // Content based on current mode
            if currentDrill == .backhand {
                Button {
                    cameraManager.stopCapture()
                    videoPlayerManager.pause()
                    audioManager.cancelPendingBeeps()
                    showingBackhandGuide = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "book.closed").font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Visual setup guide").font(.subheadline.bold())
                            Text("Camera · two poses · first trial").font(.caption)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.bold())
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .accessibilityIdentifier("backhand.guide")
                .accessibilityHint("Pauses practice and opens illustrated setup instructions")
                ScrollView {
                    VStack(spacing: 12) {
                        if currentMode == .liveCamera {
                            liveCameraView.frame(height: 340).clipped()
                        } else {
                            videoPlaybackView
                        }
                        BackhandCueView(manager: currentMode == .liveCamera ? cameraBackhand : playbackBackhand,
                            isLive: currentMode == .liveCamera,
                            isRunning: currentMode == .liveCamera ? cameraManager.isRecording : videoPlayerManager.isPlaying,
                            canCaptureVideo: videoPlayerManager.playbackState == .paused && !videoPlayerManager.isLoading,
                            readVideoPose: { try await videoPlayerManager.captureCalibrationPose() },
                            cancelAudio: { audioManager.cancelPendingBeeps() })
                            .id(currentMode == .liveCamera ? "camera" : videoPlayerManager.sourceID.uuidString)
                    }
                }
            } else {
                ZStack {
                    switch currentMode {
                    case .liveCamera: liveCameraView
                    case .videoPlayback: videoPlaybackView
                    }
                }
            }
        }
        .onAppear {
            cameraManager.poseDetectionManager = cameraPoseManager
            cameraManager.setupBallDetection(with: cameraPoseManager, factory: AppRuntime.overlayFactory)
            videoPlayerManager.poseDetectionManager = playbackPoseManager
            videoPlayerManager.setupBallDetection(with: playbackPoseManager, factory: AppRuntime.overlayFactory)
            cameraManager.ballDetectionManager?.setPoseOnly(currentDrill == .backhand)
            videoPlayerManager.ballDetectionManager?.setPoseOnly(currentDrill == .backhand)
            cameraManager.ballDetectionManager?.onPoseFrame = { observation in
                guard currentDrill == .backhand, currentMode == .liveCamera,
                      cameraManager.isRecording, scenePhase == .active else { return }
                cameraBackhand.consume(observation)
            }
            videoPlayerManager.ballDetectionManager?.onPoseFrame = { observation in
                guard currentDrill == .backhand, currentMode == .videoPlayback,
                      videoPlayerManager.isPlaying, scenePhase == .active else { return }
                playbackBackhand.consume(observation)
            }
            cameraBackhand.onCue = {
                guard currentDrill == .backhand, currentMode == .liveCamera,
                      cameraManager.isRecording, scenePhase == .active else { return }
                audioManager.playBeep()
            }
            playbackBackhand.onCue = {
                guard currentDrill == .backhand, currentMode == .videoPlayback,
                      videoPlayerManager.isPlaying, scenePhase == .active else { return }
                audioManager.playBeep()
            }
            updateActiveContexts()
            
            cameraManager.onFrameProcessed = {
                guard currentMode == .liveCamera, scenePhase == .active else { return }
                frameCount += 1
                
                let now = Date()
                let timeDiff = now.timeIntervalSince(lastFrameTime)
                if timeDiff >= 1.0 {
                    fps = Double(frameCount) / timeDiff
                    frameCount = 0
                    lastFrameTime = now
                }
            }
            
            videoPlayerManager.onFrameProcessed = {
                guard currentMode == .videoPlayback, scenePhase == .active else { return }
                frameCount += 1
                
                let now = Date()
                let timeDiff = now.timeIntervalSince(lastFrameTime)
                if timeDiff >= 1.0 {
                    fps = Double(frameCount) / timeDiff
                    frameCount = 0
                    lastFrameTime = now
                }
            }

            cameraManager.onApex = {
                guard currentDrill == .serve, currentMode == .liveCamera, scenePhase == .active else { return }
                audioManager.playBeep()
            }
            videoPlayerManager.onApex = {
                guard currentDrill == .serve, currentMode == .videoPlayback, scenePhase == .active else { return }
                audioManager.playBeep()
            }
        }
        .onChange(of: scenePhase) { _, _ in updateActiveContexts() }
        .onChange(of: cameraManager.isRecording) { _, active in
            if active { AppRuntime.seedOverlay(cameraManager.ballDetectionManager, pose: cameraPoseManager) }
            else {
                cameraBackhand.resetAttempt()
                if currentMode == .liveCamera { audioManager.cancelPendingBeeps() }
            }
        }
        .onChange(of: videoPlayerManager.isPlaying) { _, active in
            if active { AppRuntime.seedOverlay(videoPlayerManager.ballDetectionManager, pose: playbackPoseManager) }
        }
        .onChange(of: videoPlayerManager.playbackState) { _, state in
            if state != .playing {
                playbackBackhand.resetAttempt()
                if currentMode == .videoPlayback { audioManager.cancelPendingBeeps() }
            }
        }
        .onChange(of: videoPlayerManager.sourceID) { _, _ in playbackBackhand.clearCalibration() }
        .onDisappear {
            audioManager.cancelPendingBeeps()
            cameraManager.setContextActive(false)
            videoImporter.cancel()
            videoPlayerManager.shutdown()
        }
        .sheet(isPresented: $showingBackhandGuide) {
            BackhandGuideView(isLive: currentMode == .liveCamera)
        }
        .sheet(isPresented: $showingVideoPicker, onDismiss: {
            videoImporter.pickerDismissed(request: importRequest)
        }) {
            #if DEBUG
            if AppRuntime.practiceUIScenario?.hasPrefix("playback-import") == true {
                VStack {
                    ForEach(["cancel", "failure", "success"], id: \.self) { result in
                        Button(result) {
                            AppRuntime.deliverImport(videoImporter, request: importRequest, result: result)
                            showingVideoPicker = false
                        }.accessibilityIdentifier("import." + result)
                    }
                }
            } else {
                VideoPickerView(request: importRequest, importer: videoImporter)
            }
            #else
            VideoPickerView(request: importRequest, importer: videoImporter)
            #endif
        }
    }
    
    private var liveCameraView: some View {
        ZStack {
            if cameraManager.hasPermission {
                ZStack {
                    if AppRuntime.practiceUIScenario == nil {
                        CameraPreview(previewLayer: cameraManager.getPreviewLayer())
                            .ignoresSafeArea()
                    } else {
                        Color.black.ignoresSafeArea()
                    }
                    
                    // Right arm joint overlays
                    GeometryReader { geometry in
                        let rightArmJoints: [VNHumanBodyPoseObservation.JointName] = currentDrill == .serve ? [
                            .rightShoulder, .rightElbow, .rightWrist
                        ] : []
                        
                        if rightArmJoints.contains(where: { cameraPoseManager.detectedPose[$0] != nil }) {
                          ZStack {
                            ForEach(rightArmJoints, id: \.self) { jointName in
                              if let point = cameraPoseManager.detectedPose[jointName] {
                                Circle()
                                  .fill(jointColor(for: jointName))
                                  .frame(width: 6, height: 6)
                                  .position(
                                    x: point.location.x * geometry.size.width,
                                    y: (1 - point.location.y) * geometry.size.height
                                  )
                              }
                            }
                          }
                          .accessibilityElement(children: .ignore)
                          .accessibilityLabel("Right arm tracking")
                          .accessibilityValue("\(rightArmJoints.filter { cameraPoseManager.detectedPose[$0] != nil }.count) joints")
                          .accessibilityIdentifier("practice.poseOverlay")
                        }

                        // Ball overlay (live camera)
                        if currentDrill == .serve, let manager = cameraManager.ballDetectionManager {
                            BallOverlayView(manager: manager, size: geometry.size)
                        }
                    }
                }
                
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("FPS: \(String(format: "%.1f", fps))")
                                .foregroundColor(.white)
                                .font(.caption)
                            Text("Frames: \(frameCount)")
                                .foregroundColor(.white)
                                .font(.caption)
                            Text("Status: \(cameraManager.captureState.message)")
                                .accessibilityIdentifier("camera.captureStatus")
                                .foregroundColor(.white)
                                .font(.callout)
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Joints: \(cameraPoseManager.detectedPose.count)")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    }
                    .padding()
                    
                    Spacer()
                    
                    HStack {
                        Button(cameraManager.captureRequested ? "Stop" :
                          (cameraManager.captureState.canRetry ? "Retry" : "Start")) {
                            if cameraManager.captureRequested {
                                cameraManager.stopCapture()
                                frameCount = 0
                                fps = 0
                            } else {
                                cameraManager.startCapture()
                                frameCount = 0
                                lastFrameTime = Date()
                            }
                        }
                        .padding()
                        .background(cameraManager.captureRequested ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .accessibilityIdentifier("camera.captureAction")
                        
                        Button("Test Beep") {
                            audioManager.playBeep()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding()
                }
            } else {
                VStack {
                    Text(cameraManager.accessState.message)
                        .accessibilityIdentifier("camera.permissionStatus")
                        .foregroundColor(cameraManager.accessState == .denied || cameraManager.accessState == .unavailable ? .red : .primary)
                        .font(.title2)
                    if cameraManager.accessState == .restricted {
                        Text("Camera access is controlled by device restrictions. Contact the device owner or administrator.")
                            .multilineTextAlignment(.center)
                            .padding()
                    } else if cameraManager.accessState == .denied {
                        Button("Open Settings") { cameraManager.openSettings() }
                            .accessibilityIdentifier("camera.permissionAction")
                            .buttonStyle(.borderedProminent)
                    } else if cameraManager.accessState == .undetermined || cameraManager.accessState == .requesting {
                        Button("Request Permission") { cameraManager.requestAccess() }
                            .disabled(cameraManager.accessState == .requesting)
                            .accessibilityIdentifier("camera.permissionAction")
                            .buttonStyle(.borderedProminent)
                    }
                    if cameraManager.captureRequested {
                        Button("Stop") { cameraManager.stopCapture() }
                            .accessibilityIdentifier("camera.captureAction")
                    }
                }
            }
        }
    }
    
    private var videoPlaybackView: some View {
        ZStack {
            if videoPlayerManager.duration > 0 {
                // Video player with controls
                VStack(spacing: 0) {
                    // Video display area with joint overlays
                    ZStack {
                        Group {
                            if let playerLayer = videoPlayerManager.getPlayerLayer() {
                                VideoPlayerView(playerLayer: playerLayer)
                            } else { Color.black }
                        }
                            .aspectRatio(16/9, contentMode: .fit)
                            .background(Color.black)
                        
                        // Right arm joint overlays for video
                        GeometryReader { geometry in
                            let rightArmJoints: [VNHumanBodyPoseObservation.JointName] = currentDrill == .serve ? [
                                .rightShoulder, .rightElbow, .rightWrist
                            ] : []
                            
                            if rightArmJoints.contains(where: { playbackPoseManager.detectedPose[$0] != nil }) {
                              ZStack {
                                ForEach(rightArmJoints, id: \.self) { jointName in
                                  if let point = playbackPoseManager.detectedPose[jointName] {
                                    Circle()
                                      .fill(jointColor(for: jointName))
                                      .frame(width: 6, height: 6)
                                      .position(
                                        x: point.location.x * geometry.size.width,
                                        y: (1 - point.location.y) * geometry.size.height
                                      )
                                  }
                                }
                              }
                              .accessibilityElement(children: .ignore)
                              .accessibilityLabel("Right arm tracking")
                              .accessibilityValue("\(rightArmJoints.filter { playbackPoseManager.detectedPose[$0] != nil }.count) joints")
                              .accessibilityIdentifier("practice.poseOverlay")
                            }

                            // Ball overlay (video)
                            if currentDrill == .serve, let manager = videoPlayerManager.ballDetectionManager {
                                BallOverlayView(manager: manager, size: geometry.size)
                            }
                        }
                        .aspectRatio(16/9, contentMode: .fit)
                    }
                    
                    // Video controls
                    VStack(spacing: 8) {
                        Text(videoPlayerManager.playbackState.label)
                            .foregroundColor(.white)
                            .accessibilityIdentifier("playback.status")
                        // FPS and info display
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Video FPS: \(String(format: "%.1f", fps))")
                                    .foregroundColor(.white)
                                    .font(.caption)
                                    .monospaced()
                                Text("Joints: \(playbackPoseManager.detectedPose.count)")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Time slider
                        if videoPlayerManager.duration > 0 {
                            HStack {
                                Text(formatTime(videoPlayerManager.currentTime))
                                    .accessibilityIdentifier("playback.position")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .monospaced()
                                
                                Slider(value: Binding(
                                    get: { min(max(0, videoPlayerManager.currentTime), videoPlayerManager.duration) },
                                    set: { newTime in
                                        videoPlayerManager.seek(to: max(0, newTime))
                                    }
                                ), in: 0...videoPlayerManager.duration)
                                .accentColor(.white)
                                .accessibilityIdentifier("playback.slider")
                                .accessibilityLabel("Playback position")
                                .accessibilityValue(Text("\(videoPlayerManager.currentTime, specifier: "%.1f") seconds of \(videoPlayerManager.duration, specifier: "%.1f") seconds"))
                                .disabled(videoPlayerManager.isLoading)
                                
                                Text(formatTime(videoPlayerManager.duration))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .monospaced()
                            }
                            .padding(.horizontal)
                        }
                        
                        // Play/pause and other controls
                        if currentDrill == .backhand {
                            HStack(spacing: 20) {
                                Button("−0.03s") { videoPlayerManager.seek(to: videoPlayerManager.currentTime - 1.0 / 30) }
                                Text("\(videoPlayerManager.currentTime, specifier: "%.2f")s").monospacedDigit()
                                Button("+0.03s") { videoPlayerManager.seek(to: videoPlayerManager.currentTime + 1.0 / 30) }
                            }
                            .disabled(videoPlayerManager.playbackState != .paused || videoPlayerManager.isLoading)
                        }
                        HStack(spacing: 20) {
                            Button(videoPlayerManager.playbackState == .ended ? "Replay" :
                                   (videoPlayerManager.playRequested ? "Pause" : "Play")) {
                                if videoPlayerManager.playRequested {
                                    videoPlayerManager.pause()
                                } else {
                                    // Refresh connection before playing
                                    videoPlayerManager.refreshPlayerLayerConnection()
                                    videoPlayerManager.play()
                                }
                            }
                            .accessibilityIdentifier("playback.action")
                            .disabled(videoPlayerManager.isLoading)
                            .padding()
                            .background(videoPlayerManager.playRequested ? Color.orange : Color.green)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            
                            Button("Choose New Video") { chooseVideo() }
                            .accessibilityIdentifier("playback.choose")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding()
                    }
                    .background(Color.black.opacity(0.8))
                }
            } else {
                // No video selected - show picker
                VStack {
                    Text("Video Playback Mode")
                        .font(.title2)
                        .padding()
                    
                    Text("Select a video from your camera roll")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Button("Choose Video from Library") { chooseVideo() }
                    .accessibilityIdentifier("playback.choose")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Spacer()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                if videoPlayerManager.isLoading {
                    ProgressView("Loading video…").accessibilityIdentifier("playback.loading")
                    Button("Cancel") {
                        videoImporter.cancel()
                        videoPlayerManager.cancelReplacement()
                    }.accessibilityIdentifier("playback.cancelImport")
                }
                if let message = videoPlayerManager.importMessage {
                    Text(message).accessibilityIdentifier("playback.importMessage")
                }
            }.padding()
        }
    }
    
    private func chooseVideo() {
        let request = videoPlayerManager.beginReplacement()
        importRequest = request
        videoImporter.begin(request: request) { request, outcome in
            videoPlayerManager.acceptImport(outcome, request: request)
        }
        showingVideoPicker = true
    }

    private func handleModeChange(to newMode: AppMode) {
        audioManager.cancelPendingBeeps()
        cameraBackhand.resetAttempt()
        playbackBackhand.resetAttempt()
        // Always retire the outgoing owner, including pending or already paused work.
        updateActiveContexts()
        frameCount = 0
        fps = 0
        lastFrameTime = Date()
        switch newMode {
        case .liveCamera:
            // Stop video player and start camera
            if cameraManager.hasPermission && scenePhase == .active {
                cameraManager.startCapture()
            }
        case .videoPlayback:
            // Stop camera recording when switching to video mode
            // Refresh video player connection after mode switch
            videoPlayerManager.refreshPlayerLayerConnection()
        }
    }

    private func updateActiveContexts() {
        if scenePhase != .active {
            audioManager.cancelPendingBeeps()
            cameraBackhand.resetAttempt()
            playbackBackhand.resetAttempt()
        }
        if scenePhase != .active || currentMode != .videoPlayback { videoImporter.cancel() }
        cameraManager.setContextActive(scenePhase == .active && currentMode == .liveCamera)
        videoPlayerManager.setContextActive(scenePhase == .active && currentMode == .videoPlayback)
    }

    private func handleDrillChange() {
        let restartCamera = cameraManager.captureRequested
        let restartVideo = videoPlayerManager.isPlaying
        cameraManager.stopCapture()
        videoPlayerManager.pause()
        audioManager.cancelPendingBeeps()
        cameraBackhand.resetAttempt()
        playbackBackhand.resetAttempt()
        cameraManager.ballDetectionManager?.setPoseOnly(currentDrill == .backhand)
        videoPlayerManager.ballDetectionManager?.setPoseOnly(currentDrill == .backhand)
        if restartCamera, currentMode == .liveCamera, scenePhase == .active { cameraManager.startCapture() }
        if restartVideo, currentMode == .videoPlayback, scenePhase == .active { videoPlayerManager.play() }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    
    func jointColor(for jointName: VNHumanBodyPoseObservation.JointName) -> Color {
        switch jointName {
        case .rightShoulder, .leftShoulder:
            return .red
        case .rightElbow, .leftElbow:
            return .green
        case .rightWrist, .leftWrist:
            return .blue
        default:
            return .yellow
        }
    }
}

// Observe the nested publisher directly: resets redraw even without a new FPS tick.
private struct BallOverlayView: View {
  @ObservedObject var manager: BallDetectionManager
  let size: CGSize

  var body: some View {
    if let pos = manager.ballPosition {
      Circle()
        .stroke(Color.yellow, lineWidth: 2)
        .frame(width: 14, height: 14)
        .accessibilityElement()
        .accessibilityLabel("Ball overlay")
        .accessibilityIdentifier("practice.ballOverlay")
        .position(x: pos.x * size.width, y: (1 - pos.y) * size.height)
    }
  }
}

#Preview {
    ContentView()
}
