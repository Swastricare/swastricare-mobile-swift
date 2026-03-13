package com.swastricare.health.data.services

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import com.swastricare.health.domain.model.heartrate.MeasurementPhase
import com.swastricare.health.domain.model.heartrate.MeasurementResult
import com.swastricare.health.domain.model.heartrate.MeasurementState
import com.swastricare.health.domain.model.heartrate.SignalQuality
import com.swastricare.health.domain.usecase.heartrate.HeartRateDetectorService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Implementation of HeartRateDetectorService that wraps the legacy HeartRateDetector.
 * Adapts the old service to the new domain interface.
 */
class HeartRateDetectorServiceImpl @Inject constructor(
    @ApplicationContext context: Context
) : HeartRateDetectorService {

    private val detector = HeartRateDetector(context)

    // Adapt detector state flows to domain types
    private val _measurementState = MutableStateFlow(MeasurementState.IDLE)
    override val measurementState: StateFlow<MeasurementState> = _measurementState.asStateFlow()

    private val _currentBPM = MutableStateFlow(0)
    override val currentBPM: StateFlow<Int> = _currentBPM.asStateFlow()

    private val _signalQuality = MutableStateFlow(SignalQuality.POOR)
    override val signalQuality: StateFlow<SignalQuality> = _signalQuality.asStateFlow()

    private val _progress = MutableStateFlow(0f)
    override val progress: StateFlow<Float> = _progress.asStateFlow()

    private val _phase = MutableStateFlow(MeasurementPhase.PREPARING)
    override val phase: StateFlow<MeasurementPhase> = _phase.asStateFlow()

    private val _waveformData = MutableStateFlow<List<Float>>(emptyList())
    override val waveformData: StateFlow<List<Float>> = _waveformData.asStateFlow()

    init {
        // Map detector flows to domain flows
        kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main).launch {
            detector.measurementState.collect { state ->
                _measurementState.value = when (state) {
                    com.swastricare.health.data.services.MeasurementState.IDLE -> MeasurementState.IDLE
                    com.swastricare.health.data.services.MeasurementState.PREPARING -> MeasurementState.PREPARING
                    com.swastricare.health.data.services.MeasurementState.CALIBRATING -> MeasurementState.CALIBRATING
                    com.swastricare.health.data.services.MeasurementState.MEASURING -> MeasurementState.MEASURING
                    com.swastricare.health.data.services.MeasurementState.COMPLETING -> MeasurementState.COMPLETING
                    com.swastricare.health.data.services.MeasurementState.RESULT -> MeasurementState.RESULT
                    com.swastricare.health.data.services.MeasurementState.ERROR -> MeasurementState.ERROR
                }
            }
        }

        kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main).launch {
            detector.currentBPM.collect { bpm ->
                _currentBPM.value = bpm
            }
        }

        kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main).launch {
            detector.signalQuality.collect { quality ->
                _signalQuality.value = when (quality) {
                    com.swastricare.health.data.services.SignalQuality.POOR -> SignalQuality.POOR
                    com.swastricare.health.data.services.SignalQuality.FAIR -> SignalQuality.FAIR
                    com.swastricare.health.data.services.SignalQuality.GOOD -> SignalQuality.GOOD
                    com.swastricare.health.data.services.SignalQuality.EXCELLENT -> SignalQuality.EXCELLENT
                }
            }
        }

        kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main).launch {
            detector.progress.collect { progress ->
                _progress.value = progress
            }
        }

        kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main).launch {
            detector.phase.collect { phase ->
                _phase.value = when (phase) {
                    com.swastricare.health.data.services.MeasurementPhase.PREPARING -> MeasurementPhase.PREPARING
                    com.swastricare.health.data.services.MeasurementPhase.CALIBRATING -> MeasurementPhase.CALIBRATING
                    com.swastricare.health.data.services.MeasurementPhase.MEASURING -> MeasurementPhase.MEASURING
                    com.swastricare.health.data.services.MeasurementPhase.COMPLETING -> MeasurementPhase.COMPLETING
                }
            }
        }

        kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main).launch {
            detector.waveformData.collect { waveform ->
                _waveformData.value = waveform
            }
        }
    }

    override fun startMeasurement(previewView: PreviewView, lifecycleOwner: LifecycleOwner) {
        detector.startMeasurement(previewView, lifecycleOwner)
    }

    override fun stopMeasurement() {
        detector.stopMeasurement()
    }

    override fun getResult(): MeasurementResult? {
        val result = detector.getResult() ?: return null

        return MeasurementResult(
            bpm = result.bpm,
            confidence = result.confidence,
            errorMargin = result.errorMargin,
            category = com.swastricare.health.domain.model.heartrate.BPMCategory.fromBPM(result.bpm),
            quality = when (result.quality) {
                com.swastricare.health.data.services.SignalQuality.POOR -> SignalQuality.POOR
                com.swastricare.health.data.services.SignalQuality.FAIR -> SignalQuality.FAIR
                com.swastricare.health.data.services.SignalQuality.GOOD -> SignalQuality.GOOD
                com.swastricare.health.data.services.SignalQuality.EXCELLENT -> SignalQuality.EXCELLENT
            }
        )
    }
}
