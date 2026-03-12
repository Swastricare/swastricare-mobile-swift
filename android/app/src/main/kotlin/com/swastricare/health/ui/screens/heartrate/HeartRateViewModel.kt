package com.swastricare.health.ui.screens.heartrate

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.data.services.HeartRateDetector
import com.swastricare.health.data.services.MeasurementPhase
import com.swastricare.health.data.services.MeasurementState
import com.swastricare.health.data.services.SignalQuality
import com.swastricare.health.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

// ─────────────────────────────────────
// MARK: - Data Models
// ─────────────────────────────────────

@Serializable
data class HeartRateReading(
    val bpm: Int,
    val timestamp: String, // ISO 8601
    val source: String,    // "Camera" or "Health Connect"
    val confidence: Float = 0.9f
)

// ─────────────────────────────────────
// MARK: - UI State
// ─────────────────────────────────────

data class HeartRateUiState(
    val measurementState: MeasurementState = MeasurementState.IDLE,
    val measurementProgress: Float = 0f,
    val currentBpm: Int = 0,
    val lastBpm: Int = 0,
    val confidence: Float = 0.95f,
    val source: String = "Camera",
    val signalQuality: SignalQuality = SignalQuality.POOR,
    val phase: MeasurementPhase = MeasurementPhase.PREPARING,
    val waveformData: List<Float> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
) {
    val isMeasuring: Boolean get() = measurementState in listOf(
        MeasurementState.PREPARING, MeasurementState.CALIBRATING,
        MeasurementState.MEASURING, MeasurementState.COMPLETING
    )
    val showResult: Boolean get() = measurementState == MeasurementState.RESULT
}

// ─────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────

class HeartRateViewModel(
    private val context: Context = AppContainer.context,
    private val prefs: SharedPreferences = AppContainer.sharedPreferences,
    private val appAnalyticsService: AppAnalyticsService = AppContainer.appAnalyticsService
) : ViewModel() {

    companion object {
        private const val TAG = "HeartRateViewModel"
        private const val PREF_KEY_READINGS = "heart_rate_readings"
    }

    private val detector = HeartRateDetector(context)
    private var resultHandled = false

    private val _uiState = MutableStateFlow(HeartRateUiState())
    val uiState: StateFlow<HeartRateUiState> = _uiState.asStateFlow()

    private val json = Json { ignoreUnknownKeys = true }

    init {
        loadLastReading()
        collectDetectorFlows()
    }

    private fun loadLastReading() {
        val readings = getReadings()
        val lastReading = readings.lastOrNull()
        if (lastReading != null) {
            _uiState.update {
                it.copy(
                    lastBpm = lastReading.bpm,
                    confidence = lastReading.confidence,
                    source = lastReading.source
                )
            }
        }
    }

    /**
     * Collect all StateFlows from the HeartRateDetector and map them
     * into the single HeartRateUiState.
     */
    private fun collectDetectorFlows() {
        viewModelScope.launch {
            detector.measurementState.collect { state ->
                _uiState.update { it.copy(measurementState = state) }

                // When detector reaches RESULT, extract the result and save it
                if (state == MeasurementState.RESULT && !resultHandled) {
                    resultHandled = true
                    handleMeasurementResult()
                }

                // Surface errors
                if (state == MeasurementState.ERROR) {
                    _uiState.update {
                        it.copy(error = "Measurement failed. Please try again.")
                    }
                }
            }
        }

        viewModelScope.launch {
            detector.currentBPM.collect { bpm ->
                _uiState.update { it.copy(currentBpm = bpm) }
            }
        }

        viewModelScope.launch {
            detector.progress.collect { progress ->
                _uiState.update { it.copy(measurementProgress = progress) }
            }
        }

        viewModelScope.launch {
            detector.signalQuality.collect { quality ->
                _uiState.update { it.copy(signalQuality = quality) }
            }
        }

        viewModelScope.launch {
            detector.phase.collect { phase ->
                _uiState.update { it.copy(phase = phase) }
            }
        }

        viewModelScope.launch {
            detector.waveformData.collect { waveform ->
                _uiState.update { it.copy(waveformData = waveform) }
            }
        }
    }

    // ── Measurement Control ──

    fun startMeasurement(previewView: PreviewView, lifecycleOwner: LifecycleOwner) {
        resultHandled = false
        _uiState.update { it.copy(error = null) }
        detector.startMeasurement(previewView, lifecycleOwner)
    }

    fun cancelMeasurement() {
        detector.stopMeasurement()
        _uiState.update {
            it.copy(
                measurementProgress = 0f,
                currentBpm = 0,
                error = null
            )
        }
    }

    // ── Result Handling ──

    private fun handleMeasurementResult() {
        val result = detector.getResult()
        if (result != null) {
            Log.d(TAG, "Measurement complete: ${result.bpm} BPM, confidence=${result.confidence}, quality=${result.quality}")

            // Save reading to persistence
            saveReading(
                HeartRateReading(
                    bpm = result.bpm,
                    timestamp = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                    source = "Camera",
                    confidence = result.confidence
                )
            )

            _uiState.update {
                it.copy(
                    lastBpm = result.bpm,
                    confidence = result.confidence,
                    source = "Camera"
                )
            }

            // Log heart rate measurement to analytics
            appAnalyticsService.trackHeartbeatMeasurement(result.bpm, result.confidence)

            // Write to Health Connect
            viewModelScope.launch {
                AppContainer.healthConnectService.writeHeartRate(result.bpm.toLong())
            }
        } else {
            Log.w(TAG, "Measurement completed but no result available")
            _uiState.update {
                it.copy(error = "Could not determine heart rate. Please try again with your finger firmly on the camera.")
            }
        }
    }

    // ── Persistence ──

    fun getReadings(): List<HeartRateReading> {
        val raw = prefs.getString(PREF_KEY_READINGS, null) ?: return emptyList()
        return try {
            json.decodeFromString<List<HeartRateReading>>(raw)
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun saveReading(reading: HeartRateReading) {
        val readings = getReadings().toMutableList()
        readings.add(reading)
        // Keep last 500 readings
        val trimmed = if (readings.size > 500) readings.takeLast(500) else readings
        prefs.edit().putString(PREF_KEY_READINGS, json.encodeToString(trimmed)).apply()
    }

    fun clearReadings() {
        prefs.edit().remove(PREF_KEY_READINGS).apply()
        _uiState.update { it.copy(lastBpm = 0) }
    }

    // ── Lifecycle ──

    override fun onCleared() {
        super.onCleared()
        detector.stopMeasurement()
    }
}
