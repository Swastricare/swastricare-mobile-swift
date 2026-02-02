//
//  SignalValidator.swift
//  swastricare-mobile-swift
//
//  Validation utilities for heart rate signal quality and BPM readings
//

import Foundation

// MARK: - Signal Validator

struct SignalValidator {
    
    // MARK: - BPM Validation
    
    /// Validate if BPM reading is physiologically plausible with extended error bounds
    static func isValidBPM(_ bpm: Int) -> Bool {
        // Absolute physiological limits (survival possible but rare outside this)
        // Neonates can be up to 190, athletes down to 30.
        // For general adult population app context:
        return bpm >= 30 && bpm <= 220
    }
    
    /// Validate if BPM is in expected resting range for adults
    static func isRestingBPM(_ bpm: Int) -> Bool {
        return bpm >= 40 && bpm <= 100
    }
    
    /// Get BPM category description
    static func bpmCategory(_ bpm: Int) -> BPMCategory {
        switch bpm {
        case ..<50:
            return .low
        case 50..<60:
            return .athlete
        case 60..<100:
            return .normal
        case 100..<120:
            return .elevated
        case 120...:
            return .high
        default:
            return .normal
        }
    }
    
    // MARK: - Confidence Calculation
    
    /// Calculate confidence score for a series of BPM readings with outlier removal
    static func calculateConfidence(readings: [Int], signalQualityScore: Double = 1.0) -> Double {
        guard readings.count >= 5 else { return 0.0 }
        
        // Remove outliers using IQR method
        let sorted = readings.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4
        
        let q1 = Double(sorted[q1Index])
        let q3 = Double(sorted[q3Index])
        let iqr = q3 - q1
        
        // Only remove extreme outliers (3 * IQR instead of 1.5)
        let lowerBound = q1 - (3.0 * iqr)
        let upperBound = q3 + (3.0 * iqr)
        
        let cleanedReadings = readings.filter { Double($0) >= lowerBound && Double($0) <= upperBound }
        
        guard cleanedReadings.count >= 5 else { return 0.0 }
        
        // Calculate statistics on cleaned data
        let mean = Double(cleanedReadings.reduce(0, +)) / Double(cleanedReadings.count)
        let variance = cleanedReadings.map { pow(Double($0) - mean, 2) }.reduce(0, +) / Double(cleanedReadings.count)
        let stdDev = sqrt(variance)
        
        // Coefficient of variation (CV) - normalized measure of variability
        let cv = stdDev / mean
        
        // Number of readings factor (more readings = higher confidence)
        let countFactor = min(1.0, Double(cleanedReadings.count) / 20.0)
        
        // Consistency score based on stdDev (lower is better)
        // StdDev of 1-2 BPM = excellent, 5+ = poor
        let consistencyScore = max(0, min(1, 1 - (stdDev / 8.0)))
        
        // CV-based score (lower CV = more stable signal)
        let cvScore = max(0, min(1, 1 - (cv * 20.0)))
        
        // Combine factors: weighted average
        let baseConfidence = (consistencyScore * 0.5 + cvScore * 0.3 + countFactor * 0.2)
        
        // Apply signal quality multiplier
        let finalConfidence = baseConfidence * signalQualityScore
        
        // Cap confidence at 99% (0.99) to indicate margin of error
        // Never return 100% confidence for camera PPG
        return max(0, min(0.99, finalConfidence))
    }
    
    /// Get confidence level description
    static func confidenceDescription(_ confidence: Double) -> String {
        switch confidence {
        case 0.85...1.0:
            return "Very High Confidence"
        case 0.7..<0.85:
            return "High Confidence"
        case 0.5..<0.7:
            return "Moderate Confidence"
        case 0.3..<0.5:
            return "Low Confidence"
        default:
            return "Very Low Confidence"
        }
    }
    
    /// Get confidence level enum
    static func confidenceLevel(_ confidence: Double) -> ConfidenceLevel {
        switch confidence {
        case 0.85...1.0:
            return .veryHigh
        case 0.7..<0.85:
            return .high
        case 0.5..<0.7:
            return .moderate
        case 0.3..<0.5:
            return .low
        default:
            return .veryLow
        }
    }
    
    // MARK: - Reading Validation
    
    /// Filter out invalid readings from a set
    static func filterValidReadings(_ readings: [Int]) -> [Int] {
        return readings.filter { isValidBPM($0) }
    }
    
    /// Calculate validated average BPM with outlier removal
    static func calculateValidatedAverageBPM(_ readings: [Int]) -> Int? {
        let validReadings = filterValidReadings(readings)
        guard validReadings.count >= 3 else { return nil }
        
        // Remove outliers using IQR method
        let sorted = validReadings.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4
        
        let q1 = Double(sorted[q1Index])
        let q3 = Double(sorted[q3Index])
        let iqr = q3 - q1
        
        let lowerBound = q1 - (1.5 * iqr)
        let upperBound = q3 + (1.5 * iqr)
        
        let filteredReadings = validReadings.filter { Double($0) >= lowerBound && Double($0) <= upperBound }
        
        guard !filteredReadings.isEmpty else { return nil }
        
        return filteredReadings.reduce(0, +) / filteredReadings.count
    }
    
    // MARK: - Error Bounds Calculation (Production)
    
    /// Calculate error bounds (±X BPM) for a set of readings
    /// Returns (minBPM, maxBPM, errorMargin) tuple
    static func calculateErrorBounds(_ readings: [Int]) -> (min: Int, max: Int, margin: Int)? {
        let validReadings = filterValidReadings(readings)
        guard validReadings.count >= 5 else { return nil }
        
        // Remove outliers first
        let sorted = validReadings.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4
        
        let q1 = Double(sorted[q1Index])
        let q3 = Double(sorted[q3Index])
        let iqr = q3 - q1
        
        let lowerBound = q1 - (1.5 * iqr)
        let upperBound = q3 + (1.5 * iqr)
        
        let cleanedReadings = validReadings.filter { Double($0) >= lowerBound && Double($0) <= upperBound }
        guard cleanedReadings.count >= 3 else { return nil }
        
        let cleanedSorted = cleanedReadings.sorted()
        
        // Calculate statistics
        let mean = Double(cleanedReadings.reduce(0, +)) / Double(cleanedReadings.count)
        let variance = cleanedReadings.map { pow(Double($0) - mean, 2) }.reduce(0, +) / Double(cleanedReadings.count)
        let stdDev = sqrt(variance)
        
        // Error margin based on standard deviation
        // Use 1.5 * stdDev for ~87% confidence interval
        // Minimum error margin of 2 BPM (inherent sensor limitation)
        let calculatedMargin = Int(ceil(stdDev * 1.5))
        let errorMargin = max(2, min(calculatedMargin, 10)) // Cap at ±10 BPM
        
        // Min/Max from actual cleaned data
        let minBPM = cleanedSorted.first ?? 0
        let maxBPM = cleanedSorted.last ?? 0
        
        return (min: minBPM, max: maxBPM, margin: errorMargin)
    }
    
    /// Get human-readable error description
    static func errorBoundsDescription(_ readings: [Int], averageBPM: Int) -> String {
        guard let bounds = calculateErrorBounds(readings) else {
            return "±5 BPM (estimated)"
        }
        return "±\(bounds.margin) BPM"
    }
}

// MARK: - Motion Detector

class MotionDetector {
    
    private var previousValues: [Double] = []
    private let windowSize = 10
    
    /// Detect excessive motion that could corrupt the signal
    func isMotionExcessive(newValue: Double) -> Bool {
        previousValues.append(newValue)
        
        if previousValues.count > windowSize {
            previousValues.removeFirst()
        }
        
        guard previousValues.count == windowSize else { return false }
        
        // Calculate rate of change
        var derivatives: [Double] = []
        for i in 1..<previousValues.count {
            derivatives.append(abs(previousValues[i] - previousValues[i-1]))
        }
        
        let avgDerivative = derivatives.reduce(0, +) / Double(derivatives.count)
        
        // Threshold for excessive motion
        // 20.0 allows normal pulsation (~5-10) but filters out hand movement
        // Increased from 15.0 to be less sensitive and avoid false rejections
        return avgDerivative > 20.0
    }
    
    func reset() {
        previousValues.removeAll()
    }
}

// MARK: - Supporting Types

enum BPMCategory {
    case low
    case athlete
    case normal
    case elevated
    case high
    
    var description: String {
        switch self {
        case .low:
            return "Low (Bradycardia)"
        case .athlete:
            return "Athletic Range"
        case .normal:
            return "Normal"
        case .elevated:
            return "Elevated"
        case .high:
            return "High (Tachycardia)"
        }
    }
    
    var emoji: String {
        switch self {
        case .low:
            return "⚠️"
        case .athlete:
            return "💪"
        case .normal:
            return "✅"
        case .elevated:
            return "⚡"
        case .high:
            return "⚠️"
        }
    }
}

enum ConfidenceLevel {
    case veryLow
    case low
    case moderate
    case high
    case veryHigh
    
    var description: String {
        switch self {
        case .veryLow:
            return "Very Low"
        case .low:
            return "Low"
        case .moderate:
            return "Moderate"
        case .high:
            return "High"
        case .veryHigh:
            return "Very High"
        }
    }
}

// MARK: - Heart Rate Reading Model

struct HeartRateReading: Identifiable, Codable {
    let id: UUID
    let bpm: Int
    let timestamp: Date
    let confidence: Double
    let quality: String
    let deviceUsed: String
    
    init(
        id: UUID = UUID(),
        bpm: Int,
        timestamp: Date = Date(),
        confidence: Double,
        quality: String = "camera_ppg",
        deviceUsed: String = "iPhone Camera (PPG)"
    ) {
        self.id = id
        self.bpm = bpm
        self.timestamp = timestamp
        self.confidence = confidence
        self.quality = quality
        self.deviceUsed = deviceUsed
    }
    
    var isValid: Bool {
        SignalValidator.isValidBPM(bpm)
    }
    
    var category: BPMCategory {
        SignalValidator.bpmCategory(bpm)
    }
    
    var confidenceLevel: ConfidenceLevel {
        SignalValidator.confidenceLevel(confidence)
    }
}
