import Foundation
import AVFoundation

enum AppRuntime {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || practiceUIScenario != nil
    }

    static var practiceUIScenario: String? {
      #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      guard let index = arguments.firstIndex(of: "--practice-ui-scenario"),
            arguments.indices.contains(index + 1) else { return nil }
      let name = arguments[index + 1]
      return ["permission-undetermined", "permission-denied-return", "permission-restricted",
              "capture-startup", "capture-recovery", "capture-failure", "playback-seek", "playback-end",
              "playback-import", "playback-import-empty", "playback-overlay", "playback-short"]
        .contains(name) ? name : nil
      #else
      return nil
      #endif
    }

    static func makeCameraManager() -> CameraManager {
      #if DEBUG
      if let scenario = practiceUIScenario {
        let effects = CameraScenarioEffects(scenario: scenario)
        let camera = CameraManager(dependencies: .init(
          session: { $0() }, drain: { $0() }, state: { job in
            effects.stateDelivery += 1
            let hold = (scenario == "capture-startup" && effects.stateDelivery == 2)
              || (scenario == "capture-recovery" && effects.starts == 2)
            DispatchQueue.main.asyncAfter(deadline: .now() + (hold ? 4 : 0), execute: job)
          }, stop: { effects.running = false }, attach: { _ in }, start: {
            effects.starts += 1
            effects.running = scenario != "capture-failure" || effects.starts > 1
            if scenario == "capture-recovery" && effects.starts == 1 {
              DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                effects.interrupted = true
                effects.event?(.interrupted)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                  effects.interrupted = false
                  effects.event?(.interruptionEnded)
                }
              }
            }
            return effects.running
          },
          authorization: { effects.authorization },
          requestAuthorization: { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
              effects.authorization = .authorized
              completion(true)
            }
          }, openSettings: {
            effects.camera?.setContextActive(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
              effects.authorization = .authorized
              effects.camera?.setContextActive(true)
            }
          }, snapshot: { .init(running: effects.running, interrupted: effects.interrupted) },
          observe: { callback in effects.event = callback; return { effects.event = nil } }))
        effects.camera = camera
        return camera
      }
      #endif
      return CameraManager()
    }

    static func makeVideoPlayerManager() -> VideoPlayerManager {
      #if DEBUG
      if let scenario = practiceUIScenario, scenario.hasPrefix("playback-") {
        let effects = PlaybackScenarioEffects()
        let manager = VideoPlayerManager(dependencies: .init(play: {
          effects.stopped = false
          if scenario == "playback-end" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
              effects.position = CMTime(value: 30, timescale: 1)
              effects.stopped = true
              effects.event?(.ended)
            }
          }
          return true
        }, pause: {},
          startLoop: {}, stopLoop: {}, load: { _ in scenario == "playback-short" ? 0.5 : 30 },
          seek: { target, completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
              effects.position = target
              completion(true)
            }
          }, currentTime: { effects.position },
          observeEvents: { callback in effects.event = callback; return { effects.event = nil } },
          snapshot: { .init(position: effects.position, stopped: effects.stopped, failed: false) }))
        if scenario != "playback-import-empty" {
          manager.loadVideo(from: URL(fileURLWithPath: "/scripted-playback.mov"))
        }
        return manager
      }
      #endif
      return VideoPlayerManager()
    }

    #if DEBUG
    static func deliverImport(_ importer: VideoImportManager, request: UUID, result: String) {
      if result == "cancel" { importer.receiveSelection(request: request, provider: nil); return }
      importer.receiveSelection(request: request) { callback in
        let progress = Progress(totalUnitCount: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
          if result == "failure" { callback(nil, NSError(domain: "InjectedImport", code: 1)); return }
          let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
          defer { try? FileManager.default.removeItem(at: url) }
          do {
            try Data([0, 1, 2]).write(to: url)
            callback(url, nil)
          } catch { callback(nil, error) }
        }
        return progress
      }
    }
    #endif

    static var overlayFactory: ((PoseDetectionManager) -> BallDetectionManager)? {
      #if DEBUG
      if practiceUIScenario == "playback-overlay" {
        return { pose in
          BallDetectionManager(dependencies: .init(analyze: { _, _, _ in .init(samples: nil, position: nil) },
            publishPose: { [weak pose] in pose?.publish($0) }, worker: { $0() }, publication: { $0() }))
        }
      }
      #endif
      return nil
    }

    static func seedOverlay(_ ball: BallDetectionManager?, pose: PoseDetectionManager) {
      #if DEBUG
      guard practiceUIScenario == "playback-overlay" else { return }
      ball?.ballPosition = CGPoint(x: 0.5, y: 0.5)
      pose.detectedPose = [.rightWrist: .init(location: CGPoint(x: 0.4, y: 0.4), confidence: 1)]
      #endif
    }

    #if DEBUG
    private final class PlaybackScenarioEffects {
      var position = CMTime.zero
      var stopped = false
      var event: ((VideoPlayerManager.ItemEvent) -> Void)?
    }
    private final class CameraScenarioEffects {
      var authorization: AVAuthorizationStatus
      weak var camera: CameraManager?
      var running = false
      var interrupted = false
      var starts = 0
      var stateDelivery = 0
      var event: ((CameraManager.SessionEvent) -> Void)?

      init(scenario: String) {
        switch scenario {
        case "permission-denied-return": authorization = .denied
        case "permission-restricted": authorization = .restricted
        case "capture-startup", "capture-recovery", "capture-failure", "playback-overlay": authorization = .authorized
        default: authorization = .notDetermined
        }
      }
    }
    #endif
}
