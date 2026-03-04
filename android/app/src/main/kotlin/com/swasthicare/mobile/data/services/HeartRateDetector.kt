package com.swasthicare.mobile.data.services

import android.content.Context
import android.util.Log
import androidx.annotation.OptIn
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.nio.ByteBuffer
import java.util.Collections
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Heart Rate Detector using CameraX.
 * Analyses the red channel of camera frames (finger over lens + flashlight)
 * to extract PPG signal and calculate BPM.
 */
class HeartRateDetector(private val context: Context) {

    companion object {
        private const val TAG = "HeartRateDetector"
        const val MEASUREMENT_DURATION_MS = 30_000L // 30 seconds
        const val PREPARING_END_MS = 5_000L
        const val CALIBRATING_END_MS = 10_000L
        const val MEASURING_END_MS = 25_000L
    }

    private val processor = PPGSignalProcessor()
    // Recreate executor for each measurement to avoid shutdown-reuse issue (BUG-4)
    private var analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: androidx.camera.core.Camera? = null

    // State
    private val _measurementState = MutableStateFlow(MeasurementState.IDLE)
    val measurementState: StateFlow<MeasurementState> = _measurementState.asStateFlow()

    private val _currentBPM = MutableStateFlow(0)
    val currentBPM: StateFlow<Int> = _currentBPM.asStateFlow()

    private val _signalQuality = MutableStateFlow(SignalQuality.POOR)
    val signalQuality: StateFlow<SignalQuality> = _signalQuality.asStateFlow()

    private val _progress = MutableStateFlow(0f)
    val progress: StateFlow<Float> = _progress.asStateFlow()

    private val _phase = MutableStateFlow(MeasurementPhase.PREPARING)
    val phase: StateFlow<MeasurementPhase> = _phase.asStateFlow()

    private val _waveformData = MutableStateFlow<List<Float>>(emptyList())
    val waveformData: StateFlow<List<Float>> = _waveformData.asStateFlow()

    private var startTimeMs: Long = 0
    // Thread-safe list to prevent ConcurrentModificationException (BUG-5)
    private var bpmReadings: MutableList<Int> = Collections.synchronizedList(mutableListOf())

    fun startMeasurement(
        previewView: PreviewView,
        lifecycleOwner: LifecycleOwner
    ) {
        processor.reset()
        bpmReadings = Collections.synchronizedList(mutableListOf())
        _measurementState.value = MeasurementState.PREPARING
        _currentBPM.value = 0
        _signalQuality.value = SignalQuality.POOR
        _progress.value = 0f
        _phase.value = MeasurementPhase.PREPARING
        _waveformData.value = emptyList()
        startTimeMs = System.currentTimeMillis()

        // Create fresh executor for each measurement (BUG-4 fix)
        if (analysisExecutor.isShutdown) {
            analysisExecutor = Executors.newSingleThreadExecutor()
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                bindCamera(previewView, lifecycleOwner)
            } catch (e: Exception) {
                Log.e(TAG, "Camera provider failed", e)
                _measurementState.value = MeasurementState.ERROR
            }
        }, ContextCompat.getMainExecutor(context))
    }

    fun stopMeasurement() {
        // Disable torch safely (BUG-6 fix)
        try {
            camera?.cameraControl?.enableTorch(false)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to disable torch: ${e.message}")
        }

        try {
            cameraProvider?.unbindAll()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to unbind camera: ${e.message}")
        }

        camera = null
        analysisExecutor.shutdown()
        _measurementState.value = MeasurementState.IDLE
    }

    fun getResult(): HeartRateResult? {
        // Snapshot the list to avoid race conditions (BUG-25 fix)
        val snapshot = synchronized(bpmReadings) { bpmReadings.toList() }
        if (snapshot.isEmpty()) return null

        // Use median for robustness
        val sorted = snapshot.sorted()
        val medianBPM = sorted[sorted.size / 2]
        val confidence = processor.getConfidence()
        val errorMargin = when {
            confidence >= 0.8f -> 3
            confidence >= 0.6f -> 5
            else -> 8
        }

        val category = when {
            medianBPM < 60 -> BPMCategory.BRADYCARDIA
            medianBPM <= 100 -> BPMCategory.NORMAL
            medianBPM <= 120 -> BPMCategory.ELEVATED
            else -> BPMCategory.TACHYCARDIA
        }

        return HeartRateResult(
            bpm = medianBPM,
            confidence = confidence,
            errorMargin = errorMargin,
            category = category,
            quality = processor.assessSignalQuality()
        )
    }

    private fun bindCamera(previewView: PreviewView, lifecycleOwner: LifecycleOwner) {
        val provider = cameraProvider ?: return

        val preview = Preview.Builder().build().also {
            it.surfaceProvider = previewView.surfaceProvider
        }

        val imageAnalysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also {
                it.setAnalyzer(analysisExecutor) { imageProxy ->
                    processFrame(imageProxy)
                }
            }

        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

        try {
            provider.unbindAll()
            camera = provider.bindToLifecycle(
                lifecycleOwner,
                cameraSelector,
                preview,
                imageAnalysis
            )
            camera?.cameraControl?.enableTorch(true)
        } catch (e: Exception) {
            Log.e(TAG, "Camera binding failed", e)
            try { camera?.cameraControl?.enableTorch(false) } catch (_: Exception) {}
            try { cameraProvider?.unbindAll() } catch (_: Exception) {}
            _measurementState.value = MeasurementState.ERROR
        }
    }

    @OptIn(ExperimentalGetImage::class)
    private fun processFrame(imageProxy: ImageProxy) {
        try {
            val elapsed = System.currentTimeMillis() - startTimeMs
            val progressVal = (elapsed.toFloat() / MEASUREMENT_DURATION_MS).coerceIn(0f, 1f)
            _progress.value = progressVal

            val currentPhase = when {
                elapsed < PREPARING_END_MS -> MeasurementPhase.PREPARING
                elapsed < CALIBRATING_END_MS -> MeasurementPhase.CALIBRATING
                elapsed < MEASURING_END_MS -> MeasurementPhase.MEASURING
                elapsed < MEASUREMENT_DURATION_MS -> MeasurementPhase.COMPLETING
                else -> MeasurementPhase.COMPLETING
            }
            _phase.value = currentPhase
            _measurementState.value = when (currentPhase) {
                MeasurementPhase.PREPARING -> MeasurementState.PREPARING
                MeasurementPhase.CALIBRATING -> MeasurementState.CALIBRATING
                MeasurementPhase.MEASURING -> MeasurementState.MEASURING
                MeasurementPhase.COMPLETING -> MeasurementState.COMPLETING
            }

            val redAvg = extractRedChannelAverage(imageProxy)
            processor.addSample(redAvg)

            _signalQuality.value = processor.assessSignalQuality()

            val filtered = processor.getFilteredBuffer()
            val waveform = filtered.takeLast(90).map { it.toFloat() }
            _waveformData.value = waveform

            if (elapsed > CALIBRATING_END_MS) {
                processor.calculateBPM()?.let { bpm ->
                    val bpmInt = bpm.toInt()
                    _currentBPM.value = bpmInt
                    bpmReadings.add(bpmInt)
                }
            }

            if (elapsed >= MEASUREMENT_DURATION_MS) {
                _measurementState.value = MeasurementState.RESULT
                try { camera?.cameraControl?.enableTorch(false) } catch (_: Exception) {}
                try { cameraProvider?.unbindAll() } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            Log.e(TAG, "Frame processing error", e)
        } finally {
            imageProxy.close()
        }
    }

    @OptIn(ExperimentalGetImage::class)
    private fun extractRedChannelAverage(imageProxy: ImageProxy): Double {
        val image = imageProxy.image ?: return 0.0

        val yPlane = image.planes[0]
        val buffer: ByteBuffer = yPlane.buffer
        val data = ByteArray(buffer.remaining())
        buffer.get(data)

        var sum = 0L
        for (byte in data) {
            sum += (byte.toInt() and 0xFF)
        }

        return sum.toDouble() / data.size
    }
}

// ------------------------------------
// MARK: - Supporting Types
// ------------------------------------

enum class MeasurementState {
    IDLE,
    PREPARING,
    CALIBRATING,
    MEASURING,
    COMPLETING,
    RESULT,
    ERROR
}

enum class MeasurementPhase(val displayName: String) {
    PREPARING("Preparing..."),
    CALIBRATING("Calibrating..."),
    MEASURING("Measuring..."),
    COMPLETING("Completing...")
}

enum class BPMCategory(val displayName: String, val colorHex: Long) {
    BRADYCARDIA("Bradycardia", 0xFF0A84FF),
    NORMAL("Normal", 0xFF30D158),
    ELEVATED("Elevated", 0xFFFF9F0A),
    TACHYCARDIA("Tachycardia", 0xFFFF375F)
}

data class HeartRateResult(
    val bpm: Int,
    val confidence: Float,
    val errorMargin: Int,
    val category: BPMCategory,
    val quality: SignalQuality
)
