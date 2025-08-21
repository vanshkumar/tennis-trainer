//
//  ContentView.swift
//  Tennis Trainer
//
//  Created by Vansh Kumar on 8/20/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var audioManager = AudioManager()
    @State private var frameCount = 0
    @State private var lastFrameTime = Date()
    @State private var fps: Double = 0
    
    var body: some View {
        ZStack {
            if cameraManager.hasPermission {
                CameraPreview(previewLayer: cameraManager.getPreviewLayer())
                    .ignoresSafeArea()
                
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
}

#Preview {
    ContentView()
}
