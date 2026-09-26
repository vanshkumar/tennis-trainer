import AVFoundation
import SwiftUI
import Vision

final class CameraManager: NSObject, ObservableObject {
    enum AccessState: Equatable {
      case undetermined, requesting, authorized, denied, restricted, unavailable

      var message: String {
        switch self {
        case .undetermined: return "Camera permission required"
        case .requesting: return "Requesting access…"
        case .authorized: return "Camera access granted"
        case .denied: return "Camera access denied"
        case .restricted: return "Camera access is restricted"
        case .unavailable: return "Camera access is unavailable"
        }
      }
    }

    struct Dependencies {
      var session: (@escaping () -> Void) -> Void
      var drain: (@escaping () -> Void) -> Void
      var state: (@escaping () -> Void) -> Void
      var stop: () -> Void
      var attach: (Bool) -> Void
      var start: () -> Bool
      var beforeAdmission: () -> Void = {}
      var authorization: () -> AVAuthorizationStatus = { .authorized }
      var requestAuthorization: (@escaping (Bool) -> Void) -> Void = { _ in }
      var openSettings: () -> Void = {}
    }

    @Published var isRecording = false
    @Published private(set) var captureRequested = false
    @Published private(set) var accessState: AccessState = .undetermined
    var hasPermission: Bool { accessState == .authorized }
    private var authorizationRequest: UUID?
    private var waitingForAuthorization = false
    private var sessionConfigured = false
    
    private lazy var captureSession = AVCaptureSession()
    private lazy var videoOutput = AVCaptureVideoDataOutput()
    // Keep session lifecycle work responsive even when frame analysis is expensive.
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoProcessingQueue = DispatchQueue(label: "camera.video.processing.queue", qos: .userInitiated)
    private let frameProcessingLock = NSLock()
    private var operation = UUID()
    private var ingressGeneration: UUID?
    private var contextActive = true
    private var dependencies: Dependencies!
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    var poseDetectionManager: PoseDetectionManager?
    var ballDetectionManager: BallDetectionManager?
    var onFrameProcessed: (() -> Void)?
    var onApex: (() -> Void)?
    private let sourceID = UUID()
    
    override convenience init() {
        self.init(dependencies: nil)
    }

    init(dependencies: Dependencies?) {
        super.init()
        if let dependencies {
          self.dependencies = dependencies
        } else if AppRuntime.isRunningTests {
          self.dependencies = Dependencies(session: { $0() }, drain: { $0() }, state: { $0() },
            stop: {}, attach: { _ in }, start: { false }, authorization: { .notDetermined })
        } else {
          self.dependencies = Dependencies(
            session: { [weak self] in self?.sessionQueue.async(execute: $0) },
            drain: { [weak self] in self?.videoProcessingQueue.async(execute: $0) },
            state: { DispatchQueue.main.async(execute: $0) },
            stop: { [weak self] in
              guard let self else { return }
              if self.captureSession.isRunning { self.captureSession.stopRunning() }
            }, attach: { [weak self] attached in
              guard let self else { return }
              self.videoOutput.setSampleBufferDelegate(attached ? self : nil,
                queue: attached ? self.videoProcessingQueue : nil)
            }, start: { [weak self] in
              guard let self, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return false }
              if !self.sessionConfigured {
                self.configureSession()
                self.sessionConfigured = true
              }
              if !self.captureSession.isRunning { self.captureSession.startRunning() }
              return self.captureSession.isRunning
            }, authorization: { AVCaptureDevice.authorizationStatus(for: .video) },
            requestAuthorization: { AVCaptureDevice.requestAccess(for: .video, completionHandler: $0) },
            openSettings: {
              guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
              UIApplication.shared.open(url)
            })
        }
        refreshAuthorization()
    }
    
    func refreshAuthorization() {
      switch dependencies.authorization() {
      case .authorized: accessState = .authorized
      case .notDetermined: accessState = authorizationRequest == nil ? .undetermined : .requesting
      case .denied: accessState = .denied
      case .restricted: accessState = .restricted
      @unknown default: accessState = .unavailable
      }
      if hasPermission {
        if waitingForAuthorization && captureRequested && contextActive {
          waitingForAuthorization = false
          beginCapture()
        }
      } else if accessState != .undetermined && accessState != .requesting {
        stopCapture()
      }
    }

    func requestAccess() {
      refreshAuthorization()
      guard contextActive, accessState == .undetermined, authorizationRequest == nil else { return }
      let request = UUID()
      authorizationRequest = request
      accessState = .requesting
      dependencies.requestAuthorization { [weak self] _ in
        self?.dependencies.state { [weak self] in
          guard let self, self.authorizationRequest == request else { return }
          self.authorizationRequest = nil
          // The OS snapshot wins over an old callback's Boolean, including revocation.
          self.refreshAuthorization()
        }
      }
    }

    func openSettings() {
      refreshAuthorization()
      guard accessState == .denied else { return }
      dependencies.openSettings()
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        
        captureSession.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Error: Could not get back camera")
            captureSession.commitConfiguration()
            return
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Error: Could not create camera input")
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("Error: Could not add camera input to session")
            captureSession.commitConfiguration()
            return
        }
        
        configureVideoOutput()
        configure120FPS(for: videoDevice)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            print("Error: Could not add video output to session")
        }
        
        captureSession.commitConfiguration()
    }
    
    private func configureVideoOutput() {
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        videoOutput.setSampleBufferDelegate(self, queue: videoProcessingQueue)
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
      guard contextActive, !captureRequested else { return }
      refreshAuthorization()
      guard hasPermission || accessState == .undetermined || accessState == .requesting else { return }
      captureRequested = true
      if !hasPermission {
        waitingForAuthorization = true
        requestAccess()
        return
      }
      beginCapture()
    }

    private func beginCapture() {
      let current = UUID()
      frameProcessingLock.lock()
      operation = current
      ingressGeneration = nil
      frameProcessingLock.unlock()
      ballDetectionManager?.resetTrackingState()

      // Stop and detach on the AV owner BEFORE draining the serial callback queue.
      // Reopening a Boolean before this boundary would retag queued old buffers.
      dependencies.session { [weak self] in
        guard let self else { return }
        self.dependencies.stop()
        self.dependencies.attach(false)
        self.dependencies.drain { [weak self] in
          guard let self else { return }
          self.dependencies.session { [weak self] in
            guard let self, self.isCurrentOperation(current) else { return }
            guard self.dependencies.authorization() == .authorized else {
              self.dependencies.state { [weak self] in self?.refreshAuthorization() }
              return
            }
            self.dependencies.attach(true)
            let running = self.dependencies.start()
            self.dependencies.state { [weak self] in
              guard let self, self.isCurrentOperation(current) else { return }
              self.refreshAuthorization()
              guard self.hasPermission, self.isCurrentOperation(current) else { return }
              self.isRecording = running
              let generation = self.ballDetectionManager?.admissionGeneration
              self.frameProcessingLock.lock()
              if self.operation == current {
                self.ingressGeneration = running ? generation : nil
              }
              self.frameProcessingLock.unlock()
            }
          }
        }
      }
    }
    
    func stopCapture() {
      frameProcessingLock.lock()
      operation = UUID()
      ingressGeneration = nil
      frameProcessingLock.unlock()
      ballDetectionManager?.resetTrackingState()
      captureRequested = false
      waitingForAuthorization = false
      isRecording = false
      dependencies.session { [weak self] in
        self?.dependencies.stop()
        self?.dependencies.attach(false)
      }
    }

    func setContextActive(_ active: Bool) {
      contextActive = active
      if !active { stopCapture() }
      else { refreshAuthorization() }
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
        }
        return previewLayer!
    }

    private func isCurrentOperation(_ token: UUID) -> Bool {
      frameProcessingLock.lock()
      defer { frameProcessingLock.unlock() }
      return operation == token
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        receiveSampleBuffer(sampleBuffer)
    }

    // Shared production ingress; tests inject AV delivery at this boundary.
    func receiveSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
      frameProcessingLock.lock()
      let generation = ingressGeneration
      frameProcessingLock.unlock()
      guard let generation else { return }
      dependencies.beforeAdmission()
      submitSampleBuffer(sampleBuffer, expectedGeneration: generation)
    }
    
    func submitSampleBuffer(_ sampleBuffer: CMSampleBuffer, expectedGeneration: UUID? = nil) {
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        ballDetectionManager?.process(input: .init(
            pixelBuffer: pixels, sourceTime: time, orientation: .right, sourceID: sourceID
        ), expectedGeneration: expectedGeneration)
    }
}

// MARK: - Setup
extension CameraManager {
    func setupBallDetection(with pose: PoseDetectionManager,
                            factory: ((PoseDetectionManager) -> BallDetectionManager)? = nil) {
        guard ballDetectionManager == nil else { return }
        guard factory != nil || !AppRuntime.isRunningTests else {
            self.ballDetectionManager = nil
            return
        }
        // Live overlay prefers the freshest frame index (t=4)
        let manager = factory?(pose) ?? BallDetectionManager(poseDetectionManager: pose, overlayTIndex: 4)
        manager.onApex = { [weak self] in
            self?.onApex?()
        }
        manager.onFrameProcessed = { [weak self] in self?.onFrameProcessed?() }
        self.ballDetectionManager = manager
    }
}
