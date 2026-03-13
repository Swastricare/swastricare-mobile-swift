package com.swastricare.health.domain.model.heartrate

import java.time.LocalDateTime

/**
 * Domain model for a heart rate measurement.
 * Represents a single BPM reading with metadata.
 */
data class HeartRateMeasurement(
    val bpm: Int,
    val timestamp: LocalDateTime = LocalDateTime.now(),
    val source: MeasurementSource = MeasurementSource.CAMERA,
    val confidence: Float = 0.9f,
    val quality: SignalQuality = SignalQuality.GOOD,
    val category: BPMCategory = BPMCategory.fromBPM(bpm)
) {
    /**
     * Validates the measurement.
     */
    fun isValid(): Boolean = bpm in 30..220 && confidence >= 0.5f

    /**
     * Returns a formatted string representation.
     */
    fun toDisplayString(): String = "$bpm BPM"
}

/**
 * Source of the heart rate measurement.
 */
enum class MeasurementSource(val displayName: String) {
    CAMERA("Camera"),
    HEALTH_CONNECT("Health Connect"),
    MANUAL("Manual")
}

/**
 * Signal quality assessment.
 */
enum class SignalQuality(val displayName: String) {
    POOR("Poor"),
    FAIR("Fair"),
    GOOD("Good"),
    EXCELLENT("Excellent");

    companion object {
        fun fromConfidence(confidence: Float): SignalQuality = when {
            confidence >= 0.9f -> EXCELLENT
            confidence >= 0.75f -> GOOD
            confidence >= 0.6f -> FAIR
            else -> POOR
        }
    }
}

/**
 * BPM category classification.
 */
enum class BPMCategory(
    val displayName: String,
    val colorHex: Long,
    val description: String
) {
    BRADYCARDIA(
        "Bradycardia",
        0xFF0A84FF,
        "Below normal resting heart rate"
    ),
    NORMAL(
        "Normal",
        0xFF30D158,
        "Healthy resting heart rate"
    ),
    ELEVATED(
        "Elevated",
        0xFFFF9F0A,
        "Slightly elevated heart rate"
    ),
    TACHYCARDIA(
        "Tachycardia",
        0xFFFF375F,
        "Elevated resting heart rate"
    );

    companion object {
        fun fromBPM(bpm: Int): BPMCategory = when {
            bpm < 60 -> BRADYCARDIA
            bpm <= 100 -> NORMAL
            bpm <= 120 -> ELEVATED
            else -> TACHYCARDIA
        }
    }
}
