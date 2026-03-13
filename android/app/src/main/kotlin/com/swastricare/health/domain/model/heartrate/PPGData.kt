package com.swastricare.health.domain.model.heartrate

/**
 * Photoplethysmography (PPG) signal data.
 * Represents real-time signal processing state during heart rate measurement.
 */
data class PPGData(
    val rawValue: Double,
    val filteredValue: Double,
    val signalQuality: SignalQuality,
    val waveformData: List<Float> = emptyList(),
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Measurement state during heart rate detection.
 */
enum class MeasurementState {
    IDLE,
    PREPARING,
    CALIBRATING,
    MEASURING,
    COMPLETING,
    RESULT,
    ERROR;

    fun isMeasuring(): Boolean = this in listOf(
        PREPARING, CALIBRATING, MEASURING, COMPLETING
    )

    fun isFinished(): Boolean = this in listOf(RESULT, ERROR, IDLE)
}

/**
 * Measurement phase with progress information.
 */
enum class MeasurementPhase(
    val displayName: String,
    val description: String
) {
    PREPARING(
        "Preparing...",
        "Place finger over camera and flashlight"
    ),
    CALIBRATING(
        "Calibrating...",
        "Hold steady, calibrating signal"
    ),
    MEASURING(
        "Measuring...",
        "Reading heart rate"
    ),
    COMPLETING(
        "Completing...",
        "Finalizing measurement"
    )
}

/**
 * Complete heart rate measurement result with metadata.
 */
data class MeasurementResult(
    val bpm: Int,
    val confidence: Float,
    val errorMargin: Int,
    val category: BPMCategory,
    val quality: SignalQuality,
    val timestamp: Long = System.currentTimeMillis()
) {
    fun toHeartRateMeasurement(): HeartRateMeasurement {
        return HeartRateMeasurement(
            bpm = bpm,
            timestamp = java.time.Instant.ofEpochMilli(timestamp)
                .atZone(java.time.ZoneId.systemDefault())
                .toLocalDateTime(),
            source = MeasurementSource.CAMERA,
            confidence = confidence,
            quality = quality,
            category = category
        )
    }
}
