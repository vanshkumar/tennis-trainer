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

    enum CaptureState: Equatable {
      case stopped, configuring, starting, running, interrupted, recovering
      case failed(String)

      var message: String {
        switch self {
        case .stopped: return "Stopped"
        case .configuring: return "Configuring…"
        case .starting: return "Starting…"
        case .running: return "Running"
        case .interrupted: return "Interrupted"
        case .recovering: return "Recovering…"
        case .failed(let message): return "Failed: \(message)"
        }
      }

      var canRetry: Bool {
        if case .failed = self { return true }
        return false
      }
    }

    struct SessionSnapshot {
      var running: Bool
      var interrupted: Bool = false
    }

    enum SessionEvent {
      case started, stopped, interrupted, interruptionEnded
      case runtimeError(recoverable: Bool)
    }

    enum ConfigurationError: Error {
      case missingCamera, inputUnavailable, outputUnavailable
    }

    // Allocate before publishing the manager to either the preview or session
    // executor. Immutable references give configuration, preview and teardown
    // one owner without locking around blocking AVFoundation operations.
    final class CaptureBackend {
      let session = AVCaptureSession()
      let output = AVCaptureVideoDataOutput()
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
      var configure: () throws -> Void = {}
      var snapshot: (() -> SessionSnapshot)? = nil
      var observe: ((@escaping (SessionEvent) -> Void) -> () -> Void)? = nil
    }

    @Published private(set) var captureState: CaptureState = .stopped
    var isRecording: Bool { captureState == .running && captureRequested && hasPermission && contextActive }
    @Published private(set) var captureRequested = false
    @Published private(set) var accessState: AccessState = .undetermined
    var hasPermission: Bool { accessState == .authorized }
    private var authorizationRequest: UUID?
    private var waitingForAuthorization = false
    private var sessionConfigured = false
    private var removeSessionObservers: (() -> Void)?
    private var recoveryAttempts = 0
    private let backend: CaptureBackend?
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

    init(dependencies: Dependencies?, backend: CaptureBackend? = nil) {
        // Injected managers omit all camera resources unless a test explicitly
        // supplies an inert backend to inspect preview/session ownership.
        self.backend = backend ?? (dependencies == nil && !AppRuntime.isRunningTests ? CaptureBackend() : nil)
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
              guard let session = self?.backend?.session else { return }
              if session.isRunning { session.stopRunning() }
            }, attach: { [weak self] attached in
              guard let self, let output = self.backend?.output else { return }
              output.setSampleBufferDelegate(attached ? self : nil,
                queue: attached ? self.videoProcessingQueue : nil)
            }, start: { [weak self] in
              guard let session = self?.backend?.session,
                    AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return false }
              if !session.isRunning { session.startRunning() }
              return session.isRunning
            }, authorization: { AVCaptureDevice.authorizationStatus(for: .video) },
            requestAuthorization: { AVCaptureDevice.requestAccess(for: .video, completionHandler: $0) },
            openSettings: {
              guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
              UIApplication.shared.open(url)
            }, configure: { [weak self] in try self?.configureSession() },
            snapshot: { [weak self] in
              .init(running: self?.backend?.session.isRunning ?? false,
                interrupted: self?.backend?.session.isInterrupted ?? false)
            }, observe: { [weak self] callback in
              self?.observeSession(callback) ?? {}
            })
        }
        refreshAuthorization()
    }

    deinit {
      removeSessionObservers?()
      ballDetectionManager?.resetTrackingState()
      if let backend {
        sessionQueue.async {
          backend.output.setSampleBufferDelegate(nil, queue: nil)
          if backend.session.isRunning { backend.session.stopRunning() }
        }
      }
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
      } else if (captureRequested && !waitingForAuthorization)
          || (accessState != .undetermined && accessState != .requesting) {
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
    
    private func configureSession() throws {
        guard let backend else { throw ConfigurationError.missingCamera }
        let captureSession = backend.session
        let videoOutput = backend.output
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        captureSession.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw ConfigurationError.missingCamera
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw ConfigurationError.inputUnavailable
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            throw ConfigurationError.inputUnavailable
        }
        
        configureVideoOutput(videoOutput)
        configure120FPS(for: videoDevice)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            captureSession.removeInput(videoInput)
            throw ConfigurationError.outputUnavailable
        }
    }
    
    private func configureVideoOutput(_ videoOutput: AVCaptureVideoDataOutput) {
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
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
      recoveryAttempts = 0
      if !hasPermission {
        waitingForAuthorization = true
        requestAccess()
        return
      }
      beginCapture()
    }

    private func beginCapture(recovering: Bool = false) {
      let current = UUID()
      frameProcessingLock.lock()
      operation = current
      ingressGeneration = nil
      frameProcessingLock.unlock()
      ballDetectionManager?.resetTrackingState()
      captureState = recovering ? .recovering : .configuring

      // Stop and detach on the AV owner BEFORE draining the serial callback queue.
      // Reopening a Boolean before this boundary would retag queued old buffers.
      dependencies.session { [weak self] in
        guard let self, self.isCurrentOperation(current) else { return }
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
            self.removeSessionObservers?()
            self.removeSessionObservers = self.dependencies.observe? { [weak self] event in
              self?.dependencies.state { [weak self] in
                self?.reconcile(event, operation: current)
              }
            }
            do {
              if !self.sessionConfigured {
                try self.dependencies.configure()
                self.sessionConfigured = true
              }
            } catch {
              self.dependencies.state { [weak self] in
                guard let self, self.isCurrentOperation(current) else { return }
                self.failCapture("Camera configuration unavailable")
              }
              return
            }
            guard self.isCurrentOperation(current), self.dependencies.authorization() == .authorized else {
              self.dependencies.state { [weak self] in self?.refreshAuthorization() }
              return
            }
            self.dependencies.state { [weak self] in
              guard let self, self.isCurrentOperation(current) else { return }
              if !recovering { self.captureState = .starting }
            }
            self.dependencies.attach(true)
            let running = self.dependencies.start()
            // startRunning is blocking. Stop may have retired this operation while
            // it was inside AVFoundation; shut down that physical start immediately.
            guard self.isCurrentOperation(current) else {
              self.dependencies.stop()
              self.dependencies.attach(false)
              return
            }
            self.dependencies.state { [weak self] in
              guard let self, self.isCurrentOperation(current) else { return }
              self.refreshAuthorization()
              guard self.hasPermission, self.isCurrentOperation(current) else { return }
              guard self.hasPermission, self.captureRequested, self.contextActive else { return }
              let actual = self.dependencies.snapshot?() ?? .init(running: running)
              if actual.interrupted {
                self.invalidateAnalysis()
                self.captureState = .interrupted
                return
              }
              guard actual.running else {
                self.failCapture("Camera could not start")
                return
              }
              self.captureState = .running
              let generation = self.ballDetectionManager?.admissionGeneration
              self.frameProcessingLock.lock()
              if self.operation == current {
                self.ingressGeneration = generation
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
      captureState = .stopped
      let stoppedOperation = currentOperation
      dependencies.session { [weak self] in
        guard let self, self.isCurrentOperation(stoppedOperation) else { return }
        self.removeSessionObservers?()
        self.removeSessionObservers = nil
        self.dependencies.stop()
        self.dependencies.attach(false)
      }
    }

    private func invalidateAnalysis() {
      frameProcessingLock.lock()
      ingressGeneration = nil
      frameProcessingLock.unlock()
      ballDetectionManager?.resetTrackingState()
    }

    private func failCapture(_ message: String) {
      stopCapture()
      captureState = .failed(message)
    }

    private func recoverCapture() {
      guard recoveryAttempts < 1 else {
        failCapture("Camera recovery failed. Retry to continue")
        return
      }
      recoveryAttempts += 1
      beginCapture(recovering: true)
    }

    private func reconcile(_ event: SessionEvent, operation current: UUID) {
      guard isCurrentOperation(current) else { return }
      refreshAuthorization()
      guard isCurrentOperation(current), captureRequested, contextActive, hasPermission,
            let actual = dependencies.snapshot?() else { return }
      // Read the backend AFTER delivery to the state executor. Queued notification
      // names are historical evidence, never authority to resume or overwrite state.
      if actual.interrupted {
        if captureState != .interrupted { invalidateAnalysis() }
        captureState = .interrupted
        return
      }
      switch event {
      case .interruptionEnded:
        if captureState == .interrupted { recoverCapture() }
      case .runtimeError(let recoverable):
        guard !actual.running else { return }
        invalidateAnalysis()
        if recoverable { recoverCapture() }
        else { failCapture("Camera stopped unexpectedly") }
      case .stopped:
        if !actual.running && captureState == .running {
          failCapture("Camera stopped unexpectedly")
        }
      case .started, .interrupted:
        // Startup completion owns reopening after configure/start AND callback drain.
        break
      }
    }

    private func observeSession(_ callback: @escaping (SessionEvent) -> Void) -> () -> Void {
      guard let captureSession = backend?.session else { return {} }
      let center = NotificationCenter.default
      let events: [(Notification.Name, SessionEvent)] = [
        (AVCaptureSession.didStartRunningNotification, .started),
        (AVCaptureSession.didStopRunningNotification, .stopped),
        (AVCaptureSession.wasInterruptedNotification, .interrupted),
        (AVCaptureSession.interruptionEndedNotification, .interruptionEnded)
      ]
      var tokens = events.map { name, event in
        center.addObserver(forName: name, object: captureSession, queue: nil) { _ in callback(event) }
      }
      tokens.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification,
        object: captureSession, queue: nil) { notification in
          let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
          callback(.runtimeError(recoverable: error?.code == .mediaServicesWereReset))
        })
      return { tokens.forEach(center.removeObserver) }
    }

    private var currentOperation: UUID {
      frameProcessingLock.lock()
      defer { frameProcessingLock.unlock() }
      return operation
    }

    func setContextActive(_ active: Bool) {
      contextActive = active
      if !active { stopCapture() }
      else { refreshAuthorization() }
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer()
            layer.session = backend?.session
            previewLayer = layer
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
