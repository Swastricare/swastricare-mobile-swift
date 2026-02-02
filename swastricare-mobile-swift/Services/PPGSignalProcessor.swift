//
//  PPGSignalProcessor.swift
//  swastricare-mobile-swift
//
//  Signal processing for photoplethysmography (PPG) heart rate detection
//

import Foundation
import Accelerate

// MARK: - PPG Signal Processor

class PPGSignalProcessor {
    
    // MARK: - Bandpass Filter
    
    /// Butterworth bandpass filter for isolating heart rate frequencies
    /// Passband: 0.67 Hz - 3.5 Hz (40 - 210 BPM) - wider range for better accuracy
    static func bandpassFilter(signal: [Double], sampleRate: Double) -> [Double] {
        guard signal.count > 10 else { return signal }
        
        // Remove DC component (mean) - critical for PPG
        let mean = signal.reduce(0, +) / Double(signal.count)
        let centered = signal.map { $0 - mean }
        
        // Low-pass filter (cutoff: 3.5 Hz for up to 210 BPM)
        let lowPassed = lowPassFilter(signal: centered, cutoff: 3.5, sampleRate: sampleRate)
        
        // High-pass filter (cutoff: 0.67 Hz for down to 40 BPM)
        let bandPassed = highPassFilter(signal: lowPassed, cutoff: 0.67, sampleRate: sampleRate)
        
        return bandPassed
    }
    
    private static func lowPassFilter(signal: [Double], cutoff: Double, sampleRate: Double) -> [Double] {
        let rc = 1.0 / (2.0 * .pi * cutoff)
        let dt = 1.0 / sampleRate
        let alpha = dt / (rc + dt)
        
        var filtered = [Double](repeating: 0, count: signal.count)
        filtered[0] = signal[0]
        
        for i in 1..<signal.count {
            filtered[i] = filtered[i-1] + alpha * (signal[i] - filtered[i-1])
        }
        
        return filtered
    }
    
    private static func highPassFilter(signal: [Double], cutoff: Double, sampleRate: Double) -> [Double] {
        let rc = 1.0 / (2.0 * .pi * cutoff)
        let dt = 1.0 / sampleRate
        let alpha = rc / (rc + dt)
        
        var filtered = [Double](repeating: 0, count: signal.count)
        filtered[0] = signal[0]
        
        for i in 1..<signal.count {
            filtered[i] = alpha * (filtered[i-1] + signal[i] - signal[i-1])
        }
        
        return filtered
    }
    
    // MARK: - Peak Detection
    
    /// Find peaks in the filtered signal using adaptive threshold with improved accuracy
    static func findPeaks(signal: [Double], minDistance: Int = 10) -> [Int] {
        guard signal.count > 2 else { return [] }
        
        var peaks: [Int] = []
        
        // Calculate signal statistics
        let maxVal = signal.max() ?? 0
        let minVal = signal.min() ?? 0
        let range = maxVal - minVal
        
        guard range > 0 else { return [] }
        
        // Calculate mean for adaptive thresholding
        let mean = signal.reduce(0, +) / Double(signal.count)
        
        // Adaptive threshold: use mean + 30% of range (more sensitive to actual pulse peaks)
        // This works better than fixed 50% threshold for varying signal amplitudes
        let threshold = mean + (range * 0.3)
        
        // Use wider window for local maximum detection (more robust)
        let lookAhead = 2
        
        for i in lookAhead..<(signal.count - lookAhead) {
            // Check if local maximum in wider window and above threshold
            var isLocalMax = signal[i] > threshold
            
            // Verify it's higher than all points in lookAhead window
            if isLocalMax {
                for j in 1...lookAhead {
                    if signal[i] <= signal[i-j] || signal[i] <= signal[i+j] {
                        isLocalMax = false
                        break
                    }
                }
            }
            
            if isLocalMax {
                // Check minimum distance from last peak
                if peaks.isEmpty || (i - peaks.last!) >= minDistance {
                    peaks.append(i)
                } else if let lastPeakIdx = peaks.last, signal[i] > signal[lastPeakIdx] {
                    // Replace with higher peak if within minDistance
                    peaks[peaks.count - 1] = i
                }
            }
        }
        
        return peaks
    }
    
    // MARK: - Heart Rate Calculation
    
    /// Calculate BPM from peak intervals with improved outlier rejection
    static func calculateBPM(peaks: [Int], sampleRate: Double) -> Int? {
        guard peaks.count >= 3 else { return nil }
        
        // Calculate intervals between consecutive peaks
        var intervals: [Double] = []
        for i in 1..<peaks.count {
            let interval = Double(peaks[i] - peaks[i-1]) / sampleRate
            intervals.append(interval)
        }
        
        // Remove outliers (intervals outside physiological range: 40-200 BPM)
        let validIntervals = intervals.filter { interval in
            let bpm = 60.0 / interval
            return bpm >= 40 && bpm <= 200
        }
        
        guard validIntervals.count >= 2 else { return nil }
        
        // Use IQR method for additional outlier removal if we have enough data
        var cleanedIntervals = validIntervals
        if validIntervals.count >= 5 {
            let sorted = validIntervals.sorted()
            let q1 = sorted[sorted.count / 4]
            let q3 = sorted[(sorted.count * 3) / 4]
            let iqr = q3 - q1
            
            let lowerBound = q1 - (1.5 * iqr)
            let upperBound = q3 + (1.5 * iqr)
            
            cleanedIntervals = validIntervals.filter { $0 >= lowerBound && $0 <= upperBound }
        }
        
        guard !cleanedIntervals.isEmpty else { return nil }
        
        // Calculate median interval (more robust than mean for PPG)
        let sortedIntervals = cleanedIntervals.sorted()
        let medianInterval = sortedIntervals[sortedIntervals.count / 2]
        
        let bpm = 60.0 / medianInterval
        return Int(bpm.rounded())
    }
    
    // MARK: - FFT-Based BPM Calculation (Alternative Method)
    
    /// Calculate BPM using Fast Fourier Transform
    /// Can be more robust for noisy signals
    static func calculateBPMWithFFT(signal: [Double], sampleRate: Double) -> Int? {
        guard signal.count >= 64 else { return nil }
        
        // Ensure signal length is a power of 2 for FFT
        let log2n = vDSP_Length(floor(log2(Double(signal.count))))
        let n = Int(pow(2.0, Double(log2n)))
        
        guard n >= 64 else { return nil }
        
        // Prepare signal (truncate to power of 2)
        var real = Array(signal.prefix(n))
        var imaginary = [Double](repeating: 0, count: n)
        
        // Create FFT setup
        guard let fft = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return nil
        }
        defer { vDSP_destroy_fftsetupD(fft) }
        
        // Perform FFT using withUnsafeMutableBufferPointer for memory safety
        var magnitudes = [Double](repeating: 0, count: n / 2)
        
        real.withUnsafeMutableBufferPointer { realBuffer in
            imaginary.withUnsafeMutableBufferPointer { imagBuffer in
                var splitComplex = DSPDoubleSplitComplex(
                    realp: realBuffer.baseAddress!,
                    imagp: imagBuffer.baseAddress!
                )
                vDSP_fft_zipD(fft, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                
                // Calculate magnitudes
                magnitudes.withUnsafeMutableBufferPointer { magBuffer in
                    vDSP_zvmagsD(&splitComplex, 1, magBuffer.baseAddress!, 1, vDSP_Length(n / 2))
                }
            }
        }
        
        // Find peak frequency in heart rate range (0.67-3.5 Hz = 40-210 BPM)
        let freqResolution = sampleRate / Double(n)
        let minBin = max(1, Int(0.67 / freqResolution))
        let maxBin = min(n / 2 - 1, Int(3.5 / freqResolution))
        
        guard minBin < maxBin else { return nil }
        
        var maxMag: Double = 0
        var maxIndex = 0
        
        for i in minBin..<maxBin {
            if magnitudes[i] > maxMag {
                maxMag = magnitudes[i]
                maxIndex = i
            }
        }
        
        guard maxIndex > 0 else { return nil }
        
        let peakFrequency = Double(maxIndex) * freqResolution
        let bpm = peakFrequency * 60.0
        
        return Int(bpm.rounded())
    }
    
    // MARK: - Combined BPM Calculation
    
    /// Combines peak detection, FFT, and autocorrelation for best accuracy
    static func calculateCombinedBPM(signal: [Double], sampleRate: Double, minSamples: Int) -> Int? {
        guard signal.count >= minSamples else { return nil }
        
        // Apply bandpass filter
        let filtered = bandpassFilter(signal: signal, sampleRate: sampleRate)
        
        // Method 1: Peak detection
        let minPeakDistance = Int(sampleRate * 0.33)
        let peaks = findPeaks(signal: filtered, minDistance: max(minPeakDistance, 1))
        let peakBPM = calculateBPM(peaks: peaks, sampleRate: sampleRate)
        
        // Method 2: FFT
        let fftBPM = calculateBPMWithFFT(signal: filtered, sampleRate: sampleRate)
        
        // Method 3: Autocorrelation (most accurate for PPG)
        let acBPM = calculateBPMWithAutocorrelation(signal: filtered, sampleRate: sampleRate)
        
        // Validate all results (40-200 BPM range - wider for better coverage)
        let validPeak = peakBPM.flatMap { ($0 >= 40 && $0 <= 200) ? $0 : nil }
        let validFFT = fftBPM.flatMap { ($0 >= 40 && $0 <= 200) ? $0 : nil }
        let validAC = acBPM.flatMap { ($0 >= 40 && $0 <= 200) ? $0 : nil }
        
        // Collect all valid results
        var validResults: [Int] = []
        if let v = validPeak { validResults.append(v) }
        if let v = validFFT { validResults.append(v) }
        if let v = validAC { validResults.append(v) }
        
        guard !validResults.isEmpty else { return nil }
        
        // If only one method worked, use it
        if validResults.count == 1 {
            return validResults[0]
        }
        
        // If autocorrelation agrees with any other method (within 10 BPM), prefer their average
        if let ac = validAC {
            if let peak = validPeak, abs(ac - peak) <= 10 {
                return (ac + peak) / 2
            }
            if let fft = validFFT, abs(ac - fft) <= 10 {
                return (ac + fft) / 2
            }
        }
        
        // If peak and FFT agree, use their average
        if let peak = validPeak, let fft = validFFT, abs(peak - fft) <= 10 {
            return (peak + fft) / 2
        }
        
        // If all three exist but disagree, use median
        if validResults.count == 3 {
            let sorted = validResults.sorted()
            return sorted[1]  // Median
        }
        
        // If two methods exist but disagree, prefer autocorrelation, then the higher value
        // (PPG often undercounts due to missed peaks)
        if let ac = validAC {
            return ac
        }
        
        return validResults.max()
    }
    
    // MARK: - Autocorrelation BPM (Most Accurate for PPG)
    
    /// Calculate BPM using autocorrelation with improved accuracy
    /// Uses proper normalization and parabolic interpolation for sub-sample precision
    static func calculateBPMWithAutocorrelation(signal: [Double], sampleRate: Double) -> Int? {
        guard signal.count >= 128 else { return nil }
        
        // Normalize signal to zero mean, unit variance
        let mean = signal.reduce(0, +) / Double(signal.count)
        let centered = signal.map { $0 - mean }
        
        // Calculate standard deviation for normalization
        let variance = centered.map { $0 * $0 }.reduce(0, +) / Double(centered.count)
        let stdDev = sqrt(variance)
        guard stdDev > 0 else { return nil }
        
        let normalized = centered.map { $0 / stdDev }
        
        // Calculate autocorrelation for lags corresponding to 40-200 BPM (wider range)
        let minLag = Int(sampleRate * 60.0 / 200.0)  // 200 BPM
        let maxLag = min(Int(sampleRate * 60.0 / 40.0), normalized.count / 2)  // 40 BPM
        
        guard maxLag > minLag else { return nil }
        
        // Store correlation values for interpolation
        var correlations = [Double](repeating: 0, count: maxLag - minLag + 1)
        
        // Calculate normalized autocorrelation
        for lag in minLag...maxLag {
            var correlation: Double = 0
            let n = normalized.count - lag
            
            for i in 0..<n {
                correlation += normalized[i] * normalized[i + lag]
            }
            
            // Biased autocorrelation (normalized by total length, not overlap)
            // This gives better results for PPG signals
            correlations[lag - minLag] = correlation / Double(normalized.count)
        }
        
        // Find the peak correlation (ignoring first few lags which are always high)
        let searchStart = max(0, minLag)
        var maxCorrelation: Double = -1.0
        var bestLag = 0
        
        for lag in searchStart...maxLag {
            let corrValue = correlations[lag - minLag]
            if corrValue > maxCorrelation {
                maxCorrelation = corrValue
                bestLag = lag
            }
        }
        
        guard bestLag > minLag && maxCorrelation > 0.1 else { return nil }
        
        // Parabolic interpolation for sub-sample accuracy
        // This significantly improves BPM precision
        var refinedLag = Double(bestLag)
        
        if bestLag > minLag && bestLag < maxLag {
            let prevCorr = correlations[bestLag - minLag - 1]
            let currCorr = correlations[bestLag - minLag]
            let nextCorr = correlations[bestLag - minLag + 1]
            
            // Parabolic fit: y = a(x-p)^2 + b
            // Peak at: p = 0.5 * (prev - next) / (prev - 2*curr + next)
            let denominator = prevCorr - 2 * currCorr + nextCorr
            if abs(denominator) > 0.001 {
                let offset = 0.5 * (prevCorr - nextCorr) / denominator
                // Clamp offset to reasonable range
                if abs(offset) < 1.0 {
                    refinedLag = Double(bestLag) + offset
                }
            }
        }
        
        // Convert lag to BPM with refined value
        let bpm = 60.0 * sampleRate / refinedLag
        let roundedBPM = Int(bpm.rounded())
        
        // Validate result (wider range)
        if roundedBPM >= 40 && roundedBPM <= 200 {
            return roundedBPM
        }
        
        return nil
    }
    
    // MARK: - Signal Smoothing
    
    /// Apply moving average smoothing with edge preservation
    /// Uses a smaller window to preserve signal shape while reducing noise
    static func smoothSignal(signal: [Double], windowSize: Int = 5) -> [Double] {
        guard signal.count > windowSize else { return signal }
        
        // Use weighted moving average for better edge preservation
        var smoothed = [Double](repeating: 0, count: signal.count)
        let halfWindow = windowSize / 2
        
        // Gaussian-like weights for smoothing (center has more weight)
        let weights: [Double]
        switch windowSize {
        case 3:
            weights = [0.25, 0.5, 0.25]
        case 5:
            weights = [0.1, 0.2, 0.4, 0.2, 0.1]
        case 7:
            weights = [0.05, 0.1, 0.2, 0.3, 0.2, 0.1, 0.05]
        default:
            // Fallback to uniform weights
            weights = [Double](repeating: 1.0 / Double(windowSize), count: windowSize)
        }
        
        for i in 0..<signal.count {
            let start = max(0, i - halfWindow)
            let end = min(signal.count - 1, i + halfWindow)
            let window = Array(signal[start...end])
            
            // Apply weighted average
            var weightedSum = 0.0
            var weightSum = 0.0
            
            for (j, value) in window.enumerated() {
                let weightIdx = j + (start - (i - halfWindow))
                let weight = (weightIdx >= 0 && weightIdx < weights.count) ? weights[weightIdx] : (1.0 / Double(windowSize))
                weightedSum += value * weight
                weightSum += weight
            }
            
            smoothed[i] = weightedSum / weightSum
        }
        
        return smoothed
    }
    
    // MARK: - Normalize Signal
    
    /// Normalize signal to 0-1 range
    static func normalizeSignal(signal: [Double]) -> [Double] {
        guard let minVal = signal.min(), let maxVal = signal.max() else {
            return signal
        }
        
        let range = maxVal - minVal
        guard range > 0 else { return signal }
        
        return signal.map { ($0 - minVal) / range }
    }
    
    // MARK: - Median Filter
    
    /// Apply median filter to remove spike noise (excellent for PPG signals)
    /// More effective than moving average for removing outliers while preserving edges
    static func medianFilter(signal: [Double], windowSize: Int = 3) -> [Double] {
        guard signal.count > windowSize else { return signal }
        
        var filtered = [Double](repeating: 0, count: signal.count)
        let halfWindow = windowSize / 2
        
        for i in 0..<signal.count {
            let start = max(0, i - halfWindow)
            let end = min(signal.count - 1, i + halfWindow)
            let window = Array(signal[start...end]).sorted()
            
            // Take median value
            filtered[i] = window[window.count / 2]
        }
        
        return filtered
    }
}
