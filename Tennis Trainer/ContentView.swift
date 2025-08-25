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
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var poseDetectionManager = PoseDetectionManager()
    @StateObject private var videoPlayerManager = VideoPlayerManager()
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
            cameraManager.poseDetectionManager = poseDetectionManager
            cameraManager.setupBallDetection(with: poseDetectionManager)
            videoPlayerManager.poseDetectionManager = poseDetectionManager
            videoPlayerManager.setupBallDetection(with: poseDetectionManager)
            
            cameraManager.onFrameProcessed = { shouldBeep in
                frameCount += 1
                
                let now = Date()
                let timeDiff = now.timeIntervalSince(lastFrameTime)
                if timeDiff >= 1.0 {
                    fps = Double(frameCount) / timeDiff
                    frameCount = 0
                    lastFrameTime = now
                }
                
                if shouldBeep {
                    audioManager.playBeep()
                }
            }
            
            videoPlayerManager.onFrameProcessed = { shouldBeep in
                frameCount += 1
                
                let now = Date()
                let timeDiff = now.timeIntervalSince(lastFrameTime)
                if timeDiff >= 1.0 {
                    fps = Double(frameCount) / timeDiff
                    frameCount = 0
                    lastFrameTime = now
                }
                
                if shouldBeep {
                    audioManager.playBeep()
                }
            }
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
                    CameraPreview(previewLayer: cameraManager.getPreviewLayer())
                        .ignoresSafeArea()
                    
                    // Right arm joint overlays
                    GeometryReader { geometry in
                        let rightArmJoints: [VNHumanBodyPoseObservation.JointName] = [
                            .rightShoulder, .rightElbow, .rightWrist
                        ]
                        
                        ForEach(rightArmJoints, id: \.self) { jointName in
                            if let point = poseDetectionManager.detectedPose[jointName] {
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
                        if let pos = cameraManager.ballDetectionManager?.ballPosition {
                            Circle()
                                .stroke(Color.yellow, lineWidth: 2)
                                .frame(width: 14, height: 14)
                                .position(
                                    x: pos.x * geometry.size.width,
                                    y: (1 - pos.y) * geometry.size.height
                                )
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
                            Text("Status: \(cameraManager.isRecording ? "Recording" : "Stopped")")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Forearm: \(String(format: "%.1f°", poseDetectionManager.forearmAngle))")
                                .foregroundColor(.white)
                                .font(.caption)
                            Text("Upper Arm: \(String(format: "%.1f°", poseDetectionManager.upperArmAngle))")
                                .foregroundColor(.white)
                                .font(.caption)
                            Text("Joints: \(poseDetectionManager.detectedPose.count)")
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
                        Button(cameraManager.isRecording ? "Stop" : "Start") {
                            if cameraManager.isRecording {
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
                        .background(cameraManager.isRecording ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        
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
                    Text("Camera permission required")
                        .foregroundColor(.red)
                        .font(.title2)
                    Button("Request Permission") {
                        // This will trigger the permission request
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
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
            } else if let _ = selectedVideoURL,
                      let playerLayer = videoPlayerManager.getPlayerLayer() {
                
                // Video player with controls
                VStack(spacing: 0) {
                    // Video display area with joint overlays
                    ZStack {
                        VideoPlayerView(playerLayer: playerLayer)
                            .aspectRatio(16/9, contentMode: .fit)
                            .background(Color.black)
                        
                        // Right arm joint overlays for video
                        GeometryReader { geometry in
                            let rightArmJoints: [VNHumanBodyPoseObservation.JointName] = [
                                .rightShoulder, .rightElbow, .rightWrist
                            ]
                            
                            ForEach(rightArmJoints, id: \.self) { jointName in
                                if let point = poseDetectionManager.detectedPose[jointName] {
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
                            if let pos = videoPlayerManager.ballDetectionManager?.ballPosition {
                                Circle()
                                    .stroke(Color.yellow, lineWidth: 2)
                                    .frame(width: 14, height: 14)
                                    .position(
                                        x: pos.x * geometry.size.width,
                                        y: (1 - pos.y) * geometry.size.height
                                    )
                            }
                        }
                        .aspectRatio(16/9, contentMode: .fit)
                    }
                    
                    // Video controls
                    VStack(spacing: 8) {
                        // FPS and info display
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Video FPS: \(String(format: "%.1f", fps))")
                                    .foregroundColor(.white)
                                    .font(.caption)
                                    .monospaced()
                                Text("Joints: \(poseDetectionManager.detectedPose.count)")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Forearm: \(String(format: "%.1f°", poseDetectionManager.forearmAngle))")
                                    .foregroundColor(.white)
                                    .font(.caption)
                                Text("Upper Arm: \(String(format: "%.1f°", poseDetectionManager.upperArmAngle))")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        // Time slider
                        if videoPlayerManager.duration > 0 {
                            HStack {
                                Text(formatTime(videoPlayerManager.currentTime))
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
                                
                                Text(formatTime(videoPlayerManager.duration))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .monospaced()
                            }
                            .padding(.horizontal)
                        }
                        
                        // Play/pause and other controls
                        HStack(spacing: 20) {
                            Button(videoPlayerManager.isPlaying ? "Pause" : "Play") {
                                if videoPlayerManager.isPlaying {
                                    videoPlayerManager.pause()
                                } else {
                                    // Refresh connection before playing
                                    videoPlayerManager.refreshPlayerLayerConnection()
                                    videoPlayerManager.play()
                                }
                            }
                            .padding()
                            .background(videoPlayerManager.isPlaying ? Color.orange : Color.green)
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
        switch newMode {
        case .liveCamera:
            // Stop video player and start camera
            videoPlayerManager.pause()
            if cameraManager.hasPermission && !cameraManager.isRecording {
                cameraManager.startCapture()
            }
        case .videoPlayback:
            // Stop camera recording when switching to video mode
            if cameraManager.isRecording {
                cameraManager.stopCapture()
            }
            // Reset frame count and fps when switching modes
            frameCount = 0
            fps = 0
            lastFrameTime = Date()
            // Refresh video player connection after mode switch
            videoPlayerManager.refreshPlayerLayerConnection()
        }
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

#Preview {
    ContentView()
}
