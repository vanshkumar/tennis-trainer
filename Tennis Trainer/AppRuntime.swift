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
      return ["permission-undetermined", "permission-denied-return", "permission-restricted"]
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
          session: { $0() }, drain: { $0() }, state: { DispatchQueue.main.async(execute: $0) },
          stop: {}, attach: { _ in }, start: { true },
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
          }))
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

      init(scenario: String) {
        switch scenario {
        case "permission-denied-return": authorization = .denied
        case "permission-restricted": authorization = .restricted
        default: authorization = .notDetermined
        }
      }
    }
    #endif
}
