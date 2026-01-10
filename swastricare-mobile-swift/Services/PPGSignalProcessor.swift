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
    /// Passband: 0.8 Hz - 3.0 Hz (48 - 180 BPM) - tighter range to reduce noise
    static func bandpassFilter(signal: [Double], sampleRate: Double) -> [Double] {
        guard signal.count > 10 else { return signal }
        
        // Remove DC component (mean)
        let mean = signal.reduce(0, +) / Double(signal.count)
        let centered = signal.map { $0 - mean }
        
        // Low-pass filter (cutoff: 3.0 Hz for up to 180 BPM)
        let lowPassed = lowPassFilter(signal: centered, cutoff: 3.0, sampleRate: sampleRate)
        
        // High-pass filter (cutoff: 0.8 Hz for down to 48 BPM)
        let bandPassed = highPassFilter(signal: lowPassed, cutoff: 0.8, sampleRate: sampleRate)
        
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
    
    /// Find peaks in the filtered signal using adaptive threshold
    static func findPeaks(signal: [Double], minDistance: Int = 10) -> [Int] {
        guard signal.count > 2 else { return [] }
        
        var peaks: [Int] = []
        
        // Calculate signal statistics
        let maxVal = signal.max() ?? 0
        let minVal = signal.min() ?? 0
        let range = maxVal - minVal
        
        guard range > 0 else { return [] }
        
        // Threshold at 50% of signal range above minimum
        let threshold = minVal + (range * 0.5)
        
        for i in 1..<(signal.count - 1) {
            // Check if local maximum and above threshold
            if signal[i] > signal[i-1] && signal[i] > signal[i+1] && signal[i] > threshold {
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
    
    /// Calculate BPM from peak intervals
    static func calculateBPM(peaks: [Int], sampleRate: Double) -> Int? {
        guard peaks.count >= 3 else { return nil }
        
        // Calculate intervals between consecutive peaks
        var intervals: [Double] = []
        for i in 1..<peaks.count {
            let interval = Double(peaks[i] - peaks[i-1]) / sampleRate
            intervals.append(interval)
        }
        
        // Remove outliers (intervals outside physiological range)
        let validIntervals = intervals.filter { interval in
            let bpm = 60.0 / interval
            return bpm >= 40 && bpm <= 200
        }
        
        guard !validIntervals.isEmpty else { return nil }
        
        // Calculate median interval (more robust than mean)
        let sortedIntervals = validIntervals.sorted()
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
        
        // Find peak frequency in heart rate range (0.8-3.0 Hz = 48-180 BPM)
        let freqResolution = sampleRate / Double(n)
        let minBin = max(1, Int(0.8 / freqResolution))
        let maxBin = min(n / 2 - 1, Int(3.0 / freqResolution))
        
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
        
        // Validate all results (45-180 BPM range)
        let validPeak = peakBPM.flatMap { ($0 >= 45 && $0 <= 180) ? $0 : nil }
        let validFFT = fftBPM.flatMap { ($0 >= 45 && $0 <= 180) ? $0 : nil }
        let validAC = acBPM.flatMap { ($0 >= 45 && $0 <= 180) ? $0 : nil }
        
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
    
    /// Calculate BPM using autocorrelation - often more accurate than FFT for PPG
    static func calculateBPMWithAutocorrelation(signal: [Double], sampleRate: Double) -> Int? {
        guard signal.count >= 128 else { return nil }
        
        // Normalize signal
        let mean = signal.reduce(0, +) / Double(signal.count)
        let centered = signal.map { $0 - mean }
        
        // Calculate autocorrelation for lags corresponding to 45-180 BPM
        let minLag = Int(sampleRate * 60.0 / 180.0)  // 180 BPM
        let maxLag = Int(sampleRate * 60.0 / 45.0)   // 45 BPM
        
        guard maxLag < signal.count / 2 else { return nil }
        
        var maxCorrelation: Double = 0
        var bestLag = 0
        
        // Energy normalization
        var energy: Double = 0
        for i in 0..<centered.count {
            energy += centered[i] * centered[i]
        }
        guard energy > 0 else { return nil }
        
        for lag in minLag...maxLag {
            var correlation: Double = 0
            let n = centered.count - lag
            
            for i in 0..<n {
                correlation += centered[i] * centered[i + lag]
            }
            
            // Normalize by overlap length and energy
            correlation = correlation / Double(n)
            
            if correlation > maxCorrelation {
                maxCorrelation = correlation
                bestLag = lag
            }
        }
        
        guard bestLag > 0 else { return nil }
        
        // Convert lag to BPM
        let bpm = 60.0 * sampleRate / Double(bestLag)
        let roundedBPM = Int(bpm.rounded())
        
        // Validate result
        if roundedBPM >= 45 && roundedBPM <= 180 {
            return roundedBPM
        }
        
        return nil
    }
    
    // MARK: - Signal Smoothing
    
    /// Apply moving average smoothing
    static func smoothSignal(signal: [Double], windowSize: Int = 5) -> [Double] {
        guard signal.count > windowSize else { return signal }
        
        var smoothed = [Double](repeating: 0, count: signal.count)
        let halfWindow = windowSize / 2
        
        for i in 0..<signal.count {
            let start = max(0, i - halfWindow)
            let end = min(signal.count - 1, i + halfWindow)
            let window = Array(signal[start...end])
            smoothed[i] = window.reduce(0, +) / Double(window.count)
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
}
