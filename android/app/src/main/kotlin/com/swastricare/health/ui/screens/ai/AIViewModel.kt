package com.swastricare.health.ui.screens.ai

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.models.*
import com.swastricare.health.data.repository.AIConversationRepository
import com.swastricare.health.data.repository.AIMessageRecord
import com.swastricare.health.data.repository.SupabaseAIConversationRepository
import com.swastricare.health.data.services.AIService
import com.swastricare.health.data.services.AnalyticsService
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.data.services.SpeechService
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.repository.ProfileRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

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
    val userName: String? = null,
    val analysisState: AnalysisState = AnalysisState.Idle,
    val isRecording: Boolean = false,
    val currentMode: AIMode = AIMode.General,
    val selectedImageType: ImageType? = null,
    val showImageTypeSheet: Boolean = false,
    val pendingImageUri: String? = null,
    val followUpSuggestions: List<String> = emptyList(),
    val showModeSwitchDialog: Boolean = false,
    val pendingModeSwitch: AIMode? = null,
    val snackbarMessage: String? = null,
    val showHistorySheet: Boolean = false,
    val historyConversations: List<com.swastricare.health.data.repository.AIConversation> = emptyList(),
    val isHistoryLoading: Boolean = false
)

sealed class AnalysisState {
    object Idle : AnalysisState()
    object Analyzing : AnalysisState()
    data class Completed(val result: HealthAnalysisResult) : AnalysisState()
    data class Error(val message: String) : AnalysisState()
}

@HiltViewModel
class AIViewModel @Inject constructor(
    private val aiService: AIService,
    private val conversationRepo: SupabaseAIConversationRepository,
    private val analyticsService: AnalyticsService,
    private val appAnalyticsService: AppAnalyticsService,
    private val healthConnectService: HealthConnectService,
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    @ApplicationContext private val appContext: Context
) : ViewModel() {

    private val speechService = SpeechService(appContext)

    private val _uiState = MutableStateFlow(AIUiState())
    val uiState: StateFlow<AIUiState> = _uiState.asStateFlow()

    private var currentConversationId: String? = null

    init {
        loadLastConversation()
        loadUserName()
    }

    private fun loadUserName() {
        viewModelScope.launch {
            try {
                val user = authRepository.getCurrentUser()
                if (user == null) {
                    Log.d("AIViewModel", "loadUserName: no current user")
                    return@launch
                }
                // Try name from auth user first
                if (!user.fullName.isNullOrBlank()) {
                    _uiState.value = _uiState.value.copy(userName = user.fullName)
                    return@launch
                }
                // Fallback to profile repository
                val result = profileRepository.getUserProfile(user.id)
                Log.d("AIViewModel", "loadUserName: profile result = $result")
                if (result is com.swastricare.health.core.result.ResultWrapper.Success) {
                    val name = result.data?.fullName
                    if (!name.isNullOrBlank()) {
                        _uiState.value = _uiState.value.copy(userName = name)
                    }
                }
            } catch (e: Exception) {
                Log.e("AIViewModel", "loadUserName failed", e)
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        speechService.cleanup()
    }

    // MARK: - Persistence

    private fun loadLastConversation() {
        viewModelScope.launch {
            try {
                val conversations = conversationRepo.getConversations()
                    .filter { !it.is_archived }
                val latest = conversations.firstOrNull() ?: return@launch

                val records = conversationRepo.getMessages(latest.id)
                if (records.isEmpty()) return@launch

                currentConversationId = latest.id
                val messages = records.map { record ->
                    ChatMessage(
                        id = record.id,
                        content = record.content,
                        isUser = record.role == "user",
                        shouldAnimate = false
                    )
                }
                _uiState.value = _uiState.value.copy(
                    messages = messages,
                    showEmptyState = false
                )
            } catch (e: Exception) {
                Log.w("AIViewModel", "Failed to load conversation history: ${e.message}")
            }
        }
    }

    private suspend fun ensureConversation(): String {
        currentConversationId?.let { return it }
        val conversation = conversationRepo.createConversation("Chat")
        currentConversationId = conversation.id
        return conversation.id
    }

    private fun persistMessage(role: String, content: String) {
        viewModelScope.launch {
            try {
                val convId = ensureConversation()
                conversationRepo.addMessage(
                    AIMessageRecord(
                        conversation_id = convId,
                        role = role,
                        content = content
                    )
                )
            } catch (e: Exception) {
                Log.w("AIViewModel", "Failed to persist message: ${e.message}")
            }
        }
    }

    fun markMessageAnimated(messageId: String) {
        val updated = _uiState.value.messages.map { msg ->
            if (msg.id == messageId) msg.copy(shouldAnimate = false) else msg
        }
        _uiState.value = _uiState.value.copy(messages = updated)
    }

    fun onInputTextChanged(text: String) {
        _uiState.value = _uiState.value.copy(inputText = text)
    }

    fun sendMessage() {
        val text = _uiState.value.inputText.trim()
        if (text.isEmpty()) return

        val userMessage = ChatMessage.userMessage(text)
        // Capture prior messages for context BEFORE adding the new user message
        val priorMessages = _uiState.value.messages.filter { !it.isLoading }
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

        // Persist user message
        persistMessage("user", text)

        // Log AI message sent to analytics
        val mode = _uiState.value.currentMode.label
        analyticsService.logAIMessageSent(mode)
        appAnalyticsService.trackAIMessageSent(mode)

        viewModelScope.launch {
            try {
                val responseText = aiService.sendChatMessage(text, priorMessages)

                val newMessages = _uiState.value.messages.filter { !it.isLoading }.toMutableList()
                newMessages.add(ChatMessage.assistantMessage(responseText))

                val suggestions = generateFollowUpSuggestions(text, responseText)

                _uiState.value = _uiState.value.copy(
                    messages = newMessages,
                    isLoading = false,
                    followUpSuggestions = suggestions
                )

                // Persist assistant response
                persistMessage("assistant", responseText)
            } catch (e: Exception) {
                Log.w("AIViewModel", "sendMessage failed", e)
                val newMessages = _uiState.value.messages.filter { !it.isLoading }.toMutableList()
                newMessages.add(ChatMessage.assistantMessage("I'm having trouble connecting right now. Please try again in a moment."))
                _uiState.value = _uiState.value.copy(
                    messages = newMessages,
                    isLoading = false
                )
            }
        }
    }

    fun sendFollowUp(suggestion: String) {
        _uiState.value = _uiState.value.copy(inputText = suggestion)
        sendMessage()
    }

    fun clearChat() {
        // Archive the current conversation so it doesn't reload next time
        currentConversationId?.let { id ->
            viewModelScope.launch {
                try { conversationRepo.archiveConversation(id) } catch (_: Exception) {}
            }
        }
        currentConversationId = null
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
        val userText = "[Image: ${imageType.label}] Please analyze this ${imageType.label.lowercase()} image."
        val userMessage = ChatMessage.userMessage(userText, _uiState.value.pendingImageUri)
        // Capture prior messages for context BEFORE adding the new user message
        val priorMessages = _uiState.value.messages.filter { !it.isLoading }
        val currentMessages = _uiState.value.messages.toMutableList()
        currentMessages.add(userMessage)
        currentMessages.add(ChatMessage.loadingMessage())

        _uiState.value = _uiState.value.copy(
            messages = currentMessages,
            isLoading = true,
            showEmptyState = false,
            followUpSuggestions = emptyList()
        )

        persistMessage("user", userText)

        viewModelScope.launch {
            try {
                val responseText = aiService.sendChatMessage(
                    "Analyze this ${imageType.label} image using MedGemma 4B model",
                    priorMessages
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

                persistMessage("assistant", responseText)
            } catch (e: Exception) {
                Log.w("AIViewModel", "sendImageForAnalysis failed", e)
                val newMessages = _uiState.value.messages.filter { !it.isLoading }.toMutableList()
                newMessages.add(ChatMessage.assistantMessage("I'm having trouble analyzing this image right now. Please try again in a moment."))
                _uiState.value = _uiState.value.copy(
                    messages = newMessages,
                    isLoading = false,
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

    // MARK: - Chat History

    fun openHistorySheet() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(showHistorySheet = true, isHistoryLoading = true)
            try {
                val conversations = conversationRepo.getConversations()
                _uiState.value = _uiState.value.copy(
                    historyConversations = conversations,
                    isHistoryLoading = false
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isHistoryLoading = false)
            }
        }
    }

    fun closeHistorySheet() {
        _uiState.value = _uiState.value.copy(showHistorySheet = false)
    }

    fun loadConversation(conversation: com.swastricare.health.data.repository.AIConversation) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(showHistorySheet = false, isLoading = true)
            try {
                val records = conversationRepo.getMessages(conversation.id)
                val messages = records.map { record ->
                    ChatMessage(
                        id = record.id,
                        content = record.content,
                        isUser = record.role == "user",
                        shouldAnimate = false
                    )
                }
                currentConversationId = conversation.id
                _uiState.value = _uiState.value.copy(
                    messages = messages,
                    showEmptyState = messages.isEmpty(),
                    isLoading = false
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Failed to load conversation"
                )
            }
        }
    }

    fun deleteConversationFromHistory(id: String) {
        viewModelScope.launch {
            try {
                conversationRepo.deleteConversation(id)
                val updated = _uiState.value.historyConversations.filter { it.id != id }
                _uiState.value = _uiState.value.copy(historyConversations = updated)
                if (currentConversationId == id) {
                    currentConversationId = null
                    _uiState.value = _uiState.value.copy(
                        messages = emptyList(),
                        showEmptyState = true
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(error = "Failed to delete conversation")
            }
        }
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
                // Check if Health Connect is available and has permissions
                if (!healthConnectService.isAvailable) {
                    _uiState.value = _uiState.value.copy(
                        analysisState = AnalysisState.Error("Health Connect is not available on this device. Please install Google Health Connect from the Play Store.")
                    )
                    return@launch
                }

                if (!healthConnectService.hasAllPermissions()) {
                    _uiState.value = _uiState.value.copy(
                        analysisState = AnalysisState.Error("Health Connect permissions are required. Please grant permissions in Settings > Health Connect.")
                    )
                    return@launch
                }

                // Fetch real health data from Health Connect
                val summary = healthConnectService.getTodaySummary()
                val metrics = HealthMetrics(
                    steps = summary.steps,
                    heartRate = summary.heartRate,
                    sleep = summary.sleepFormatted,
                    activeCalories = summary.activeCalories,
                    exerciseMinutes = summary.exerciseMinutes,
                    bloodPressure = summary.bloodPressureFormatted,
                    weight = if (summary.weightKg > 0) "%.1f".format(summary.weightKg) else "--"
                )

                // Warn if all metrics are empty (no data recorded today)
                if (metrics.isEmpty()) {
                    _uiState.value = _uiState.value.copy(
                        analysisState = AnalysisState.Error("No health data found for today. Start tracking your activity, and try again later.")
                    )
                    return@launch
                }

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
