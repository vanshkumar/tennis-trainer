import AVFoundation
import SwiftUI

class AudioManager: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var beepBuffer: AVAudioPCMBuffer?
    
    init() {
        setupAudio()
    }
    
    private func setupAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            
            audioEngine = AVAudioEngine()
            playerNode = AVAudioPlayerNode()
            
            guard let audioEngine = audioEngine, let playerNode = playerNode else { return }
            
            audioEngine.attach(playerNode)
            
            let format = audioEngine.outputNode.outputFormat(forBus: 0)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
            
            createBeepBuffer()
            
            try audioEngine.start()
        } catch {
            print("Audio setup error: \(error)")
        }
    }
    
    private func createBeepBuffer() {
        guard let audioEngine = audioEngine else { return }
        
        let format = audioEngine.outputNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * 0.2)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        
        buffer.frameLength = frameCount
        
        let frequency: Float = 800.0
        let amplitude: Float = 0.3
        
        for frame in 0..<Int(frameCount) {
            let value = sin(2.0 * Float.pi * frequency * Float(frame) / Float(sampleRate)) * amplitude
            buffer.floatChannelData?[0][frame] = value
            
            if buffer.format.channelCount > 1 {
                buffer.floatChannelData?[1][frame] = value
            }
        }
        
        beepBuffer = buffer
    }
    
    func playBeep() {
        guard let playerNode = playerNode,
              let beepBuffer = beepBuffer,
              let audioEngine = audioEngine,
              audioEngine.isRunning else { return }
        
        playerNode.scheduleBuffer(beepBuffer, at: nil, options: [], completionHandler: nil)
        
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
    
    deinit {
        audioEngine?.stop()
    }
}