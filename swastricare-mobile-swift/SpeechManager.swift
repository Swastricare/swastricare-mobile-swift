//
//  SpeechManager.swift
//  swastricare-mobile-swift
//
//  Created by AI Assistant on 06/01/26.
//

import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class SpeechManager: NSObject, ObservableObject {
    static let shared = SpeechManager()
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isSpeaking = false
    @Published var recognizedText = ""
    @Published var errorMessage: String?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    // MARK: - Speech Recognition Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Text-to-Speech Properties
    private let synthesizer = AVSpeechSynthesizer()
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - Authorization
    
    func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Speech-to-Text
    
    func startRecording() async throws {
        // Check authorization
        if authorizationStatus != .authorized {
            let authorized = await requestSpeechAuthorization()
            guard authorized else {
                throw SpeechError.notAuthorized
            }
        }
        
        let micAuthorized = await requestMicrophoneAuthorization()
        guard micAuthorized else {
            throw SpeechError.microphoneNotAuthorized
        }
        
        // Cancel previous task if any
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Get audio input node
        let inputNode = audioEngine.inputNode
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                }
                
                if error != nil || result?.isFinal == true {
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    self.isRecording = false
                }
            }
        }
        
        // Configure audio tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        recognizedText = ""
        errorMessage = nil
        
        print("🎤 Started recording")
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
        print("🎤 Stopped recording")
    }
    
    // MARK: - Text-to-Speech
    
    func speak(_ text: String, rate: Float = 0.5, voice: AVSpeechSynthesisVoice? = nil) {
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Use specified voice or default
        if let voice = voice {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        isSpeaking = true
        synthesizer.speak(utterance)
        
        print("🔊 Speaking: \(text.prefix(50))...")
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        print("🔊 Stopped speaking")
    }
    
    func pauseSpeaking() {
        synthesizer.pauseSpeaking(at: .word)
    }
    
    func continueSpeaking() {
        synthesizer.continueSpeaking()
    }
    
    // MARK: - Utility
    
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: "en") }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            print("🔊 Finished speaking")
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            print("🔊 Cancelled speaking")
        }
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case notAuthorized
    case microphoneNotAuthorized
    case unableToCreateRequest
    case recognitionFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in Settings."
        case .microphoneNotAuthorized:
            return "Microphone access not authorized. Please enable in Settings."
        case .unableToCreateRequest:
            return "Unable to create speech recognition request."
        case .recognitionFailed:
            return "Speech recognition failed. Please try again."
        }
    }
}
