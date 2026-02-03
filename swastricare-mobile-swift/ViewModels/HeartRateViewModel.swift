//
//  HeartRateViewModel.swift
//  swastricare-mobile-swift
//
//  ViewModel for camera-based heart rate measurement
//

import Foundation
import Combine
import AVFoundation
import UIKit

@MainActor
final class HeartRateViewModel: ObservableObject {
    
    // MARK: - Constants
    
    static let measurementDuration: TimeInterval = 30.0
    
    // MARK: - Published State
    
    @Published private(set) var bpm: Int = 0
    @Published private(set) var signalQuality: SignalQuality = .poor
    @Published private(set) var progress: Float = 0
    @Published private(set) var isRunning = false
    @Published private(set) var measurementPhase: MeasurementPhase = .idle
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
    
    // Track first BPM detection for accessibility
    private var hasAnnouncedFirstBPM = false
    
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
        measurementPhase = .preparing
        hasAnnouncedFirstBPM = false
        detector.startMeasurement()
        
        // Accessibility announcement
        announceForAccessibility("Heart rate measurement started. Place your finger on the camera.")
    }
    
    func stopMeasurement() {
        detector.stopMeasurement()
        isRunning = false
        measurementPhase = .idle
        
        // Accessibility announcement
        announceForAccessibility("Measurement stopped")
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
        let timestamp = Date()
        
        let reading = HeartRateReading(
            bpm: bpm,
            timestamp: timestamp,
            confidence: confidence,
            deviceUsed: "iPhone Camera (PPG)"
        )
        
        // Always persist locally so History/Analytics can work offline.
        HeartRateLocalStorage.shared.saveLastMeasured(bpm: bpm, date: timestamp)
        HeartRateLocalStorage.shared.appendMeasurement(
            bpm: bpm,
            date: timestamp,
            confidence: confidence,
            deviceUsed: "iPhone Camera (PPG)",
            source: "camera"
        )
        
        do {
            // Save to Supabase
            _ = try await vitalSignsService.saveHeartRate(reading)
            
            // Always save to HealthKit so it appears in vitals (HomeView reads from HealthKit)
            do {
                try await vitalSignsService.saveToHealthKit(bpm: bpm, date: Date())
            } catch {
                // Don't fail the whole save if HealthKit fails (e.g. permission denied)
                print("HealthKit save failed: \(error)")
            }

            saveSuccess = true
            AppAnalyticsService.shared.logHeartbeatMeasurement(bpm: bpm, source: "camera")
            
            // Accessibility announcement
            announceForAccessibility("Heart rate reading saved successfully")
            
            // Auto-dismiss after successful save
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            showResult = false
            resetState()
            
        } catch {
            saveError = error.localizedDescription
            AppAnalyticsService.shared.logFailure(context: "heartbeat", type: "save_failed", message: error.localizedDescription)
            announceForAccessibility("Failed to save reading: \(error.localizedDescription)")
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
        measurementPhase = .idle
        hasAnnouncedFirstBPM = false
    }
    
    private func updateMeasurementPhase() {
        guard isRunning else {
            measurementPhase = .idle
            return
        }
        
        let newPhase: MeasurementPhase
        if progress < 0.07 {
            newPhase = .preparing
        } else if progress < 0.17 {
            newPhase = .calibrating
        } else if progress > 0.90 {
            newPhase = .completing
        } else {
            newPhase = .measuring
        }
        
        // Announce phase changes for accessibility
        if newPhase != measurementPhase {
            measurementPhase = newPhase
            
            switch newPhase {
            case .calibrating:
                announceForAccessibility("Calibrating signal")
            case .measuring:
                if bpm > 0 {
                    announceForAccessibility("Measuring heart rate")
                }
            case .completing:
                announceForAccessibility("Almost done, \(Int((1 - progress) * Float(Self.measurementDuration))) seconds remaining")
            default:
                break
            }
        }
    }
    
    private func announceForAccessibility(_ message: String) {
        // Post accessibility notification for VoiceOver users
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - HeartRateDetectorDelegate

extension HeartRateViewModel: HeartRateDetectorDelegate {
    
    nonisolated func heartRateDetector(_ detector: HeartRateDetector, didUpdateBPM bpm: Int) {
        Task { @MainActor in
            let previousBPM = self.bpm
            self.bpm = bpm
            self.bpmReadings.append(bpm)
            
            // Announce first BPM detection for accessibility
            if !hasAnnouncedFirstBPM && bpm > 0 {
                hasAnnouncedFirstBPM = true
                announceForAccessibility("Heart rate detected: \(bpm) beats per minute")
            }
            
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
            let previousQuality = self.signalQuality
            self.signalQuality = quality
            
            // Provide immediate feedback if signal is lost
            if quality == .poor {
                self.bpm = 0
                
                // Announce signal loss for accessibility (but not too frequently)
                if previousQuality != .poor {
                    announceForAccessibility("Signal lost. Place finger on camera.")
                }
            } else if previousQuality == .poor && quality != .poor {
                announceForAccessibility("Signal detected")
            }
        }
    }
    
    nonisolated func heartRateDetector(_ detector: HeartRateDetector, didUpdateProgress progress: Float) {
        Task { @MainActor in
            self.progress = progress
            self.updateMeasurementPhase()
        }
    }
    
    nonisolated func heartRateDetectorDidFinish(_ detector: HeartRateDetector, averageBPM: Int) {
        Task { @MainActor in
            self.isRunning = false
            self.measurementPhase = .idle
            
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
                
                // Accessibility announcement
                let categoryText = self.bpmCategory?.description ?? ""
                announceForAccessibility("Measurement complete. Your heart rate is \(self.finalBPM ?? 0) beats per minute. \(categoryText)")
            } else {
                self.errorMessage = "Signal too noisy. Keep finger steady and retry with firm coverage."
                announceForAccessibility("Measurement failed. Signal was too noisy. Please try again.")
            }
        }
    }
    
    nonisolated func heartRateDetector(_ detector: HeartRateDetector, didEncounterError error: HeartRateError) {
        Task { @MainActor in
            self.isRunning = false
            self.measurementPhase = .idle
            self.errorMessage = error.localizedDescription
            
            announceForAccessibility("Error: \(error.localizedDescription)")
        }
    }
}
