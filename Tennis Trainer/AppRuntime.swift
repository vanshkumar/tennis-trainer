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
              "capture-startup", "capture-recovery", "capture-failure"]
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

    #if DEBUG
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
        case "capture-startup", "capture-recovery", "capture-failure": authorization = .authorized
        default: authorization = .notDetermined
        }
      }
    }
    #endif
}
