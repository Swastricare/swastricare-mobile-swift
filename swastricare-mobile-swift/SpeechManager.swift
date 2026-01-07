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
    
    // MARK: - Speech Recognition Properties (Lazy)
    private lazy var speechRecognizer: SFSpeechRecognizer? = {
        SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private lazy var audioEngine: AVAudioEngine = AVAudioEngine()
    
    // MARK: - Text-to-Speech Properties (Lazy)
    private lazy var synthesizer: AVSpeechSynthesizer = {
        let synth = AVSpeechSynthesizer()
        synth.delegate = self
        return synth
    }()
    
    private override init() {
        super.init()
        // Don't initialize speech services until needed
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
        // Check if already recording
        if isRecording {
            stopRecording()
            return
        }
        
        // Check speech recognizer availability
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognitionFailed
        }
        
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
        
        // Stop audio engine if running
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Audio session setup failed: \(error)")
            throw SpeechError.unableToCreateRequest
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Get audio input node
        let inputNode = audioEngine.inputNode
        
        // Get the recording format - use a safe format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate format (sample rate must be > 0)
        guard recordingFormat.sampleRate > 0 else {
            print("⚠️ Invalid audio format: sample rate is 0")
            throw SpeechError.unableToCreateRequest
        }
        
        // Remove any existing tap
        inputNode.removeTap(onBus: 0)
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                }
                
                if error != nil || result?.isFinal == true {
                    self.cleanupRecording()
                }
            }
        }
        
        // Configure audio tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("⚠️ Audio engine failed to start: \(error)")
            cleanupRecording()
            throw SpeechError.recognitionFailed
        }
        
        isRecording = true
        recognizedText = ""
        errorMessage = nil
        
        print("🎤 Started recording")
    }
    
    private func cleanupRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        cleanupRecording()
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
