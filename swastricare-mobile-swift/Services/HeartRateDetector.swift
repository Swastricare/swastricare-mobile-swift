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
        case .poor: return "Place finger on camera"
        case .fair: return "Adjusting..."
        case .good: return "Good signal"
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
    private let measurementDuration: TimeInterval = 30.0  // Extended to 30 seconds for better accuracy
    private let warmupSamples = 60  // Ignore first 2 seconds of unstable frames
    let minSamplesForCalculation = 180  // ~6 seconds at 30fps
    private let maxSamples = 900  // ~30 seconds at 30fps
    
    // State
    private var isRunning = false
    private var bpmReadings: [Int] = []
    
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
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .low  // Low resolution is sufficient
        
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
            device.unlockForConfiguration()
            
            // Setup input
            let input = try AVCaptureDeviceInput(device: device)
            captureSession?.beginConfiguration()
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
            }
            
            // Setup output
            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput?.setSampleBufferDelegate(self, queue: processingQueue)
            videoOutput?.alwaysDiscardsLateVideoFrames = true
            
            if let output = videoOutput, captureSession?.canAddOutput(output) == true {
                captureSession?.addOutput(output)
            }
            captureSession?.commitConfiguration()
            
            // Start session
            isRunning = true
            startTime = Date()
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
                // Ensure torch stays on even if the session reconfigures
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
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
                try device.setTorchModeOn(level: 1.0)
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
        
        // Decision logic: prefer autocorrelation, validate with others
        
        // If autocorrelation agrees with FFT or peak (within 12 BPM), use average
        if let ac = acBPM {
            if let fft = fftBPM, abs(ac - fft) <= 12 {
                return (ac + fft) / 2
            }
            if let peak = peakBPM, abs(ac - peak) <= 12 {
                return (ac + peak) / 2
            }
            // If autocorrelation is alone but in good range, trust it
            return ac
        }
        
        // Fallback to FFT + peak
        if let fft = fftBPM, let peak = peakBPM {
            if abs(fft - peak) <= 12 {
                return (fft + peak) / 2
            }
            // Prefer higher value (PPG tends to undercount)
            return max(fft, peak)
        }
        
        return fftBPM ?? peakBPM
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
    
    func evaluateSignalQuality() -> SignalQuality {
        guard redValues.count >= 30 else { return .poor }
        
        let recentValues = Array(redValues.suffix(30))
        
        // Check mean brightness (finger covering camera should be bright red)
        let mean = recentValues.reduce(0, +) / Double(recentValues.count)
        
        // Check amplitude (pulsation should create variation)
        let min = recentValues.min() ?? 0
        let max = recentValues.max() ?? 0
        let amplitude = max - min
        
        // Check standard deviation (should have rhythmic variation)
        let variance = recentValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(recentValues.count)
        let stdDev = sqrt(variance)
        
        // Evaluate quality (relaxed thresholds to reduce false "noisy")
        if mean < 80 || amplitude < 1 {
            return .poor  // Finger likely not on camera
        } else if mean < 120 || amplitude < 3 || stdDev < 0.8 {
            return .fair  // Weak signal
        } else if stdDev < 2.5 {
            return .good
        } else {
            return .excellent
        }
    }
}

// MARK: - Video Frame Processing

extension HeartRateDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard isRunning,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Extract red channel average
        let redAverage = extractRedAverage(from: pixelBuffer)
        
        // Skip frames with excessive motion (helps avoid spikes)
        if motionDetector.isMotionExcessive(newValue: redAverage) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.heartRateDetector(self, didUpdateSignalQuality: .poor)
            }
            return
        }
        let timestamp = Date().timeIntervalSince(startTime ?? Date())
        
        // Store sample
        redValues.append(redAverage)
        timestamps.append(timestamp)
        
        // Trim old samples
        if redValues.count > maxSamples {
            redValues.removeFirst()
            timestamps.removeFirst()
        }
        
        // Update progress
        let progress = Float(min(timestamp / measurementDuration, 1.0))
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.heartRateDetector(self, didUpdateProgress: progress)
        }
        
        // Check signal quality and calculate BPM
        let quality = evaluateSignalQuality()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.heartRateDetector(self, didUpdateSignalQuality: quality)
        }
        
        // Calculate BPM if we have enough samples
        if redValues.count >= minSamplesForCalculation {
            if let bpm = calculateHeartRate() {
                bpmReadings.append(bpm)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.heartRateDetector(self, didUpdateBPM: bpm)
                }
            }
        }
        
        // Auto-stop after measurement duration
        if timestamp >= measurementDuration {
            DispatchQueue.main.async { [weak self] in
                self?.stopMeasurement()
            }
        }
    }
    
    private func extractRedAverage(from pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return 0
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var redSum: Double = 0
        var pixelCount: Double = 0
        
        // Sample center region (more reliable)
        let startX = width / 4
        let endX = 3 * width / 4
        let startY = height / 4
        let endY = 3 * height / 4
        
        for y in stride(from: startY, to: endY, by: 2) {
            for x in stride(from: startX, to: endX, by: 2) {
                let offset = y * bytesPerRow + x * 4
                
                // BGRA format - red is at offset + 2
                let red = Double(buffer[offset + 2])
                redSum += red
                pixelCount += 1
            }
        }
        
        return redSum / pixelCount
    }
}
