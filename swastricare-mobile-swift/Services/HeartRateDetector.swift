//
//  HeartRateDetector.swift
//  swastricare-mobile-swift
//
//  Camera-based heart rate detection using photoplethysmography (PPG)
//

import AVFoundation
import Accelerate

// MARK: - Protocols

protocol HeartRateDetectorDelegate: AnyObject {
    func heartRateDetector(_ detector: HeartRateDetector, didUpdateBPM bpm: Int)
    func heartRateDetector(_ detector: HeartRateDetector, didUpdateSignalQuality quality: SignalQuality)
    func heartRateDetector(_ detector: HeartRateDetector, didUpdateProgress progress: Float)
    func heartRateDetectorDidFinish(_ detector: HeartRateDetector, averageBPM: Int)
    func heartRateDetector(_ detector: HeartRateDetector, didEncounterError error: HeartRateError)
}

// MARK: - Enums

enum SignalQuality {
    case poor
    case fair
    case good
    case excellent
    
    var description: String {
        switch self {
        case .poor: return "Place finger firmly covering camera and flash"
        case .fair: return "Hold steady..."
        case .good: return "Detecting pulse..."
        case .excellent: return "Excellent signal"
        }
    }
}

enum HeartRateError: Error, LocalizedError {
    case cameraNotAvailable
    case torchNotAvailable
    case permissionDenied
    case measurementFailed
    
    var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "Camera is not available on this device."
        case .torchNotAvailable:
            return "Flash/torch is not available on this device."
        case .permissionDenied:
            return "Camera permission is required. Please enable it in Settings."
        case .measurementFailed:
            return "Measurement failed. Please try again."
        }
    }
}

// MARK: - HeartRateDetector

class HeartRateDetector: NSObject {
    
    // MARK: - Properties
    
    weak var delegate: HeartRateDetectorDelegate?
    
    private(set) var captureSession: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let processingQueue = DispatchQueue(label: "com.swasthicare.heartrate.processing")
    private let motionDetector = MotionDetector()
    
    // Signal collection
    private var redValues: [Double] = []
    private var timestamps: [Double] = []
    private var startTime: Date?
    
    // Configuration
    let sampleRate: Double = 30.0  // Target FPS
    private let measurementDuration: TimeInterval = 30.0
    private let warmupSamples = 60  // Ignore first 2 seconds
    let minSamplesForCalculation = 180
    private let maxSamples = 900
    
    // State
    private var isRunning = false
    private var bpmReadings: [Int] = []
    private var validTimeElapsed: TimeInterval = 0
    private var lastFrameTime: Date?
    
    // MARK: - Public Methods
    
    func startMeasurement() {
        guard !isRunning else { return }
        
        resetState()
        
        checkPermissions { [weak self] granted in
            guard let self = self else { return }
            
            guard granted else {
                DispatchQueue.main.async {
                    self.delegate?.heartRateDetector(self, didEncounterError: .permissionDenied)
                }
                return
            }
            self.setupCaptureSession()
        }
    }
    
    func stopMeasurement() {
        isRunning = false
        captureSession?.stopRunning()
        turnOffTorch()
        
        // Clear session to reset preview in UI
        captureSession = nil
        
        if !bpmReadings.isEmpty {
            let averageBPM = bpmReadings.reduce(0, +) / bpmReadings.count
            delegate?.heartRateDetectorDidFinish(self, averageBPM: averageBPM)
        }
    }
    
    // MARK: - Private Methods
    
    private func resetState() {
        redValues.removeAll()
        timestamps.removeAll()
        bpmReadings.removeAll()
        startTime = nil
        lastFrameTime = nil
        validTimeElapsed = 0
        motionDetector.reset()
    }
    
    private func checkPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }
    
    private func setupCaptureSession() {
        // Stop any existing session first
        captureSession?.stopRunning()
        captureSession = nil
        
        let session = AVCaptureSession()
        self.captureSession = session
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.heartRateDetector(self, didEncounterError: .cameraNotAvailable)
            }
            return
        }
        captureDevice = device
        
        do {
            // Begin session configuration FIRST (before any device config)
            session.beginConfiguration()
            
            // Use medium preset for better compatibility
            if session.canSetSessionPreset(.medium) {
                session.sessionPreset = .medium
            } else if session.canSetSessionPreset(.low) {
                session.sessionPreset = .low
            }
            
            // Setup input
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // Setup output
            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput?.setSampleBufferDelegate(self, queue: processingQueue)
            videoOutput?.alwaysDiscardsLateVideoFrames = true
            
            if let output = videoOutput, session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            // Commit session configuration
            session.commitConfiguration()
            
            // Configure frame rate only (NOT torch yet - torch must be set AFTER session starts)
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(sampleRate))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(sampleRate))
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
            
            // Set running state
            isRunning = true
            startTime = nil
            
            // Start session on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                session.startRunning()
                
                // Wait for session to fully start, then turn on torch
                Thread.sleep(forTimeInterval: 0.5)
                
                DispatchQueue.main.async {
                    // Turn on torch AFTER session is running
                    self.turnOnTorch()
                }
            }
            
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.heartRateDetector(self, didEncounterError: .cameraNotAvailable)
            }
        }
    }
    
    private func turnOnTorch() {
        guard isRunning else { return }
        guard let device = captureDevice, device.hasTorch else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.heartRateDetector(self, didEncounterError: .torchNotAvailable)
            }
            return
        }
        
        do {
            try device.lockForConfiguration()
            // Use maximum torch level for best finger illumination
            if device.isTorchModeSupported(.on) {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            }
            device.unlockForConfiguration()
            
            // Keep checking torch stays on
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.verifyTorchOn()
            }
        } catch {
            // Retry after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.turnOnTorch()
            }
        }
    }
    
    private func verifyTorchOn() {
        guard isRunning, let device = captureDevice else { return }
        
        if device.torchMode != .on {
            turnOnTorch()
        }
    }
    
    private func turnOffTorch() {
        let device = captureDevice ?? AVCaptureDevice.default(for: .video)
        guard let device, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        } catch {
            print("Failed to turn off torch: \(error)")
        }
    }
    
    // MARK: - Signal Processing Integration
    
    func calculateHeartRate() -> Int? {
        let usable = usableSamples()
        guard usable.red.count >= minSamplesForCalculation else { return nil }
        
        // Use observed frame rate
        let observedSampleRate = currentSampleRate(usable.timestamps)
        
        // Step 1: Remove spike noise with median filter (excellent for PPG)
        let denoised = PPGSignalProcessor.medianFilter(signal: usable.red, windowSize: 3)
        
        // Step 2: Smooth the signal to reduce high-frequency noise
        let smoothed = PPGSignalProcessor.smoothSignal(signal: denoised, windowSize: 3)
        
        // Step 3: Apply bandpass filter to isolate heart rate frequencies
        let filtered = PPGSignalProcessor.bandpassFilter(
            signal: smoothed,
            sampleRate: observedSampleRate
        )
        
        // Verify signal has sufficient variation (not flat)
        let signalRange = (filtered.max() ?? 0) - (filtered.min() ?? 0)
        guard signalRange > 0.08 else { return nil }  // Reduced threshold for better sensitivity
        
        // Method 1: Autocorrelation (most accurate for PPG)
        var acBPM: Int? = nil
        if let rawAC = PPGSignalProcessor.calculateBPMWithAutocorrelation(signal: filtered, sampleRate: observedSampleRate) {
            if rawAC >= 40 && rawAC <= 200 {
                acBPM = rawAC
            }
        }
        
        // Method 2: FFT-based BPM
        var fftBPM: Int? = nil
        if let rawFFT = PPGSignalProcessor.calculateBPMWithFFT(signal: filtered, sampleRate: observedSampleRate) {
            if rawFFT >= 40 && rawFFT <= 200 {
                fftBPM = rawFFT
            }
        }
        
        // Method 3: Peak detection with timestamp intervals
        var peakBPM: Int? = nil
        let minPeakDistance = Int(observedSampleRate * 0.3)  // Increased from 0.33 for lower HR
        let peaks = PPGSignalProcessor.findPeaks(signal: filtered, minDistance: max(minPeakDistance, 1))
        
        if peaks.count >= 3 {  // Reduced from 4 for more flexibility
            var intervals: [Double] = []
            for i in 1..<peaks.count {
                let prevIdx = peaks[i - 1]
                let currIdx = peaks[i]
                guard prevIdx < usable.timestamps.count, currIdx < usable.timestamps.count else { continue }
                let delta = usable.timestamps[currIdx] - usable.timestamps[prevIdx]
                if delta > 0.3 && delta < 1.5 {  // 40-200 BPM range
                    intervals.append(delta)
                }
            }
            
            if intervals.count >= 2 {  // Need at least 2 intervals
                // Use IQR for outlier removal if enough data
                var cleanedIntervals = intervals
                if intervals.count >= 4 {
                    let sorted = intervals.sorted()
                    let q1 = sorted[sorted.count / 4]
                    let q3 = sorted[(sorted.count * 3) / 4]
                    let iqr = q3 - q1
                    let lowerBound = q1 - (1.5 * iqr)
                    let upperBound = q3 + (1.5 * iqr)
                    cleanedIntervals = intervals.filter { $0 >= lowerBound && $0 <= upperBound }
                }
                
                if !cleanedIntervals.isEmpty {
                    let sorted = cleanedIntervals.sorted()
                    let medianInterval = sorted[sorted.count / 2]
                    let bpm = Int((60.0 / medianInterval).rounded())
                    if bpm >= 40 && bpm <= 200 {
                        peakBPM = bpm
                    }
                }
            }
        }
        
        // IMPROVED DECISION LOGIC:
        // Adaptive agreement threshold based on heart rate range
        // Lower HR = stricter threshold, Higher HR = more flexible
        let baseThreshold = 8  // Increased from 6 for more flexibility
        
        // Best case: All three methods agree (within threshold)
        if let ac = acBPM, let fft = fftBPM, let peak = peakBPM {
            let maxDiff = max(abs(ac - fft), max(abs(ac - peak), abs(fft - peak)))
            let avgBPM = (ac + fft + peak) / 3
            
            // Adaptive threshold: ±8 for normal HR, ±10 for high HR
            let adaptiveThreshold = avgBPM > 120 ? baseThreshold + 2 : baseThreshold
            
            if maxDiff <= adaptiveThreshold {
                // High confidence: use weighted median (favor autocorrelation slightly)
                let sorted = [ac, fft, peak].sorted()
                return sorted[1]  // Median
            }
            
            // Partial agreement: at least 2 methods within threshold
            if abs(ac - fft) <= adaptiveThreshold && abs(ac - peak) <= adaptiveThreshold {
                // AC agrees with both - very reliable
                return ac
            }
            if abs(ac - fft) <= adaptiveThreshold {
                // AC and FFT agree - good confidence
                return (ac * 2 + fft) / 3  // Weight AC more
            }
            if abs(ac - peak) <= adaptiveThreshold {
                // AC and Peak agree - good confidence
                return (ac * 2 + peak) / 3  // Weight AC more
            }
            if abs(fft - peak) <= adaptiveThreshold {
                // FFT and Peak agree - decent confidence
                return (fft + peak) / 2
            }
        }
        
        // Two methods available: prefer autocorrelation combinations
        if let ac = acBPM {
            let adaptiveThreshold = ac > 120 ? baseThreshold + 2 : baseThreshold
            
            if let fft = fftBPM, abs(ac - fft) <= adaptiveThreshold {
                return (ac * 2 + fft) / 3  // Weight AC more heavily
            }
            if let peak = peakBPM, abs(ac - peak) <= adaptiveThreshold {
                return (ac * 2 + peak) / 3  // Weight AC more heavily
            }
        }
        
        // FFT and Peak agree (no AC available)
        if let fft = fftBPM, let peak = peakBPM {
            let avgBPM = (fft + peak) / 2
            let adaptiveThreshold = avgBPM > 120 ? baseThreshold + 2 : baseThreshold
            
            if abs(fft - peak) <= adaptiveThreshold {
                return (fft + peak) / 2
            }
        }
        
        // Single method available - use with caution
        // Autocorrelation is most robust for PPG signals, so trust it more
        if let ac = acBPM {
            // Autocorrelation alone is still fairly reliable for PPG
            return ac
        }
        
        // Last resort: FFT or Peak alone (lower reliability)
        // Only use if methods are within extended threshold
        if let fft = fftBPM, let peak = peakBPM, abs(fft - peak) <= 15 {
            return (fft + peak) / 2
        }
        
        // Single FFT or Peak - use only if no other option
        if let fft = fftBPM {
            return fft
        }
        if let peak = peakBPM {
            return peak
        }
        
        // No valid readings available
        return nil
    }
    
    // Observed sample rate based on timestamps to account for actual camera FPS
    private func currentSampleRate(_ times: [Double]) -> Double {
        guard let first = times.first,
              let last = times.last,
              last > first else {
            return sampleRate
        }
        let duration = last - first
        return Double(times.count - 1) / duration
    }
    
    private func usableSamples() -> (red: [Double], timestamps: [Double]) {
        guard redValues.count > warmupSamples else {
            return (redValues, timestamps)
        }
        let start = warmupSamples
        return (Array(redValues[start...]), Array(timestamps[start...]))
    }
    
    // Improved Signal Quality Evaluation with better sensitivity
    // Returns quality based on current frame + buffer statistics (if available)
    func evaluateSignalQuality(red: Double, green: Double, blue: Double) -> SignalQuality {
        // STAGE 1: Basic frame checks (brightness + redness)
        // These determine if we should even collect this sample
        
        // Basic brightness check - relaxed threshold for various lighting conditions
        if red < 40 {  // Reduced from 50 for better sensitivity
            return .poor
        }
        
        // CRITICAL: Check for ambient light (all channels high = no finger)
        // If green and blue are also very bright, it's NOT a finger
        if green > 120 && blue > 120 {  // Increased from 100 to be less sensitive
            return .poor  // Ambient light, not finger
        }
        
        // Color dominance check - finger with blood should be RED dominant
        // When finger covers camera+torch: R>>G, R>>B (blood absorbs green/blue)
        let rednessRatio = red / max(green + blue, 1)
        if rednessRatio < 0.55 {  // Reduced from 0.6 for more flexibility
            return .poor
        }
        
        // STAGE 2: Basic checks passed - this is a valid finger frame!
        // NEVER return .poor after this point - we want to collect data
        
        // Need more samples for detailed analysis
        guard redValues.count >= 60 else {
            return .fair  // Allow data collection during warmup
        }
        
        // STAGE 3: Buffer-based quality assessment (for UI feedback only)
        // Use recent samples, skipping warmup period
        let recentValues = Array(redValues.suffix(30))
        let mean = recentValues.reduce(0, +) / Double(recentValues.count)
        let minVal = recentValues.min() ?? 0
        let maxVal = recentValues.max() ?? 0
        let amplitude = maxVal - minVal
        let variance = recentValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(recentValues.count)
        let stdDev = sqrt(variance)
        
        // Note: We NEVER return .poor here - basic checks already passed
        // This is just for user feedback (fair/good/excellent)
        
        // EXCELLENT: Good brightness, nice pulse amplitude, reasonably stable
        if mean >= 90 && amplitude >= 1.8 && stdDev <= 35.0 {  // Relaxed thresholds
            return .excellent
        }
        
        // GOOD: Decent readings
        if mean >= 70 && amplitude >= 1.0 {  // Relaxed from 80
            return .good
        }
        
        // Default to FAIR (still collecting data!)
        return .fair
    }
}

// MARK: - Video Frame Processing

extension HeartRateDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard isRunning,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Extract color averages
        let colors = extractColorAverages(from: pixelBuffer)
        
        // Evaluate Quality using full color info
        let quality = evaluateSignalQuality(red: colors.red, green: colors.green, blue: colors.blue)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.heartRateDetector(self, didUpdateSignalQuality: quality)
        }
        
        // SMART DETECTION:
        // If quality is poor (finger removed or bad placement), DO NOT record data or advance progress.
        // This effectively "pauses" the measurement until the user fixes placement.
        if quality == .poor {
            // Optionally clear recent buffer if poor for too long to avoid mixing bad data
            // For now, just skipping is enough to pause.
            return
        }
        
        // Motion Check
        if motionDetector.isMotionExcessive(newValue: colors.red) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.heartRateDetector(self, didUpdateSignalQuality: .poor)
            }
            return
        }
        
        // Record timestamp logic
        let now = Date()
        if startTime == nil {
            startTime = now
        }
        
        // Calculate delta time for progress
        if let last = lastFrameTime {
            let delta = now.timeIntervalSince(last)
            // Cap delta to avoid jumps if thread was blocked
            validTimeElapsed += min(delta, 0.1)
        }
        lastFrameTime = now
        
        let timestamp = validTimeElapsed
        
        // Store sample
        redValues.append(colors.red)
        timestamps.append(timestamp)
        
        // Trim old samples
        if redValues.count > maxSamples {
            redValues.removeFirst()
            timestamps.removeFirst()
        }
        
        // Update progress based on VALID time elapsed, not wall clock time
        let progress = Float(min(validTimeElapsed / measurementDuration, 1.0))
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.heartRateDetector(self, didUpdateProgress: progress)
        }
        
        // Calculate BPM if we have enough samples
        if redValues.count >= minSamplesForCalculation {
            // Run calculation less frequently to save CPU? No, every frame is fine for responsiveness.
            if let bpm = calculateHeartRate() {
                bpmReadings.append(bpm)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.heartRateDetector(self, didUpdateBPM: bpm)
                }
            }
        }
        
        // Auto-stop after measurement duration
        if validTimeElapsed >= measurementDuration {
            DispatchQueue.main.async { [weak self] in
                self?.stopMeasurement()
            }
        }
    }
    
    private func extractColorAverages(from pixelBuffer: CVPixelBuffer) -> (red: Double, green: Double, blue: Double) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return (0, 0, 0)
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var redSum: Double = 0
        var greenSum: Double = 0
        var blueSum: Double = 0
        var pixelCount: Double = 0
        
        // Sample center region
        let startX = width / 4
        let endX = 3 * width / 4
        let startY = height / 4
        let endY = 3 * height / 4
        
        for y in stride(from: startY, to: endY, by: 2) {
            for x in stride(from: startX, to: endX, by: 2) {
                let offset = y * bytesPerRow + x * 4
                
                // BGRA format
                // 0: Blue, 1: Green, 2: Red, 3: Alpha
                let blue = Double(buffer[offset])
                let green = Double(buffer[offset + 1])
                let red = Double(buffer[offset + 2])
                
                redSum += red
                greenSum += green
                blueSum += blue
                pixelCount += 1
            }
        }
        
        return (redSum / pixelCount, greenSum / pixelCount, blueSum / pixelCount)
    }
}
