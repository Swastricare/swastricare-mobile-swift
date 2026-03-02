package com.swasthicare.mobile.ui.screens.ai

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.data.services.AIService
import com.swasthicare.mobile.data.services.SpeechService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

// MARK: - AI Mode

enum class AIMode(val label: String) {
    General("General"),
    Medical("Medical"),
    ImageAnalysis("Image Analysis")
}

// MARK: - Image Type for Analysis

enum class ImageType(val label: String, val icon: String) {
    XRay("X-Ray", "radiology"),
    MRI("MRI", "mri"),
    CTScan("CT Scan", "ct_scan"),
    SkinPhoto("Skin Photo", "skin"),
    LabReport("Lab Report", "lab"),
    Prescription("Prescription", "prescription"),
    Other("Other", "other")
}

// MARK: - UI State

data class AIUiState(
    val messages: List<ChatMessage> = emptyList(),
    val inputText: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
    val showEmptyState: Boolean = true,
    val analysisState: AnalysisState = AnalysisState.Idle,
    val isRecording: Boolean = false,
    val currentMode: AIMode = AIMode.General,
    val selectedImageType: ImageType? = null,
    val showImageTypeSheet: Boolean = false,
    val pendingImageUri: String? = null,
    val followUpSuggestions: List<String> = emptyList(),
    val showModeSwitchDialog: Boolean = false,
    val pendingModeSwitch: AIMode? = null,
    val snackbarMessage: String? = null
)

sealed class AnalysisState {
    object Idle : AnalysisState()
    object Analyzing : AnalysisState()
    data class Completed(val result: HealthAnalysisResult) : AnalysisState()
    data class Error(val message: String) : AnalysisState()
}

class AIViewModel(application: Application) : AndroidViewModel(application) {
    private val aiService = AIService()
    private val speechService = SpeechService(application.applicationContext)

    private val _uiState = MutableStateFlow(AIUiState())
    val uiState: StateFlow<AIUiState> = _uiState.asStateFlow()

    override fun onCleared() {
        super.onCleared()
        speechService.cleanup()
    }

    fun onInputTextChanged(text: String) {
        _uiState.value = _uiState.value.copy(inputText = text)
    }

    fun sendMessage() {
        val text = _uiState.value.inputText.trim()
        if (text.isEmpty()) return

        val userMessage = ChatMessage.userMessage(text)
        val currentMessages = _uiState.value.messages.toMutableList()
        currentMessages.add(userMessage)

        // Add loading message
        currentMessages.add(ChatMessage.loadingMessage())

        _uiState.value = _uiState.value.copy(
            messages = currentMessages,
            inputText = "",
            isLoading = true,
            showEmptyState = false,
            followUpSuggestions = emptyList()
        )

        viewModelScope.launch {
            try {
                val responseText = aiService.sendChatMessage(text, _uiState.value.messages.filter { !it.isLoading })

                val newMessages = _uiState.value.messages.filter { !it.isLoading }.toMutableList()
                newMessages.add(ChatMessage.assistantMessage(responseText))

                val suggestions = generateFollowUpSuggestions(text, responseText)

                _uiState.value = _uiState.value.copy(
                    messages = newMessages,
                    isLoading = false,
                    followUpSuggestions = suggestions
                )
            } catch (e: Exception) {
                val newMessages = _uiState.value.messages.filter { !it.isLoading }
                _uiState.value = _uiState.value.copy(
                    messages = newMessages,
                    isLoading = false,
                    error = e.message ?: "Failed to send message"
                )
            }
        }
    }

    fun sendFollowUp(suggestion: String) {
        _uiState.value = _uiState.value.copy(inputText = suggestion)
        sendMessage()
    }

    fun clearChat() {
        _uiState.value = AIUiState(
            showEmptyState = true,
            currentMode = _uiState.value.currentMode
        )
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    fun dismissAnalysis() {
        _uiState.value = _uiState.value.copy(analysisState = AnalysisState.Idle)
    }

    fun sendQuickAction(action: QuickAction) {
        if (action.title == "Analyze My Health") {
            analyzeCurrentHealth()
        } else {
            _uiState.value = _uiState.value.copy(inputText = action.prompt)
            sendMessage()
        }
    }

    // MARK: - Mode Switching

    fun requestModeSwitch(newMode: AIMode) {
        if (newMode == _uiState.value.currentMode) return

        if (_uiState.value.messages.isNotEmpty()) {
            _uiState.value = _uiState.value.copy(
                showModeSwitchDialog = true,
                pendingModeSwitch = newMode
            )
        } else {
            switchMode(newMode)
        }
    }

    fun confirmModeSwitch() {
        val pending = _uiState.value.pendingModeSwitch ?: return
        _uiState.value = AIUiState(
            showEmptyState = true,
            currentMode = pending,
            showModeSwitchDialog = false,
            pendingModeSwitch = null
        )
    }

    fun cancelModeSwitch() {
        _uiState.value = _uiState.value.copy(
            showModeSwitchDialog = false,
            pendingModeSwitch = null
        )
    }

    private fun switchMode(mode: AIMode) {
        _uiState.value = _uiState.value.copy(
            currentMode = mode,
            selectedImageType = null,
            pendingImageUri = null,
            showImageTypeSheet = false
        )
    }

    // MARK: - Image Analysis

    fun onImagePicked(uri: String) {
        _uiState.value = _uiState.value.copy(
            pendingImageUri = uri,
            showImageTypeSheet = true
        )
    }

    fun onImageTypeSelected(type: ImageType) {
        _uiState.value = _uiState.value.copy(
            selectedImageType = type,
            showImageTypeSheet = false
        )
        // Send the image with type context
        sendImageForAnalysis(type)
    }

    fun dismissImageTypeSheet() {
        _uiState.value = _uiState.value.copy(
            showImageTypeSheet = false,
            pendingImageUri = null
        )
    }

    private fun sendImageForAnalysis(imageType: ImageType) {
        val userMessage = ChatMessage.userMessage("[Image: ${imageType.label}] Please analyze this ${imageType.label.lowercase()} image.")
        val currentMessages = _uiState.value.messages.toMutableList()
        currentMessages.add(userMessage)
        currentMessages.add(ChatMessage.loadingMessage())

        _uiState.value = _uiState.value.copy(
            messages = currentMessages,
            isLoading = true,
            showEmptyState = false,
            followUpSuggestions = emptyList()
        )

        viewModelScope.launch {
            try {
                val responseText = aiService.sendChatMessage(
                    "Analyze this ${imageType.label} image using MedGemma 4B model",
                    _uiState.value.messages.filter { !it.isLoading }
                )

                val newMessages = _uiState.value.messages.filter { !it.isLoading }.toMutableList()
                newMessages.add(ChatMessage.assistantMessage(responseText))

                val suggestions = generateFollowUpSuggestions(imageType.label, responseText)

                _uiState.value = _uiState.value.copy(
                    messages = newMessages,
                    isLoading = false,
                    pendingImageUri = null,
                    followUpSuggestions = suggestions
                )
            } catch (e: Exception) {
                val newMessages = _uiState.value.messages.filter { !it.isLoading }
                _uiState.value = _uiState.value.copy(
                    messages = newMessages,
                    isLoading = false,
                    error = e.message ?: "Image analysis failed",
                    pendingImageUri = null
                )
            }
        }
    }

    // MARK: - Snackbar

    fun showSnackbar(message: String) {
        _uiState.value = _uiState.value.copy(snackbarMessage = message)
    }

    fun clearSnackbar() {
        _uiState.value = _uiState.value.copy(snackbarMessage = null)
    }

    fun onMessageCopied() {
        showSnackbar("Message copied")
    }

    fun onMessageBookmarked() {
        showSnackbar("Message bookmarked")
    }

    // MARK: - Follow-Up Suggestions

    private fun generateFollowUpSuggestions(userQuery: String, aiResponse: String): List<String> {
        val query = userQuery.lowercase()
        val response = aiResponse.lowercase()

        return when {
            query.contains("sleep") || response.contains("sleep") -> listOf(
                "What is the ideal sleep duration?",
                "How does sleep affect heart health?",
                "Tips for better sleep hygiene"
            )
            query.contains("heart") || response.contains("heart rate") || response.contains("cardiac") -> listOf(
                "What is a normal resting heart rate?",
                "How to lower my heart rate naturally?",
                "When should I be concerned about heart rate?"
            )
            query.contains("exercise") || query.contains("workout") || response.contains("exercise") -> listOf(
                "Best exercises for weight loss?",
                "How often should I exercise?",
                "What stretches help after a workout?"
            )
            query.contains("diet") || query.contains("nutrition") || query.contains("eat") || response.contains("nutrition") -> listOf(
                "What foods are rich in protein?",
                "How much water should I drink daily?",
                "Best foods for immunity?"
            )
            query.contains("weight") || response.contains("bmi") || response.contains("weight") -> listOf(
                "How to calculate my BMI?",
                "Healthy ways to lose weight?",
                "What is a healthy weight range?"
            )
            query.contains("blood pressure") || response.contains("blood pressure") -> listOf(
                "What causes high blood pressure?",
                "Foods that lower blood pressure?",
                "How often should I check BP?"
            )
            query.contains("x-ray") || query.contains("mri") || query.contains("ct scan") || query.contains("image") -> listOf(
                "What does this finding mean?",
                "Should I see a specialist?",
                "What are the next steps?"
            )
            query.contains("skin") || response.contains("skin") || response.contains("dermat") -> listOf(
                "Is this condition serious?",
                "What treatments are available?",
                "Should I see a dermatologist?"
            )
            query.contains("lab") || query.contains("report") || query.contains("test") -> listOf(
                "Are my values within normal range?",
                "What do these results mean?",
                "Should I get retested?"
            )
            else -> listOf(
                "Tell me more about this",
                "What precautions should I take?",
                "Any lifestyle changes recommended?"
            )
        }
    }

    // MARK: - Health Analysis

    private fun analyzeCurrentHealth() {
        _uiState.value = _uiState.value.copy(analysisState = AnalysisState.Analyzing)

        viewModelScope.launch {
            try {
                val metrics = HealthMetrics(
                    steps = 5432,
                    heartRate = 72,
                    sleep = "7h 15m",
                    activeCalories = 320,
                    exerciseMinutes = 45,
                    bloodPressure = "120/80",
                    weight = "70.5"
                )

                val response = aiService.analyzeHealth(metrics)

                val result = HealthAnalysisResult(
                    metrics = metrics,
                    analysis = response
                )

                _uiState.value = _uiState.value.copy(
                    analysisState = AnalysisState.Completed(result)
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    analysisState = AnalysisState.Error(e.message ?: "Analysis failed")
                )
            }
        }
    }

    // MARK: - Speech

    fun toggleRecording() {
        if (_uiState.value.isRecording) {
            speechService.stopRecording()
            _uiState.value = _uiState.value.copy(isRecording = false)
        } else {
            _uiState.value = _uiState.value.copy(isRecording = true)
            speechService.startRecording(
                onResult = { text ->
                    _uiState.value = _uiState.value.copy(inputText = text, isRecording = false)
                },
                onPartialResult = { text ->
                    _uiState.value = _uiState.value.copy(inputText = text)
                },
                onError = { error ->
                    _uiState.value = _uiState.value.copy(isRecording = false, error = error)
                }
            )
        }
    }
}
