package com.swasthicare.mobile.ui.screens.heartrate

import android.content.Context
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.services.*
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

// ------------------------------------
// MARK: - UI State
// ------------------------------------

data class HeartRateUiState(
    val state: MeasurementState = MeasurementState.IDLE,
    val currentBPM: Int = 0,
    val signalQuality: SignalQuality = SignalQuality.POOR,
    val progress: Float = 0f,
    val phase: MeasurementPhase = MeasurementPhase.PREPARING,
    val waveformData: List<Float> = emptyList(),
    val result: HeartRateResult? = null,
    val hasAcceptedDisclaimer: Boolean = false,
    val showDisclaimer: Boolean = false,
    val isSaving: Boolean = false,
    val saved: Boolean = false,
    val error: String? = null
)

// ------------------------------------
// MARK: - ViewModel
// ------------------------------------

class HeartRateViewModel(
    private val context: Context,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(HeartRateUiState())
    val uiState: StateFlow<HeartRateUiState> = _uiState.asStateFlow()

    private val detector = HeartRateDetector(context)
    private val demoProfileId = "demo-profile-id"

    init {
        // Check if disclaimer was already accepted
        val prefs = context.getSharedPreferences("swasthicare_prefs", Context.MODE_PRIVATE)
        val accepted = prefs.getBoolean("heart_rate_disclaimer_accepted", false)
        _uiState.value = _uiState.value.copy(
            hasAcceptedDisclaimer = accepted,
            showDisclaimer = !accepted
        )

        // Observe detector state changes
        viewModelScope.launch {
            detector.measurementState.collect { state ->
                _uiState.value = _uiState.value.copy(state = state)
                if (state == MeasurementState.RESULT) {
                    _uiState.value = _uiState.value.copy(result = detector.getResult())
                }
            }
        }
        viewModelScope.launch {
            detector.currentBPM.collect { bpm ->
                _uiState.value = _uiState.value.copy(currentBPM = bpm)
            }
        }
        viewModelScope.launch {
            detector.signalQuality.collect { quality ->
                _uiState.value = _uiState.value.copy(signalQuality = quality)
            }
        }
        viewModelScope.launch {
            detector.progress.collect { progress ->
                _uiState.value = _uiState.value.copy(progress = progress)
            }
        }
        viewModelScope.launch {
            detector.phase.collect { phase ->
                _uiState.value = _uiState.value.copy(phase = phase)
            }
        }
        viewModelScope.launch {
            detector.waveformData.collect { data ->
                _uiState.value = _uiState.value.copy(waveformData = data)
            }
        }
    }

    fun acceptDisclaimer() {
        val prefs = context.getSharedPreferences("swasthicare_prefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("heart_rate_disclaimer_accepted", true).apply()
        _uiState.value = _uiState.value.copy(
            hasAcceptedDisclaimer = true,
            showDisclaimer = false
        )
    }

    fun startMeasurement(previewView: PreviewView, lifecycleOwner: LifecycleOwner) {
        _uiState.value = _uiState.value.copy(
            result = null,
            saved = false,
            error = null
        )
        detector.startMeasurement(previewView, lifecycleOwner)
    }

    fun stopMeasurement() {
        detector.stopMeasurement()
    }

    fun retake() {
        _uiState.value = _uiState.value.copy(
            state = MeasurementState.IDLE,
            result = null,
            currentBPM = 0,
            progress = 0f,
            saved = false,
            error = null
        )
    }

    fun saveResult() {
        val result = _uiState.value.result ?: return

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSaving = true)
            try {
                val record = VitalSignRecord(
                    id = UUID.randomUUID().toString(),
                    healthProfileId = demoProfileId,
                    vitalType = "heart_rate",
                    value = result.bpm.toDouble(),
                    unit = "bpm",
                    measuredAt = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                    source = "camera_ppg",
                    confidence = result.confidence.toDouble(),
                    notes = "Camera PPG measurement. Quality: ${result.quality.displayName}. Category: ${result.category.displayName}"
                )
                supabaseClient.from("vital_signs").upsert(record)
                _uiState.value = _uiState.value.copy(saved = true, isSaving = false)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = "Failed to save: ${e.localizedMessage}",
                    isSaving = false
                )
            }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    override fun onCleared() {
        super.onCleared()
        detector.stopMeasurement()
    }
}

// ------------------------------------
// MARK: - Supabase DTO
// ------------------------------------

@Serializable
data class VitalSignRecord(
    val id: String,
    @SerialName("health_profile_id") val healthProfileId: String,
    @SerialName("vital_type") val vitalType: String,
    val value: Double,
    val unit: String,
    @SerialName("measured_at") val measuredAt: String,
    val source: String = "camera_ppg",
    val confidence: Double = 0.0,
    val notes: String? = null
)
