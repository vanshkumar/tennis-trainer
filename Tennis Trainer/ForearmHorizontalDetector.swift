import Foundation

class ForearmHorizontalDetector {
    private var wasHorizontal = false
    private var lastBeepTime: Date = Date.distantPast
    
    private let threshold = 10.0 // degrees tolerance
    private let cooldownSeconds = 1.0 // minimum time between beeps
    
    func checkForearmHorizontal(forearmAngle: Double) -> Bool {
        // Check if forearm is horizontal (0° or 180° ± threshold)
        let isHorizontalRight = abs(forearmAngle - 0) <= threshold
        let isHorizontalLeft = abs(forearmAngle - 180) <= threshold
        let isCurrentlyHorizontal = isHorizontalRight || isHorizontalLeft
        
        // Only beep on transition TO horizontal AND respect cooldown
        let shouldBeep = isCurrentlyHorizontal && !wasHorizontal && 
                        Date().timeIntervalSince(lastBeepTime) > cooldownSeconds
        
        if shouldBeep {
            lastBeepTime = Date()
        }
        
        wasHorizontal = isCurrentlyHorizontal
        return shouldBeep
    }
    
    func reset() {
        wasHorizontal = false
        lastBeepTime = Date.distantPast
    }
}