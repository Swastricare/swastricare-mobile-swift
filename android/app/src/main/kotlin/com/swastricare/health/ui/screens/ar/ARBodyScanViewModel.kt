package com.swastricare.health.ui.screens.ar

import android.graphics.PointF
import androidx.camera.core.ImageProxy
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.services.BodyScanResult
import com.swastricare.health.data.services.PoseDetectionService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Detection state for body scanning.
 */
enum class BodyDetectionState {
    SCANNING,
    DETECTED,
    NOT_FOUND
}

/**
 * Organ info displayed on the body overlay.
 */
data class OrganInfo(
    val name: String,
    val displayName: String,
    val emoji: String,
    val value: String,
    val detail: String
)

/**
 * AR Body Scan UI state.
 */
data class ARBodyScanState(
    val cameraPermissionGranted: Boolean = false,
    val detectionState: BodyDetectionState = BodyDetectionState.SCANNING,
    val bodyScanResult: BodyScanResult? = null,
    val selectedOrgan: OrganInfo? = null,
    val showDetailSheet: Boolean = false,
    // Health data for organ overlays
    val heartRate: Int = 72,
    val exerciseMinutes: Int = 45,
    val caloriesConsumed: Int = 1240,
    val hydrationCurrent: Int = 1250,
    val hydrationGoal: Int = 2500
)

/**
 * ViewModel for AR Body Scan screen.
 * Manages camera permission state, body detection, and health data overlays.
 */
@HiltViewModel
class ARBodyScanViewModel @Inject constructor() : ViewModel() {

    private val poseDetectionService = PoseDetectionService()

    private val _uiState = MutableStateFlow(ARBodyScanState())
    val uiState: StateFlow<ARBodyScanState> = _uiState.asStateFlow()

    private var frameCounter = 0
    private val processEveryNthFrame = 3 // Only process every 3rd frame for performance

    fun onPermissionResult(granted: Boolean) {
        _uiState.value = _uiState.value.copy(cameraPermissionGranted = granted)
    }

    /**
     * Process a camera frame through ML Kit pose detection.
     * Throttled to every Nth frame for performance.
     */
    fun processFrame(imageProxy: ImageProxy) {
        frameCounter++
        if (frameCounter % processEveryNthFrame != 0) {
            imageProxy.close()
            return
        }

        viewModelScope.launch {
            try {
                val result = poseDetectionService.processFrame(imageProxy)
                if (result != null) {
                    _uiState.value = _uiState.value.copy(
                        detectionState = BodyDetectionState.DETECTED,
                        bodyScanResult = result
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        detectionState = BodyDetectionState.NOT_FOUND,
                        bodyScanResult = null
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    detectionState = BodyDetectionState.NOT_FOUND,
                    bodyScanResult = null
                )
            }
        }
    }

    fun selectOrgan(organKey: String) {
        val info = getOrganInfo(organKey)
        _uiState.value = _uiState.value.copy(
            selectedOrgan = info,
            showDetailSheet = true
        )
    }

    fun dismissDetailSheet() {
        _uiState.value = _uiState.value.copy(
            showDetailSheet = false,
            selectedOrgan = null
        )
    }

    private fun getOrganInfo(organKey: String): OrganInfo {
        val state = _uiState.value
        return when (organKey) {
            "heart" -> OrganInfo(
                name = "heart",
                displayName = "Heart",
                emoji = "\u2764\uFE0F",
                value = "${state.heartRate} BPM",
                detail = "Your latest heart rate reading. A resting heart rate between 60-100 BPM is considered normal for adults."
            )
            "left_lung", "right_lung" -> OrganInfo(
                name = organKey,
                displayName = "Lungs",
                emoji = "\uD83E\uDEC1",
                value = "${state.exerciseMinutes} min today",
                detail = "Active exercise minutes tracked today. Aim for at least 30 minutes of moderate exercise daily."
            )
            "stomach" -> OrganInfo(
                name = "stomach",
                displayName = "Stomach",
                emoji = "\uD83C\uDF7D\uFE0F",
                value = "${state.caloriesConsumed} cal consumed",
                detail = "Total calories consumed today from tracked meals. Monitor your intake to maintain a balanced diet."
            )
            "liver" -> OrganInfo(
                name = "liver",
                displayName = "Liver",
                emoji = "\uD83E\uDEC0",
                value = "No data",
                detail = "Upload recent lab results to your Vault to see liver health insights here."
            )
            "left_kidney", "right_kidney" -> OrganInfo(
                name = organKey,
                displayName = "Kidneys",
                emoji = "\uD83D\uDCA7",
                value = "${state.hydrationCurrent}/${state.hydrationGoal} ml",
                detail = "Hydration status. Staying well-hydrated supports kidney function. Your goal is ${state.hydrationGoal} ml per day."
            )
            else -> OrganInfo(
                name = organKey,
                displayName = organKey.replaceFirstChar { it.uppercase() },
                emoji = "\uD83C\uDFE5",
                value = "No data",
                detail = "No health data available for this area."
            )
        }
    }

    override fun onCleared() {
        super.onCleared()
        poseDetectionService.close()
    }
}
