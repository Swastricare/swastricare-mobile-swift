package com.swastricare.health.data.services

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * PPG Signal Processor
 * Processes raw red channel values from camera frames for heart rate detection.
 * Implements bandpass filtering, DC removal, and peak detection.
 */
class PPGSignalProcessor {

    companion object {
        // BPM bounds
        const val MIN_BPM = 40
        const val MAX_BPM = 200

        // Filter parameters (targeting 0.67 - 3.5 Hz for 40-210 BPM)
        const val LOW_CUTOFF_HZ = 0.67
        const val HIGH_CUTOFF_HZ = 3.5
        const val SAMPLE_RATE = 30.0 // Camera FPS assumption

        // Peak detection
        const val MIN_PEAK_DISTANCE_SAMPLES = 8 // ~0.27s at 30fps (max ~220 BPM)

        // Finger-presence detection on raw Y-plane luminance (0-255).
        // A finger pressed to a lit lens produces a bright, stable frame.
        const val FINGER_MIN_BRIGHTNESS = 100.0
        const val FINGER_MAX_STABLE_STDDEV = 25.0
        const val FINGER_DETECTION_MIN_SAMPLES = 15 // ~0.5s at 30fps
    }

    private val rawBuffer = mutableListOf<Double>()
    private val filteredBuffer = mutableListOf<Double>()
    private var dcEstimate: Double = 0.0
    private var initialized = false

    // Simple IIR bandpass filter coefficients (second-order)
    private var prevInput = doubleArrayOf(0.0, 0.0)
    private var prevOutput = doubleArrayOf(0.0, 0.0)

    fun reset() {
        rawBuffer.clear()
        filteredBuffer.clear()
        dcEstimate = 0.0
        initialized = false
        prevInput = doubleArrayOf(0.0, 0.0)
        prevOutput = doubleArrayOf(0.0, 0.0)
    }

    /**
     * Add a raw red channel sample (average brightness of frame).
     * Returns the filtered value.
     */
    fun addSample(rawValue: Double): Double {
        rawBuffer.add(rawValue)

        // DC removal with exponential moving average
        if (!initialized) {
            dcEstimate = rawValue
            initialized = true
        } else {
            dcEstimate = 0.95 * dcEstimate + 0.05 * rawValue
        }
        val acComponent = rawValue - dcEstimate

        // Simple bandpass filter (second-order Butterworth approximation)
        val filtered = applyBandpassFilter(acComponent)
        filteredBuffer.add(filtered)

        return filtered
    }

    /**
     * Detect peaks in the filtered signal.
     * Returns list of indices where peaks occur.
     */
    fun detectPeaks(): List<Int> {
        if (filteredBuffer.size < 3) return emptyList()

        val peaks = mutableListOf<Int>()
        val threshold = calculateAdaptiveThreshold()

        for (i in 1 until filteredBuffer.size - 1) {
            val prev = filteredBuffer[i - 1]
            val curr = filteredBuffer[i]
            val next = filteredBuffer[i + 1]

            // Peak: higher than neighbors and above threshold
            if (curr > prev && curr > next && curr > threshold) {
                // Check minimum distance from last peak
                if (peaks.isEmpty() || (i - peaks.last()) >= MIN_PEAK_DISTANCE_SAMPLES) {
                    peaks.add(i)
                }
            }
        }
        return peaks
    }

    /**
     * Calculate BPM from detected peaks.
     * Returns null if insufficient data.
     */
    fun calculateBPM(): Double? {
        val peaks = detectPeaks()
        if (peaks.size < 2) return null

        // Calculate inter-peak intervals
        val intervals = peaks.zipWithNext { a, b -> (b - a).toDouble() / SAMPLE_RATE }

        // Filter outlier intervals
        val validIntervals = intervals.filter { interval ->
            val bpm = 60.0 / interval
            bpm in MIN_BPM.toDouble()..MAX_BPM.toDouble()
        }

        if (validIntervals.isEmpty()) return null

        // Average interval
        val avgInterval = validIntervals.average()
        val bpm = 60.0 / avgInterval

        return if (bpm in MIN_BPM.toDouble()..MAX_BPM.toDouble()) bpm else null
    }

    /**
     * Returns true when the recent raw frames look like a fingertip held
     * steady over a lit lens: consistently bright and low variance.
     */
    fun isFingerPresent(): Boolean {
        if (rawBuffer.size < FINGER_DETECTION_MIN_SAMPLES) return false

        val recent = rawBuffer.takeLast(FINGER_DETECTION_MIN_SAMPLES)
        val mean = recent.average()
        if (mean < FINGER_MIN_BRIGHTNESS) return false

        val variance = recent.map { (it - mean) * (it - mean) }.average()
        return sqrt(variance) < FINGER_MAX_STABLE_STDDEV
    }

    /**
     * Assess signal quality based on variance and consistency.
     * Returns quality from 0.0 (poor) to 1.0 (excellent).
     */
    fun assessSignalQuality(): SignalQuality {
        if (!isFingerPresent()) return SignalQuality.POOR
        if (filteredBuffer.size < 30) return SignalQuality.POOR

        val recent = filteredBuffer.takeLast(30)
        val mean = recent.average()
        val variance = recent.map { (it - mean) * (it - mean) }.average()
        val stdDev = sqrt(variance)

        // Check for consistent periodicity
        val peaks = detectPeaks()
        val peakConsistency = if (peaks.size >= 3) {
            val intervals = peaks.zipWithNext { a, b -> b - a }
            val avgInterval = intervals.average()
            val intervalVariance = intervals.map { (it - avgInterval) * (it - avgInterval) }.average()
            val cv = sqrt(intervalVariance) / avgInterval // coefficient of variation
            1.0 - cv.coerceIn(0.0, 1.0)
        } else 0.0

        // Signal should have some variance (finger is on) but not too much (noise)
        val signalStrength = when {
            stdDev < 0.5 -> 0.2 // Too flat - finger not properly placed
            stdDev > 50.0 -> 0.3 // Too noisy
            else -> 0.8
        }

        val overallQuality = (signalStrength * 0.4 + peakConsistency * 0.6)

        return when {
            overallQuality >= 0.75 -> SignalQuality.EXCELLENT
            overallQuality >= 0.5 -> SignalQuality.GOOD
            overallQuality >= 0.25 -> SignalQuality.FAIR
            else -> SignalQuality.POOR
        }
    }

    fun getConfidence(): Float {
        val quality = assessSignalQuality()
        return when (quality) {
            SignalQuality.EXCELLENT -> 0.95f
            SignalQuality.GOOD -> 0.80f
            SignalQuality.FAIR -> 0.60f
            SignalQuality.POOR -> 0.30f
        }
    }

    fun getFilteredBuffer(): List<Double> = filteredBuffer.toList()

    fun getBufferSize(): Int = filteredBuffer.size

    // ------------------------------------
    // Private Helpers
    // ------------------------------------

    private fun applyBandpassFilter(input: Double): Double {
        // Second-order IIR bandpass filter
        // Butterworth approximation for 0.67-3.5 Hz at 30 Hz sample rate
        val w0 = 2 * PI * ((LOW_CUTOFF_HZ + HIGH_CUTOFF_HZ) / 2) / SAMPLE_RATE
        val bw = 2 * PI * (HIGH_CUTOFF_HZ - LOW_CUTOFF_HZ) / SAMPLE_RATE
        val alpha = sin(bw) / 2.0

        val b0 = alpha
        val b1 = 0.0
        val b2 = -alpha
        val a0 = 1.0 + alpha
        val a1 = -2.0 * cos(w0)
        val a2 = 1.0 - alpha

        val output = (b0 / a0) * input +
                (b1 / a0) * prevInput[0] +
                (b2 / a0) * prevInput[1] -
                (a1 / a0) * prevOutput[0] -
                (a2 / a0) * prevOutput[1]

        // Shift history
        prevInput[1] = prevInput[0]
        prevInput[0] = input
        prevOutput[1] = prevOutput[0]
        prevOutput[0] = output

        return output
    }

    private fun calculateAdaptiveThreshold(): Double {
        if (filteredBuffer.size < 10) return 0.0

        val recent = filteredBuffer.takeLast(minOf(filteredBuffer.size, 90)) // Last 3 seconds
        val mean = recent.average()
        val maxVal = recent.maxOrNull() ?: 0.0

        // Threshold at 40% of the max amplitude above mean
        return mean + (maxVal - mean) * 0.4
    }
}

enum class SignalQuality(val displayName: String, val emoji: String) {
    EXCELLENT("Excellent", "🟢"),
    GOOD("Good", "🔵"),
    FAIR("Fair", "🟡"),
    POOR("Poor", "🔴")
}
