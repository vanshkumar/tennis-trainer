import AVFoundation
import SwiftUI
import Vision

class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var hasPermission = false
    
    private let captureSession = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    var poseDetectionManager: PoseDetectionManager?
    var onFrameProcessed: ((Bool) -> Void)?
    
    private let horizontalDetector = ForearmHorizontalDetector()
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera permission: authorized")
            hasPermission = true
            setupCamera()
        case .notDetermined:
            print("Camera permission: requesting...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    print("Camera permission: \(granted ? "granted" : "denied")")
                    self.hasPermission = granted
                    if granted {
                        self.setupCamera()
                    }
                }
            }
        case .denied:
            print("Camera permission: denied")
            hasPermission = false
        case .restricted:
            print("Camera permission: restricted")
            hasPermission = false
        @unknown default:
            print("Camera permission: unknown")
            hasPermission = false
        }
    }
    
    private func setupCamera() {
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    private func configureSession() {
        print("Configuring camera session...")
        captureSession.beginConfiguration()
        
        captureSession.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Error: Could not get back camera")
            captureSession.commitConfiguration()
            return
        }
        
        print("Found camera: \(videoDevice.localizedName)")
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Error: Could not create camera input")
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            print("Added camera input successfully")
        } else {
            print("Error: Could not add camera input to session")
            captureSession.commitConfiguration()
            return
        }
        
        configureVideoOutput()
        configure120FPS(for: videoDevice)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            print("Added video output successfully")
        } else {
            print("Error: Could not add video output to session")
        }
        
        captureSession.commitConfiguration()
        print("Camera session configuration complete")
    }
    
    private func configureVideoOutput() {
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
    }
    
    private func configure120FPS(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            let format = device.formats.first { format in
                let ranges = format.videoSupportedFrameRateRanges
                return ranges.contains { range in
                    range.maxFrameRate >= 120.0
                }
            }
            
            if let format = format {
                device.activeFormat = format
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 120)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 120)
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error configuring 120fps: \(error)")
        }
    }
    
    func startCapture() {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                print("Starting camera capture...")
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isRecording = true
                    print("Camera capture started")
                }
            }
        }
    }
    
    func stopCapture() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                print("Stopping camera capture...")
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isRecording = false
                    print("Camera capture stopped")
                }
            }
        }
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            print("Created preview layer for session")
        }
        return previewLayer!
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        processFrame(pixelBuffer: pixelBuffer)
    }
    
    private func processFrame(pixelBuffer: CVPixelBuffer) {
        poseDetectionManager?.detectPose(in: pixelBuffer)
        
        let shouldBeep = checkForearmHorizontal()
        
        DispatchQueue.main.async {
            self.onFrameProcessed?(shouldBeep)
        }
    }
    
    private func checkForearmHorizontal() -> Bool {
        guard let poseManager = poseDetectionManager else { return false }
        return horizontalDetector.checkForearmHorizontal(forearmAngle: poseManager.forearmAngle)
    }
}
