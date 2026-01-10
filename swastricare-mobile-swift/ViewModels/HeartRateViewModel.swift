//
//  HeartRateViewModel.swift
//  swastricare-mobile-swift
//
//  ViewModel for camera-based heart rate measurement
//

import Foundation
import Combine
import AVFoundation

@MainActor
final class HeartRateViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var bpm: Int = 0
    @Published private(set) var signalQuality: SignalQuality = .poor
    @Published private(set) var progress: Float = 0
    @Published private(set) var isRunning = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var finalBPM: Int?
    @Published private(set) var isSaving = false
    @Published private(set) var saveSuccess = false
    @Published private(set) var saveError: String?
    @Published var showResult = false
    @Published var showDisclaimer = false
    
    // BPM readings for confidence calculation
    @Published private(set) var bpmReadings: [Int] = []
    @Published private(set) var confidence: Double = 0
    @Published private(set) var errorMargin: Int = 5 // ±X BPM
    
    // MARK: - Dependencies
    
    private let detector = HeartRateDetector()
    private let vitalSignsService: VitalSignsServiceProtocol
    
    // MARK: - Camera Session
    
    var captureSession: AVCaptureSession? {
        detector.captureSession
    }
    
    // MARK: - Computed Properties
    
    var confidenceDescription: String {
        SignalValidator.confidenceDescription(confidence)
    }
    
    var confidenceLevel: ConfidenceLevel {
        SignalValidator.confidenceLevel(confidence)
    }
    
    var bpmCategory: BPMCategory? {
        guard let bpm = finalBPM else { return nil }
        return SignalValidator.bpmCategory(bpm)
    }
    
    var canSave: Bool {
        finalBPM != nil && !isSaving && SignalValidator.isValidBPM(finalBPM ?? 0)
    }
    
    var instructionText: String {
        if isRunning {
            return "Keep your finger steady on the camera"
        } else if finalBPM != nil {
            return "Measurement complete"
        } else {
            return "Place your fingertip firmly on the rear camera lens"
        }
    }
    
    var errorBoundsText: String {
        return "±\(errorMargin) BPM"
    }
    
    // MARK: - Init
    
    init(vitalSignsService: VitalSignsServiceProtocol = VitalSignsService.shared) {
        self.vitalSignsService = vitalSignsService
        detector.delegate = self
        
        // Show disclaimer on first use
        if !UserDefaults.standard.bool(forKey: "hasSeenHeartRateDisclaimer") {
            showDisclaimer = true
        }
    }
    
    // MARK: - Public Methods
    
    func startMeasurement() {
        resetState()
        isRunning = true
        detector.startMeasurement()
    }
    
    func stopMeasurement() {
        detector.stopMeasurement()
        isRunning = false
    }
    
    func dismissResult() {
        showResult = false
        resetState()
    }
    
    func acceptDisclaimer() {
        UserDefaults.standard.set(true, forKey: "hasSeenHeartRateDisclaimer")
        showDisclaimer = false
    }
    
    func saveReading() async {
        guard let bpm = finalBPM else { return }
        
        isSaving = true
        saveError = nil
        
        let reading = HeartRateReading(
            bpm: bpm,
            confidence: confidence,
            deviceUsed: "iPhone Camera (PPG)"
        )
        
        do {
            // Save to Supabase
            _ = try await vitalSignsService.saveHeartRate(reading)
            
            // Optionally save to HealthKit
            if UserDefaults.standard.bool(forKey: "syncHeartRateToHealthKit") {
                do {
                    try await vitalSignsService.saveToHealthKit(bpm: bpm, date: Date())
                } catch {
                    // Don't fail the whole save if HealthKit fails
                    print("HealthKit save failed: \(error)")
                }
            }
            
            saveSuccess = true
            
            // Auto-dismiss after successful save
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            showResult = false
            resetState()
            
        } catch {
            saveError = error.localizedDescription
        }
        
        isSaving = false
    }
    
    // MARK: - Private Methods
    
    private func resetState() {
        bpm = 0
        progress = 0
        finalBPM = nil
        errorMessage = nil
        bpmReadings.removeAll()
        confidence = 0
        errorMargin = 5
        saveSuccess = false
        saveError = nil
        signalQuality = .poor
    }
}

// MARK: - HeartRateDetectorDelegate

extension HeartRateViewModel: HeartRateDetectorDelegate {
    
    nonisolated func heartRateDetector(_ detector: HeartRateDetector, didUpdateBPM bpm: Int) {
        Task { @MainActor in
            self.bpm = bpm
            self.bpmReadings.append(bpm)
            
            // Calculate running confidence with signal quality factor
            if self.bpmReadings.count >= 5 {
                let qualityScore = signalQualityToScore(self.signalQuality)
                self.confidence = SignalValidator.calculateConfidence(
                    readings: self.bpmReadings,
                    signalQualityScore: qualityScore
                )
            }
        }
    }
    
    private func signalQualityToScore(_ quality: SignalQuality) -> Double {
        switch quality {
        case .excellent: return 1.0
        case .good: return 0.9
        case .fair: return 0.7
        case .poor: return 0.5
        }
    }
    
    nonisolated func heartRateDetector(_ detector: HeartRateDetector, didUpdateSignalQuality quality: SignalQuality) {
        Task { @MainActor in
            self.signalQuality = quality
            // Provide immediate feedback if signal is lost
            if quality == .poor {
                self.bpm = 0
            }
        }
    }
    
    nonisolated func heartRateDetector(_ detector: HeartRateDetector, didUpdateProgress progress: Float) {
        Task { @MainActor in
            self.progress = progress
        }
    }
    
    nonisolated func heartRateDetectorDidFinish(_ detector: HeartRateDetector, averageBPM: Int) {
        Task { @MainActor in
            self.isRunning = false
            
            // Use validated average if we have enough readings
            if let validatedBPM = SignalValidator.calculateValidatedAverageBPM(self.bpmReadings) {
                self.finalBPM = validatedBPM
            } else {
                self.finalBPM = averageBPM
            }
            
            // Calculate final confidence with signal quality
            let qualityScore = signalQualityToScore(self.signalQuality)
            self.confidence = SignalValidator.calculateConfidence(
                readings: self.bpmReadings,
                signalQualityScore: qualityScore
            )
            
            // Calculate error bounds
            if let bounds = SignalValidator.calculateErrorBounds(self.bpmReadings) {
                self.errorMargin = bounds.margin
            } else {
                // Default error margin based on confidence
                self.errorMargin = self.confidence >= 0.7 ? 3 : 5
            }
            
            // Show result if we have acceptable quality
            let hasAcceptableSignal = self.signalQuality == .good || self.signalQuality == .excellent || self.signalQuality == .fair
            let hasAcceptableConfidence = self.confidence >= 0.3
            
            if hasAcceptableSignal && hasAcceptableConfidence {
                self.showResult = true
            } else {
                self.errorMessage = "Signal too noisy. Keep finger steady and retry with firm coverage."
            }
        }
    }
    
    nonisolated func heartRateDetector(_ detector: HeartRateDetector, didEncounterError error: HeartRateError) {
        Task { @MainActor in
            self.isRunning = false
            self.errorMessage = error.localizedDescription
        }
    }
}
