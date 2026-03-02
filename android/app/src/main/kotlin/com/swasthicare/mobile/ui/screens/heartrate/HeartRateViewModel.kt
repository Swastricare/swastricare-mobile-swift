package com.swasthicare.mobile.ui.screens.heartrate

import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.di.AppContainer
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
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
    val isMeasuring: Boolean = false,
    val showResult: Boolean = false,
    val measurementProgress: Float = 0f,
    val currentBpm: Int = 0,
    val lastBpm: Int = 0,
    val confidence: Float = 0.95f,
    val source: String = "Camera",
    val isLoading: Boolean = false,
    val error: String? = null
)

// ─────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────

class HeartRateViewModel(
    private val prefs: SharedPreferences = AppContainer.sharedPreferences
) : ViewModel() {

    private val _uiState = MutableStateFlow(HeartRateUiState())
    val uiState: StateFlow<HeartRateUiState> = _uiState.asStateFlow()

    private var measurementJob: Job? = null

    private val json = Json { ignoreUnknownKeys = true }

    companion object {
        private const val PREF_KEY_READINGS = "heart_rate_readings"
    }

    init {
        loadLastReading()
    }

    private fun loadLastReading() {
        val readings = getReadings()
        val lastReading = readings.lastOrNull()
        if (lastReading != null) {
            _uiState.value = _uiState.value.copy(
                lastBpm = lastReading.bpm,
                confidence = lastReading.confidence,
                source = lastReading.source
            )
        }
    }

    fun startMeasurement() {
        measurementJob?.cancel()
        _uiState.value = _uiState.value.copy(
            isMeasuring = true,
            showResult = false,
            measurementProgress = 0f,
            currentBpm = 0
        )

        measurementJob = viewModelScope.launch {
            // Simulate camera PPG measurement over ~10 seconds
            val totalSteps = 50
            val stepDelayMs = 200L
            var simulatedBpm = 0

            for (step in 1..totalSteps) {
                delay(stepDelayMs)
                val progress = step.toFloat() / totalSteps

                // Simulate BPM stabilizing
                simulatedBpm = when {
                    step < 10 -> (60..120).random()
                    step < 25 -> (68..85).random()
                    step < 40 -> (70..78).random()
                    else -> (72..76).random()
                }

                _uiState.value = _uiState.value.copy(
                    measurementProgress = progress,
                    currentBpm = simulatedBpm
                )
            }

            // Final result
            val finalBpm = (71..77).random()
            val confidence = 0.92f + (Math.random() * 0.07f).toFloat()

            // Save reading
            saveReading(
                HeartRateReading(
                    bpm = finalBpm,
                    timestamp = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                    source = "Camera",
                    confidence = confidence
                )
            )

            _uiState.value = _uiState.value.copy(
                isMeasuring = false,
                showResult = true,
                lastBpm = finalBpm,
                confidence = confidence,
                source = "Camera"
            )
        }
    }

    fun cancelMeasurement() {
        measurementJob?.cancel()
        _uiState.value = _uiState.value.copy(
            isMeasuring = false,
            showResult = false,
            measurementProgress = 0f,
            currentBpm = 0
        )
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
        _uiState.value = _uiState.value.copy(lastBpm = 0)
    }
}
