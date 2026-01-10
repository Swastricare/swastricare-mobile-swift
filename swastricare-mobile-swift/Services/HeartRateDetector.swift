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
        let session = AVCaptureSession()
        session.sessionPreset = .low  // Low resolution is sufficient
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
            // Configure camera fps
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(sampleRate))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(sampleRate))
            
            // Fix focus and exposure for consistent lighting
            if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
                device.setFocusModeLocked(lensPosition: 0.0, completionHandler: nil) // Macro focus
            }
            
            if device.isExposureModeSupported(.locked) {
                // We want a relatively bright image but not blown out. 
                // However, auto-exposure is often better for adapting to different fingers/torches.
                // Let's try continuous auto exposure but lock it once we start if needed.
                // For now, continuous usually works best to adapt to skin tone.
                device.exposureMode = .continuousAutoExposure
            }
            
            // White balance locked to Red gain if possible? No, auto is fine if we look at relative changes.
            // Actually, locking WB is good to prevent color shifts being interpreted as pulse.
            if device.isWhiteBalanceModeSupported(.locked) {
                // Locking current WB (which might be wrong initially) is risky.
                // continuousAutoWhiteBalance is safer unless we set custom gains.
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            device.unlockForConfiguration()
            
            // Setup input
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            if session.canAddInput(input) == true {
                session.addInput(input)
            }
            
            // Setup output
            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput?.setSampleBufferDelegate(self, queue: processingQueue)
            videoOutput?.alwaysDiscardsLateVideoFrames = true
            
            if let output = videoOutput, session.canAddOutput(output) == true {
                session.addOutput(output)
            }
            session.commitConfiguration()
            
            // Start session
            isRunning = true
            // Reset startTime only when we actually get good frames
            startTime = nil 
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
                // Ensure torch stays on even if the session reconfigures
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.ensureTorchOn(retries: 3)
                }
            }
            
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.heartRateDetector(self, didEncounterError: .cameraNotAvailable)
            }
        }
    }
    
    private func ensureTorchOn(retries: Int) {
        guard let device = captureDevice else { return }
        guard device.hasTorch else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.heartRateDetector(self, didEncounterError: .torchNotAvailable)
            }
            return
        }
        do {
            try device.lockForConfiguration()
            if device.isTorchModeSupported(.on) {
                try device.setTorchModeOn(level: 0.1) // Use lower torch level to avoid saturation and heat
            } else {
                device.torchMode = .on
            }
            device.unlockForConfiguration()
        } catch {
            if retries > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.ensureTorchOn(retries: retries - 1)
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.heartRateDetector(self, didEncounterError: .torchNotAvailable)
                }
            }
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
        
        // Apply bandpass filter
        let filtered = PPGSignalProcessor.bandpassFilter(
            signal: usable.red,
            sampleRate: observedSampleRate
        )
        
        // Verify signal has sufficient variation (not flat)
        let signalRange = (filtered.max() ?? 0) - (filtered.min() ?? 0)
        guard signalRange > 0.1 else { return nil }
        
        // Method 1: Autocorrelation (most accurate for PPG)
        var acBPM: Int? = nil
        if let rawAC = PPGSignalProcessor.calculateBPMWithAutocorrelation(signal: filtered, sampleRate: observedSampleRate) {
            if rawAC >= 45 && rawAC <= 180 {
                acBPM = rawAC
            }
        }
        
        // Method 2: FFT-based BPM
        var fftBPM: Int? = nil
        if let rawFFT = PPGSignalProcessor.calculateBPMWithFFT(signal: filtered, sampleRate: observedSampleRate) {
            if rawFFT >= 45 && rawFFT <= 180 {
                fftBPM = rawFFT
            }
        }
        
        // Method 3: Peak detection with timestamp intervals
        var peakBPM: Int? = nil
        let minPeakDistance = Int(observedSampleRate * 0.33)
        let peaks = PPGSignalProcessor.findPeaks(signal: filtered, minDistance: max(minPeakDistance, 1))
        
        if peaks.count >= 4 {
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
            
            if !intervals.isEmpty {
                let sorted = intervals.sorted()
                let medianInterval = sorted[sorted.count / 2]
                let bpm = Int((60.0 / medianInterval).rounded())
                if bpm >= 45 && bpm <= 180 {
                    peakBPM = bpm
                }
            }
        }
        
        // PRODUCTION DECISION LOGIC:
        // Tighter agreement threshold (6 BPM) for high accuracy
        let agreementThreshold = 6
        
        // Best case: All three methods agree (within threshold)
        if let ac = acBPM, let fft = fftBPM, let peak = peakBPM {
            let maxDiff = max(abs(ac - fft), max(abs(ac - peak), abs(fft - peak)))
            if maxDiff <= agreementThreshold {
                // High confidence: use median of three
                let sorted = [ac, fft, peak].sorted()
                return sorted[1]
            }
        }
        
        // Two methods agree: prefer autocorrelation combinations
        if let ac = acBPM {
            if let fft = fftBPM, abs(ac - fft) <= agreementThreshold {
                return (ac + fft) / 2
            }
            if let peak = peakBPM, abs(ac - peak) <= agreementThreshold {
                return (ac + peak) / 2
            }
        }
        
        // FFT and Peak agree
        if let fft = fftBPM, let peak = peakBPM, abs(fft - peak) <= agreementThreshold {
            return (fft + peak) / 2
        }
        
        // No agreement - require at least autocorrelation for reliability
        // Autocorrelation is most robust for PPG signals
        if let ac = acBPM {
            return ac
        }
        
        // Last resort: only return if FFT and Peak are close-ish (within 10)
        if let fft = fftBPM, let peak = peakBPM, abs(fft - peak) <= 10 {
            return (fft + peak) / 2
        }
        
        // Methods disagree too much - don't return unreliable data
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
    
    // Improved Signal Quality Evaluation
    func evaluateSignalQuality(red: Double, green: Double, blue: Double) -> SignalQuality {
        // Basic brightness check
        // With torch ON, finger should be bright.
        // If it's dark, finger is likely not covering the lens.
        if red < 60 { return .poor }
        
        // Color dominance check
        // Finger should look RED.
        // If Red is not significantly higher than Green and Blue, it's likely not a finger (e.g. ambient light on a table)
        if red < (green + blue) * 0.8 {
            return .poor
        }
        
        // Now check the signal buffer statistics if we have enough data
        guard redValues.count >= 30 else { return .poor }
        let recentValues = Array(redValues.suffix(30))
        
        // Check mean brightness
        let mean = recentValues.reduce(0, +) / Double(recentValues.count)
        
        // Check amplitude (pulsation should create variation)
        let minVal = recentValues.min() ?? 0
        let maxVal = recentValues.max() ?? 0
        let amplitude = maxVal - minVal
        
        // Check standard deviation
        let variance = recentValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(recentValues.count)
        let stdDev = sqrt(variance)
        
        // Tier 1: POOR
        // - Too dark (mean < 60)
        // - Too flat (amplitude < 1.0) -> indicates no pulse or inanimate object
        // - Too noisy (stdDev > 10) -> indicates motion
        if mean < 60 || amplitude < 1.0 || stdDev > 15 {
            return .poor
        }
        
        // Tier 2: FAIR
        if mean < 100 || amplitude < 2.5 || stdDev < 0.6 {
            return .fair
        }
        
        // Tier 3: EXCELLENT
        if amplitude >= 5.0 && stdDev >= 1.2 && stdDev <= 5.0 && mean >= 120 {
            return .excellent
        }
        
        // Tier 4: GOOD
        if amplitude >= 2.5 && stdDev >= 0.7 && stdDev <= 6.0 {
            return .good
        }
        
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
