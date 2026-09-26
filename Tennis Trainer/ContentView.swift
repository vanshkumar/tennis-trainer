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

struct ContentView: View {
    @StateObject private var cameraManager = AppRuntime.makeCameraManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var cameraPoseManager = PoseDetectionManager()
    @StateObject private var playbackPoseManager = PoseDetectionManager()
    @StateObject private var videoPlayerManager = AppRuntime.makeVideoPlayerManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var frameCount = 0
    @State private var lastFrameTime = Date()
    @State private var fps: Double = 0
    
    @State private var currentMode: AppMode = .liveCamera
    @State private var selectedVideoURL: URL?
    @State private var showingVideoPicker = false
    
    var body: some View {
        VStack {
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
            ZStack {
                switch currentMode {
                case .liveCamera:
                    liveCameraView
                case .videoPlayback:
                    videoPlaybackView
                }
            }
        }
        .onAppear {
            cameraManager.poseDetectionManager = cameraPoseManager
            cameraManager.setupBallDetection(with: cameraPoseManager)
            videoPlayerManager.poseDetectionManager = playbackPoseManager
            videoPlayerManager.setupBallDetection(with: playbackPoseManager)
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
                guard currentMode == .liveCamera, scenePhase == .active else { return }
                audioManager.playBeep()
            }
            videoPlayerManager.onApex = {
                guard currentMode == .videoPlayback, scenePhase == .active else { return }
                audioManager.playBeep()
            }
        }
        .onChange(of: scenePhase) { _, _ in updateActiveContexts() }
        .onDisappear {
            cameraManager.setContextActive(false)
            videoPlayerManager.setContextActive(false)
        }
        .onChange(of: selectedVideoURL) { _, newURL in
            if let url = newURL {
                videoPlayerManager.loadVideo(from: url)
            }
        }
        .sheet(isPresented: $showingVideoPicker) {
            VideoPickerView(selectedVideoURL: $selectedVideoURL)
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
                        let rightArmJoints: [VNHumanBodyPoseObservation.JointName] = [
                            .rightShoulder, .rightElbow, .rightWrist
                        ]
                        
                        ForEach(rightArmJoints, id: \.self) { jointName in
                            if let point = cameraPoseManager.detectedPose[jointName] {
                                Circle()
                                    .fill(jointColor(for: jointName))
                                    .frame(width: 6, height: 6)
                                    .position(
                                        x: point.location.x * geometry.size.width,
                                        y: (1 - point.location.y) * geometry.size.height // Flip Y for UIKit
                                    )
                            }
                        }

                        // Ball overlay (live camera)
                        if let manager = cameraManager.ballDetectionManager {
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
                                .font(.caption)
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
                        .foregroundColor(.red)
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
            if videoPlayerManager.isLoading {
                // Loading state
                VStack {
                    ProgressView("Loading video...")
                        .font(.title2)
                        .padding()
                    Spacer()
                }
            } else if videoPlayerManager.duration > 0 {
                
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
                            let rightArmJoints: [VNHumanBodyPoseObservation.JointName] = [
                                .rightShoulder, .rightElbow, .rightWrist
                            ]
                            
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

                            // Ball overlay (video)
                            if let manager = videoPlayerManager.ballDetectionManager {
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
                                    get: { max(0, videoPlayerManager.currentTime) },
                                    set: { newTime in
                                        videoPlayerManager.seek(to: max(0, newTime))
                                    }
                                ), in: 0...max(videoPlayerManager.duration, 1))
                                .accentColor(.white)
                                .accessibilityIdentifier("playback.slider")
                                
                                Text(formatTime(videoPlayerManager.duration))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .monospaced()
                            }
                            .padding(.horizontal)
                        }
                        
                        // Play/pause and other controls
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
                            .padding()
                            .background(videoPlayerManager.playRequested ? Color.orange : Color.green)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            
                            Button("Choose New Video") {
                                videoPlayerManager.pause()
                                showingVideoPicker = true
                            }
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
                    
                    Button("Choose Video from Library") {
                        showingVideoPicker = true
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Spacer()
                }
            }
        }
    }
    
    private func handleModeChange(to newMode: AppMode) {
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
        cameraManager.setContextActive(scenePhase == .active && currentMode == .liveCamera)
        videoPlayerManager.setContextActive(scenePhase == .active && currentMode == .videoPlayback)
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
        .position(x: pos.x * size.width, y: (1 - pos.y) * size.height)
    }
  }
}

#Preview {
    ContentView()
}
