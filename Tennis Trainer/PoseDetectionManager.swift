import Foundation
import Vision
import AVFoundation
import CoreImage

class PoseDetectionManager: ObservableObject {
    @Published var detectedPose: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [:]
    @Published var forearmAngle: Double = 0.0
    @Published var upperArmAngle: Double = 0.0
    
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    
    init() {
        poseRequest.revision = VNDetectHumanBodyPoseRequestRevision1
    }
    
    func detectPose(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .right) {
        // Use provided orientation (default .right for camera, but videos should pass correct orientation)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        
        do {
            try handler.perform([poseRequest])
            
            guard let observation = poseRequest.results?.first else { return }
            
            DispatchQueue.main.async {
                self.processPoseObservation(observation)
            }
        } catch {
            print("Pose detection error: \(error)")
        }
    }
    
    private func processPoseObservation(_ observation: VNHumanBodyPoseObservation) {
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist
        ]
        
        var recognizedPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [:]
        
        for jointName in jointNames {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > 0.3 else { continue }
            
            recognizedPoints[jointName] = point
        }
        
        self.detectedPose = recognizedPoints
        self.calculateAngles()
    }
    
    private func calculateAngles() {
        // Calculate right arm angles (can be modified for left arm or both)
        if let shoulder = detectedPose[.rightShoulder],
           let elbow = detectedPose[.rightElbow],
           let wrist = detectedPose[.rightWrist] {
            
            // Upper arm angle (shoulder to elbow relative to horizontal)
            let upperArmVector = CGPoint(
                x: elbow.location.x - shoulder.location.x,
                y: elbow.location.y - shoulder.location.y
            )
            self.upperArmAngle = angleFromHorizontal(vector: upperArmVector)
            
            // Forearm angle (elbow to wrist relative to horizontal)
            let forearmVector = CGPoint(
                x: wrist.location.x - elbow.location.x,
                y: wrist.location.y - elbow.location.y
            )
            self.forearmAngle = angleFromHorizontal(vector: forearmVector)
            
//            print("Shoulder: (\(String(format: "%.3f", shoulder.location.x)), \(String(format: "%.3f", shoulder.location.y))) conf: \(String(format: "%.2f", shoulder.confidence))")
//            print("Elbow: (\(String(format: "%.3f", elbow.location.x)), \(String(format: "%.3f", elbow.location.y))) conf: \(String(format: "%.2f", elbow.confidence))")
//            print("Wrist: (\(String(format: "%.3f", wrist.location.x)), \(String(format: "%.3f", wrist.location.y))) conf: \(String(format: "%.2f", wrist.confidence))")
//            print("Forearm vector: (\(String(format: "%.3f", forearmVector.x)), \(String(format: "%.3f", forearmVector.y)))")
//            print("Updated angles - Forearm: \(String(format: "%.1f", forearmAngle))°, Upper: \(String(format: "%.1f", upperArmAngle))°")
        } else {
            print("Missing keypoints - Shoulder: \(detectedPose[.rightShoulder] != nil), Elbow: \(detectedPose[.rightElbow] != nil), Wrist: \(detectedPose[.rightWrist] != nil)")
        }
    }
    
    private func angleFromHorizontal(vector: CGPoint) -> Double {
        // Vision coordinates: Origin at bottom-left, Y increases upward (standard math coordinates)
        // Standard formula: angle from positive X-axis (horizontal right)
        let radians = atan2(vector.y, vector.x)
        var degrees = radians * 180.0 / .pi
        
        // Normalize to 0-360°
        if degrees < 0 {
            degrees += 360
        }
        
        return degrees
    }
    
    func getJointPosition(for jointName: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        return detectedPose[jointName]?.location
    }
    
    func getJointConfidence(for jointName: VNHumanBodyPoseObservation.JointName) -> Float? {
        return detectedPose[jointName]?.confidence
    }
}
