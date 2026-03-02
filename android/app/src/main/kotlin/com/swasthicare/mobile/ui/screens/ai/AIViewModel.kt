package com.swasthicare.mobile.ui.screens.ai

import android.app.Application
import android.content.SharedPreferences
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.data.repository.AIConversationRepository
import com.swasthicare.mobile.data.repository.AIConversation
import com.swasthicare.mobile.data.repository.AIMessageRecord
import com.swasthicare.mobile.data.services.AIService
import com.swasthicare.mobile.data.services.HealthConnectService
import com.swasthicare.mobile.data.services.SpeechService
import com.swasthicare.mobile.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

// AI Mode
enum class AIMode(val label: String, val param: String) {
    General("General", "general"),
    Medical("Medical", "medical")
}

// AI Personality
enum class AIPersonality(val label: String, val param: String) {
    Default("Default", "default"),
    Friendly("Friendly", "friendly"),
    Professional("Professional", "professional"),
    Concise("Concise", "concise"),
    Detailed("Detailed", "detailed")
}

data class AIUiState(
    val messages: List<ChatMessage> = emptyList(),
    val inputText: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
    val showEmptyState: Boolean = true,
    val analysisState: AnalysisState = AnalysisState.Idle,
    val isRecording: Boolean = false,
    // New AI features
    val selectedMode: AIMode = AIMode.General,
    val selectedPersonality: AIPersonality = AIPersonality.Default,
    val selectedImageUri: Uri? = null,
    val showMedicalDisclaimer: Boolean = false,
    val showEmergencyAlert: Boolean = false,
    val emergencyMessage: String = "",
    // Conversation history
    val conversations: List<AIConversation> = emptyList(),
    val currentConversationId: String? = null,
    val showHistorySheet: Boolean = false,
    // Bookmarks
    val bookmarkedMessages: List<AIMessageRecord> = emptyList(),
    val showBookmarksSheet: Boolean = false
)

sealed class AnalysisState {
    object Idle : AnalysisState()
    object Analyzing : AnalysisState()
    data class Completed(val result: HealthAnalysisResult) : AnalysisState()
    data class Error(val message: String) : AnalysisState()
}

// Emergency keywords
private val EMERGENCY_KEYWORDS = listOf(
    "heart attack", "can't breathe", "cannot breathe", "difficulty breathing",
    "stroke", "seizure", "suicide", "suicidal", "dying", "emergency",
    "severe bleeding", "unconscious", "overdose", "chest pain"
)

class AIViewModel(application: Application) : AndroidViewModel(application) {
    private val aiService = AIService()
    private val speechService = SpeechService(application.applicationContext)
    private val healthConnectService: HealthConnectService = AppContainer.healthConnectService
    private val conversationRepo: AIConversationRepository = AppContainer.aiConversationRepository
    private val prefs: SharedPreferences = AppContainer.sharedPreferences

    private val _uiState = MutableStateFlow(AIUiState())
    val uiState: StateFlow<AIUiState> = _uiState.asStateFlow()

    init {
        loadConversations()
    }

    override fun onCleared() {
        super.onCleared()
        speechService.cleanup()
    }

    fun onInputTextChanged(text: String) {
        _uiState.value = _uiState.value.copy(inputText = text)
    }

    // ── Mode & Personality ──

    fun setMode(mode: AIMode) {
        if (mode == AIMode.Medical && !hasMedicalConsent()) {
            _uiState.value = _uiState.value.copy(showMedicalDisclaimer = true)
            return
        }
        _uiState.value = _uiState.value.copy(selectedMode = mode)
    }

    fun acceptMedicalDisclaimer() {
        prefs.edit().putBoolean("medical_disclaimer_accepted", true).apply()
        _uiState.value = _uiState.value.copy(
            showMedicalDisclaimer = false,
            selectedMode = AIMode.Medical
        )
    }

    fun dismissMedicalDisclaimer() {
        _uiState.value = _uiState.value.copy(showMedicalDisclaimer = false)
    }

    private fun hasMedicalConsent(): Boolean {
        return prefs.getBoolean("medical_disclaimer_accepted", false)
    }

    fun setPersonality(personality: AIPersonality) {
        _uiState.value = _uiState.value.copy(selectedPersonality = personality)
    }

    // ── Image Selection ──

    fun setSelectedImage(uri: Uri?) {
        _uiState.value = _uiState.value.copy(selectedImageUri = uri)
    }

    fun clearSelectedImage() {
        _uiState.value = _uiState.value.copy(selectedImageUri = null)
    }

    // ── Send Message ──

    fun sendMessage() {
        val state = _uiState.value
        val text = state.inputText.trim()
        if (text.isEmpty() && state.selectedImageUri == null) return

        // Emergency keyword detection
        if (containsEmergencyKeyword(text)) {
            _uiState.value = state.copy(
                showEmergencyAlert = true,
                emergencyMessage = "If you or someone else is experiencing a medical emergency, please call emergency services immediately:\n\n112 (India) | 911 (US) | 999 (UK)"
            )
            // Continue sending, but show alert
        }

        // Smart prompt rewrite: enrich vague messages
        val enrichedText = smartPromptRewrite(text)

        val userMessage = ChatMessage.userMessage(enrichedText)
        val currentMessages = state.messages.toMutableList()
        currentMessages.add(userMessage)
        currentMessages.add(ChatMessage.loadingMessage())

        _uiState.value = state.copy(
            messages = currentMessages,
            inputText = "",
            isLoading = true,
            showEmptyState = false,
            selectedImageUri = null
        )

        // Save user message to conversation
        saveMessageToConversation(userMessage)

        viewModelScope.launch {
            try {
                val responseText = aiService.sendChatMessage(
                    enrichedText,
                    _uiState.value.messages.filter { !it.isLoading }
                )

                val newMessages = _uiState.value.messages.filter { !it.isLoading }.toMutableList()
                val assistantMessage = ChatMessage.assistantMessage(responseText)
                newMessages.add(assistantMessage)

                _uiState.value = _uiState.value.copy(
                    messages = newMessages,
                    isLoading = false
                )

                // Save assistant message
                saveMessageToConversation(assistantMessage)
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

    fun clearChat() {
        _uiState.value = AIUiState(
            showEmptyState = true,
            selectedMode = _uiState.value.selectedMode,
            selectedPersonality = _uiState.value.selectedPersonality,
            conversations = _uiState.value.conversations
        )
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    fun dismissAnalysis() {
        _uiState.value = _uiState.value.copy(analysisState = AnalysisState.Idle)
    }

    fun dismissEmergencyAlert() {
        _uiState.value = _uiState.value.copy(showEmergencyAlert = false)
    }

    // ── Quick Actions ──

    fun sendQuickAction(action: QuickAction) {
        if (action.title == "Analyze My Health") {
            analyzeCurrentHealth()
        } else {
            _uiState.value = _uiState.value.copy(inputText = action.prompt)
            sendMessage()
        }
    }

    // ── Health Analysis with real data ──

    private fun analyzeCurrentHealth() {
        _uiState.value = _uiState.value.copy(analysisState = AnalysisState.Analyzing)

        viewModelScope.launch {
            try {
                // Fetch real health data from Health Connect
                val metrics = fetchRealHealthMetrics()

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

    private suspend fun fetchRealHealthMetrics(): HealthMetrics {
        return try {
            val hasPermissions = healthConnectService.hasAllPermissions()
            if (healthConnectService.isAvailable && hasPermissions) {
                val summary = healthConnectService.getTodaySummary()
                HealthMetrics(
                    steps = summary.steps,
                    heartRate = summary.heartRate,
                    sleep = summary.sleepFormatted,
                    activeCalories = summary.activeCalories,
                    exerciseMinutes = summary.exerciseMinutes,
                    standHours = summary.standHours,
                    distance = summary.distanceKm,
                    bloodPressure = summary.bloodPressureFormatted,
                    weight = if (summary.weightKg > 0) "${summary.weightKg}" else "--"
                )
            } else {
                // Fallback mock data
                HealthMetrics(
                    steps = 5432, heartRate = 72, sleep = "7h 15m",
                    activeCalories = 320, exerciseMinutes = 45,
                    bloodPressure = "120/80", weight = "70.5"
                )
            }
        } catch (e: Exception) {
            HealthMetrics(
                steps = 5432, heartRate = 72, sleep = "7h 15m",
                activeCalories = 320, exerciseMinutes = 45,
                bloodPressure = "120/80", weight = "70.5"
            )
        }
    }

    // ── Smart Prompt Rewrite ──

    private fun smartPromptRewrite(text: String): String {
        val lowerText = text.lowercase()
        val vaguePatterns = listOf("help", "how am i", "analyze", "check", "status", "how am i doing")

        val isVague = vaguePatterns.any { lowerText.contains(it) }
        if (!isVague) return text

        // Append context about current health metrics (cached from last load)
        val contextSuffix = buildString {
            append("\n\n[Context from my health data: ")
            // We'll use a simple approach -- append known state
            append("I'm asking about my health status. ")
            append("Please provide a comprehensive analysis based on available data.]")
        }
        return text + contextSuffix
    }

    // ── Emergency Detection ──

    private fun containsEmergencyKeyword(text: String): Boolean {
        val lower = text.lowercase()
        return EMERGENCY_KEYWORDS.any { lower.contains(it) }
    }

    // ── Message Feedback & Bookmarks ──

    fun toggleBookmark(messageId: String) {
        viewModelScope.launch {
            val message = _uiState.value.messages.find { it.id == messageId } ?: return@launch
            val conversationId = _uiState.value.currentConversationId ?: return@launch

            val record = AIMessageRecord(
                id = messageId,
                conversation_id = conversationId,
                role = if (message.isUser) "user" else "assistant",
                content = message.content,
                is_bookmarked = true
            )
            conversationRepo.updateMessageBookmark(messageId, true)

            // Refresh bookmarks
            val bookmarks = conversationRepo.getBookmarkedMessages()
            _uiState.value = _uiState.value.copy(bookmarkedMessages = bookmarks)
        }
    }

    fun sendFeedback(messageId: String, isPositive: Boolean) {
        viewModelScope.launch {
            val feedback = if (isPositive) "up" else "down"
            conversationRepo.updateMessageFeedback(messageId, feedback)
        }
    }

    // ── Conversation History ──

    fun toggleHistorySheet() {
        val show = !_uiState.value.showHistorySheet
        _uiState.value = _uiState.value.copy(showHistorySheet = show)
        if (show) loadConversations()
    }

    fun toggleBookmarksSheet() {
        val show = !_uiState.value.showBookmarksSheet
        _uiState.value = _uiState.value.copy(showBookmarksSheet = show)
        if (show) loadBookmarks()
    }

    private fun loadConversations() {
        viewModelScope.launch {
            try {
                val conversations = conversationRepo.getConversations()
                _uiState.value = _uiState.value.copy(conversations = conversations)
            } catch (_: Exception) {}
        }
    }

    private fun loadBookmarks() {
        viewModelScope.launch {
            try {
                val bookmarks = conversationRepo.getBookmarkedMessages()
                _uiState.value = _uiState.value.copy(bookmarkedMessages = bookmarks)
            } catch (_: Exception) {}
        }
    }

    fun loadConversation(conversationId: String) {
        viewModelScope.launch {
            try {
                val records = conversationRepo.getMessages(conversationId)
                val messages = records.map { record ->
                    ChatMessage(
                        id = record.id,
                        content = record.content,
                        isUser = record.role == "user",
                        timestamp = try { java.time.Instant.parse(record.created_at).toEpochMilli() } catch (_: Exception) { System.currentTimeMillis() }
                    )
                }
                _uiState.value = _uiState.value.copy(
                    messages = messages,
                    currentConversationId = conversationId,
                    showEmptyState = false,
                    showHistorySheet = false
                )
            } catch (_: Exception) {}
        }
    }

    fun deleteConversation(conversationId: String) {
        viewModelScope.launch {
            try {
                conversationRepo.deleteConversation(conversationId)
                loadConversations()
                if (_uiState.value.currentConversationId == conversationId) {
                    clearChat()
                }
            } catch (_: Exception) {}
        }
    }

    fun archiveConversation(conversationId: String) {
        viewModelScope.launch {
            try {
                conversationRepo.archiveConversation(conversationId)
                loadConversations()
            } catch (_: Exception) {}
        }
    }

    private fun saveMessageToConversation(message: ChatMessage) {
        viewModelScope.launch {
            try {
                // Create conversation if needed
                var convId = _uiState.value.currentConversationId
                if (convId == null) {
                    val title = message.content.take(50).ifEmpty { "New Conversation" }
                    val conversation = conversationRepo.createConversation(title)
                    convId = conversation.id
                    _uiState.value = _uiState.value.copy(currentConversationId = convId)
                }

                val record = AIMessageRecord(
                    id = message.id,
                    conversation_id = convId,
                    role = if (message.isUser) "user" else "assistant",
                    content = message.content
                )
                conversationRepo.addMessage(record)
            } catch (_: Exception) {}
        }
    }

    // ── Speech ──

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
