package com.swastricare.health.domain.usecase.heartrate

import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.heartrate.MeasurementResult
import com.swastricare.health.domain.model.heartrate.MeasurementState
import com.swastricare.health.domain.model.heartrate.PPGData
import com.swastricare.health.domain.model.heartrate.SignalQuality
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject

/**
 * Use case: Measure heart rate using camera PPG detection.
 * Encapsulates the business logic for heart rate measurement.
 */
interface HeartRateDetectorService {
    val measurementState: StateFlow<MeasurementState>
    val currentBPM: StateFlow<Int>
    val signalQuality: StateFlow<SignalQuality>
    val progress: StateFlow<Float>
    val phase: StateFlow<com.swastricare.health.domain.model.heartrate.MeasurementPhase>
    val waveformData: StateFlow<List<Float>>

    fun startMeasurement(previewView: PreviewView, lifecycleOwner: LifecycleOwner)
    fun stopMeasurement()
    fun getResult(): MeasurementResult?
}

/**
 * Use case for measuring heart rate via camera.
 */
class MeasureHeartRateUseCase @Inject constructor(
    private val detectorService: HeartRateDetectorService
) {
    /**
     * Start a heart rate measurement.
     *
     * @param previewView Camera preview view
     * @param lifecycleOwner Lifecycle owner for camera binding
     * @return Result indicating success or failure
     */
    suspend operator fun invoke(
        previewView: PreviewView,
        lifecycleOwner: LifecycleOwner
    ): ResultWrapper<Unit> {
        return try {
            detectorService.startMeasurement(previewView, lifecycleOwner)
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            ResultWrapper.Error(
                AppException.UnknownException(
                    "Failed to start measurement: ${e.message}",
                    e
                )
            )
        }
    }

    /**
     * Stop the current measurement.
     */
    fun stop() {
        detectorService.stopMeasurement()
    }

    /**
     * Get the measurement result.
     */
    fun getResult(): MeasurementResult? {
        return detectorService.getResult()
    }

    /**
     * Get measurement state flow.
     */
    fun getMeasurementState(): StateFlow<MeasurementState> {
        return detectorService.measurementState
    }

    /**
     * Get current BPM flow.
     */
    fun getCurrentBPM(): StateFlow<Int> {
        return detectorService.currentBPM
    }

    /**
     * Get signal quality flow.
     */
    fun getSignalQuality(): StateFlow<SignalQuality> {
        return detectorService.signalQuality
    }

    /**
     * Get progress flow.
     */
    fun getProgress(): StateFlow<Float> {
        return detectorService.progress
    }

    /**
     * Get phase flow.
     */
    fun getPhase(): StateFlow<com.swastricare.health.domain.model.heartrate.MeasurementPhase> {
        return detectorService.phase
    }

    /**
     * Get waveform data flow.
     */
    fun getWaveformData(): StateFlow<List<Float>> {
        return detectorService.waveformData
    }
}
