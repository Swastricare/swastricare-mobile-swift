package com.swastricare.health.ui.screens.heartrate

import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.domain.model.heartrate.MeasurementPhase
import com.swastricare.health.domain.model.heartrate.MeasurementState
import com.swastricare.health.domain.model.heartrate.SignalQuality
import com.swastricare.health.domain.usecase.heartrate.ClearHeartRateHistoryUseCase
import com.swastricare.health.domain.usecase.heartrate.GetHeartRateHistoryUseCase
import com.swastricare.health.domain.usecase.heartrate.MeasureHeartRateUseCase
import com.swastricare.health.domain.usecase.heartrate.SaveHeartRateMeasurementUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for HeartRate screen (new Clean Architecture version).
 */
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
    val isMeasuring: Boolean get() = measurementState.isMeasuring()
    val showResult: Boolean get() = measurementState == MeasurementState.RESULT
}

/**
 * ViewModel for HeartRate screen.
 * Migrated to Clean Architecture with Hilt dependency injection.
 */
@HiltViewModel
class HeartRateViewModelNew @Inject constructor(
    private val measureHeartRateUseCase: MeasureHeartRateUseCase,
    private val saveHeartRateMeasurementUseCase: SaveHeartRateMeasurementUseCase,
    private val getHeartRateHistoryUseCase: GetHeartRateHistoryUseCase,
    private val clearHeartRateHistoryUseCase: ClearHeartRateHistoryUseCase,
    private val appAnalyticsService: AppAnalyticsService
) : ViewModel() {

    private val _uiState = MutableStateFlow(HeartRateUiState())
    val uiState: StateFlow<HeartRateUiState> = _uiState.asStateFlow()

    private var resultHandled = false

    init {
        loadLastReading()
        collectMeasurementFlows()
    }

    // ── Actions ──

    /**
     * Start a new heart rate measurement.
     */
    fun startMeasurement(previewView: PreviewView, lifecycleOwner: LifecycleOwner) {
        resultHandled = false
        _uiState.update { it.copy(error = null) }

        viewModelScope.launch {
            when (measureHeartRateUseCase(previewView, lifecycleOwner)) {
                is ResultWrapper.Success -> {
                    // Measurement started successfully
                }
                is ResultWrapper.Error -> {
                    _uiState.update {
                        it.copy(error = "Failed to start measurement. Please check camera permissions.")
                    }
                }
                is ResultWrapper.Loading -> {}
            }
        }
    }

    /**
     * Cancel the current measurement.
     */
    fun cancelMeasurement() {
        measureHeartRateUseCase.stop()
        _uiState.update {
            it.copy(
                measurementProgress = 0f,
                currentBpm = 0,
                error = null
            )
        }
    }

    /**
     * Clear all heart rate history.
     */
    fun clearReadings() {
        viewModelScope.launch {
            when (clearHeartRateHistoryUseCase()) {
                is ResultWrapper.Success -> {
                    _uiState.update { it.copy(lastBpm = 0) }
                }
                is ResultWrapper.Error -> {
                    _uiState.update { it.copy(error = "Failed to clear readings") }
                }
                is ResultWrapper.Loading -> {}
            }
        }
    }

    // ── Private helpers ──

    private fun loadLastReading() {
        viewModelScope.launch {
            val lastMeasurement = getHeartRateHistoryUseCase.getLastMeasurement()
            if (lastMeasurement != null) {
                _uiState.update {
                    it.copy(
                        lastBpm = lastMeasurement.bpm,
                        confidence = lastMeasurement.confidence,
                        source = lastMeasurement.source.displayName
                    )
                }
            }
        }
    }

    private fun collectMeasurementFlows() {
        // Collect measurement state
        viewModelScope.launch {
            measureHeartRateUseCase.getMeasurementState().collect { state ->
                _uiState.update { it.copy(measurementState = state) }

                // Handle result
                if (state == MeasurementState.RESULT && !resultHandled) {
                    resultHandled = true
                    handleMeasurementResult()
                }

                // Handle errors
                if (state == MeasurementState.ERROR) {
                    _uiState.update {
                        it.copy(error = "Measurement failed. Please try again.")
                    }
                }
            }
        }

        // Collect current BPM
        viewModelScope.launch {
            measureHeartRateUseCase.getCurrentBPM().collect { bpm ->
                _uiState.update { it.copy(currentBpm = bpm) }
            }
        }

        // Collect progress
        viewModelScope.launch {
            measureHeartRateUseCase.getProgress().collect { progress ->
                _uiState.update { it.copy(measurementProgress = progress) }
            }
        }

        // Collect signal quality
        viewModelScope.launch {
            measureHeartRateUseCase.getSignalQuality().collect { quality ->
                _uiState.update { it.copy(signalQuality = quality) }
            }
        }

        // Collect phase
        viewModelScope.launch {
            measureHeartRateUseCase.getPhase().collect { phase ->
                _uiState.update { it.copy(phase = phase) }
            }
        }

        // Collect waveform data
        viewModelScope.launch {
            measureHeartRateUseCase.getWaveformData().collect { waveform ->
                _uiState.update { it.copy(waveformData = waveform) }
            }
        }
    }

    private fun handleMeasurementResult() {
        val result = measureHeartRateUseCase.getResult()
        if (result != null) {
            val measurement = result.toHeartRateMeasurement()

            // Save the measurement
            viewModelScope.launch {
                when (saveHeartRateMeasurementUseCase(measurement, writeToHealthConnect = true)) {
                    is ResultWrapper.Success -> {
                        _uiState.update {
                            it.copy(
                                lastBpm = measurement.bpm,
                                confidence = measurement.confidence,
                                source = measurement.source.displayName
                            )
                        }

                        // Log to analytics
                        appAnalyticsService.trackHeartbeatMeasurement(
                            measurement.bpm,
                            measurement.confidence
                        )
                    }
                    is ResultWrapper.Error -> {
                        _uiState.update {
                            it.copy(error = "Failed to save measurement")
                        }
                    }
                    is ResultWrapper.Loading -> {}
                }
            }
        } else {
            _uiState.update {
                it.copy(error = "Could not determine heart rate. Please try again with your finger firmly on the camera.")
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        measureHeartRateUseCase.stop()
    }
}
