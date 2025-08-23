import Foundation

class ForearmHorizontalDetector {
    private enum ForearmState {
        case below      // 270° to 355° - backswing position
        case above      // 5° to 90° - follow-through position  
        case deadZone   // 355° to 5° - transition buffer
        case unknown    // outside tennis range or just started
    }
    
    private var previousState: ForearmState = .unknown
    private var lastBeepTime: Date = Date.distantPast
    
    private let cooldownSeconds = 0.5 // minimum time between beeps
    
    func checkForearmHorizontal(forearmAngle: Double) -> Bool {
        let currentState = classifyAngle(forearmAngle)
        
        // Detect upward crossing: below → above (right-handed forehand)
        let isUpwardCrossing = previousState == .below && currentState == .above
        
        // Only beep on upward crossing with cooldown
        let shouldBeep = isUpwardCrossing && 
                        Date().timeIntervalSince(lastBeepTime) > cooldownSeconds
        
        if shouldBeep {
            lastBeepTime = Date()
        }
        
        // Update state (but don't update to deadZone to avoid state confusion)
        if currentState != .deadZone {
            previousState = currentState
        }
        
        return shouldBeep
    }
    
    private func classifyAngle(_ angle: Double) -> ForearmState {
        // Normalize angle to 0-360 range
        let normalizedAngle = angle.truncatingRemainder(dividingBy: 360.0)
        let positiveAngle = normalizedAngle < 0 ? normalizedAngle + 360.0 : normalizedAngle
        
        // Classify based on tennis motion zones
        if positiveAngle >= 270.0 && positiveAngle <= 355.0 {
            return .below      // Backswing/preparation
        } else if positiveAngle >= 5.0 && positiveAngle <= 90.0 {
            return .above      // Follow-through
        } else if (positiveAngle >= 355.0 && positiveAngle <= 360.0) || 
                  (positiveAngle >= 0.0 && positiveAngle <= 5.0) {
            return .deadZone   // Transition buffer around 0°
        } else {
            return .unknown    // Outside typical tennis forearm range
        }
    }
    
    func reset() {
        previousState = .unknown
        lastBeepTime = Date.distantPast
    }
}