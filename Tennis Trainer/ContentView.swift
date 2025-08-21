//
//  ContentView.swift
//  Tennis Trainer
//
//  Created by Vansh Kumar on 8/20/25.
//

import SwiftUI
import Vision

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var poseDetectionManager = PoseDetectionManager()
    @State private var frameCount = 0
    @State private var lastFrameTime = Date()
    @State private var fps: Double = 0
    
    var body: some View {
        ZStack {
            if cameraManager.hasPermission {
                ZStack {
                    CameraPreview(previewLayer: cameraManager.getPreviewLayer())
                        .ignoresSafeArea()
                    
                    // Overlay detected joints
                    GeometryReader { geometry in
                        ForEach(Array(poseDetectionManager.detectedPose.keys), id: \.self) { jointName in
                            if let point = poseDetectionManager.detectedPose[jointName] {
                                Circle()
                                    .fill(jointColor(for: jointName))
                                    .frame(width: 12, height: 12)
                                    .position(
                                        x: point.location.x * geometry.size.width,
                                        y: (1 - point.location.y) * geometry.size.height // Flip Y for UIKit
                                    )
                            }
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
        .onAppear {
            cameraManager.poseDetectionManager = poseDetectionManager
            
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
        }
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
