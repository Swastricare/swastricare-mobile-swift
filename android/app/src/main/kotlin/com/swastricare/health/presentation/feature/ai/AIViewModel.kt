package com.swastricare.health.presentation.feature.ai

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.services.AnalyticsService
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.data.services.SpeechService
import com.swastricare.health.domain.model.ai.Message
import com.swastricare.health.domain.model.ai.MessageRole
import com.swastricare.health.domain.usecase.ai.AnalyzeHealthUseCase
import com.swastricare.health.domain.usecase.ai.DeleteConversationUseCase
import com.swastricare.health.domain.usecase.ai.GetConversationsUseCase
import com.swastricare.health.domain.usecase.ai.GetMessagesUseCase
import com.swastricare.health.domain.usecase.ai.ManageConversationUseCase
import com.swastricare.health.domain.usecase.ai.ManageMessageUseCase
import com.swastricare.health.domain.usecase.ai.SendMessageUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import javax.inject.Inject

/**
 * ViewModel for AI chat screen.
 * Uses Clean Architecture with domain use cases and Hilt DI.
 */
@HiltViewModel
class AIViewModel @Inject constructor(
    application: Application,
    private val sendMessageUseCase: SendMessageUseCase,
    private val getConversationsUseCase: GetConversationsUseCase,
    private val getMessagesUseCase: GetMessagesUseCase,
    private val deleteConversationUseCase: DeleteConversationUseCase,
    private val manageConversationUseCase: ManageConversationUseCase,
    private val manageMessageUseCase: ManageMessageUseCase,
    private val analyzeHealthUseCase: AnalyzeHealthUseCase,
    private val analyticsService: AnalyticsService,
    private val appAnalyticsService: AppAnalyticsService
) : AndroidViewModel(application) {

    private val speechService = SpeechService(application.applicationContext)

    private val _uiState = MutableStateFlow(AIUiState())
    val uiState: StateFlow<AIUiState> = _uiState.asStateFlow()

    private var currentConversationId: String? = null

    init {
        loadLastConversation()
    }

    override fun onCleared() {
        super.onCleared()
        speechService.cleanup()
    }

    // ── Persistence ──

    private fun loadLastConversation() {
        viewModelScope.launch {
            try {
                val conversations = getConversationsUseCase()
                val latest = conversations.firstOrNull() ?: return@launch

                val messages = getMessagesUseCase(latest.id)
                if (messages.isEmpty()) return@launch

                currentConversationId = latest.id
                val uiMessages = messages.map { it.toUi(shouldAnimate = false) }
                _uiState.value = _uiState.value.copy(
                    messages = uiMessages,
                    showEmptyState = false
                )
            } catch (e: Exception) {
                // Ignore - just show empty state
            }
        }
    }

    private suspend fun ensureConversation(): String {
        currentConversationId?.let { return it }
        val conversation = manageConversationUseCase.create("Chat")
        currentConversationId = conversation.id
        return conversation.id
    }

    private fun persistMessage(role: MessageRole, content: String) {
        viewModelScope.launch {
            try {
                val convId = ensureConversation()
                val message = Message(
                    id = java.util.UUID.randomUUID().toString(),
                    conversationId = convId,
                    role = role,
                    content = content,
                    createdAt = LocalDateTime.now()
                )
                manageMessageUseCase.add(message)
            } catch (e: Exception) {
                // Ignore persistence errors
            }
        }
    }

    // ── Input & Messages ──

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

        val userMessage = ChatMessageUi.userMessage(text)
        val priorMessages = _uiState.value.messages.filter { !it.isLoading }
        val currentMessages = _uiState.value.messages.toMutableList()
        currentMessages.add(userMessage)
        currentMessages.add(ChatMessageUi.loadingMessage())

        _uiState.value = _uiState.value.copy(
            messages = currentMessages,
            inputText = "",
            isLoading = true,
            showEmptyState = false,
            followUpSuggestions = emptyList()
        )

        // Persist user message
        persistMessage(MessageRole.USER, text)

        // Log analytics
        val mode = _uiState.value.currentMode.label
        analyticsService.logAIMessageSent(mode)
        appAnalyticsService.trackAIMessageSent(mode)

        viewModelScope.launch {
            try {
                // Convert UI messages to domain messages for context
                val domainMessages = priorMessages.map { it.toDomain() }
                val responseText = sendMessageUseCase(text, domainMessages)

                val newMessages = _uiState.value.messages.filter { !it.isLoading }.toMutableList()
                newMessages.add(ChatMessageUi.assistantMessage(responseText))

                val suggestions = generateFollowUpSuggestions(text, responseText)

                _uiState.value = _uiState.value.copy(
                    messages = newMessages,
                    isLoading = false,
                    followUpSuggestions = suggestions
                )

                // Persist assistant response
                persistMessage(MessageRole.ASSISTANT, responseText)
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
        // Archive the current conversation
        currentConversationId?.let { id ->
            viewModelScope.launch {
                try {
                    manageConversationUseCase.archive(id)
                } catch (e: Exception) {
                    // Ignore
                }
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

    // ── Mode Switching ──

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

    // ── Image Analysis ──

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
        val userMessage = ChatMessageUi.userMessage(userText, _uiState.value.pendingImageUri)
        val priorMessages = _uiState.value.messages.filter { !it.isLoading }
        val currentMessages = _uiState.value.messages.toMutableList()
        currentMessages.add(userMessage)
        currentMessages.add(ChatMessageUi.loadingMessage())

        _uiState.value = _uiState.value.copy(
            messages = currentMessages,
            isLoading = true,
            showEmptyState = false,
            followUpSuggestions = emptyList()
        )

        persistMessage(MessageRole.USER, userText)

        viewModelScope.launch {
            try {
                // TODO: Implement image analysis with actual image data
                // For now, send text-only message
                val domainMessages = priorMessages.map { it.toDomain() }
                val responseText = sendMessageUseCase(
                    "Analyze this ${imageType.label} image using MedGemma 4B model",
                    domainMessages
                )

                val newMessages = _uiState.value.messages.filter { !it.isLoading }.toMutableList()
                newMessages.add(ChatMessageUi.assistantMessage(responseText))

                val suggestions = generateFollowUpSuggestions(imageType.label, responseText)

                _uiState.value = _uiState.value.copy(
                    messages = newMessages,
                    isLoading = false,
                    pendingImageUri = null,
                    followUpSuggestions = suggestions
                )

                persistMessage(MessageRole.ASSISTANT, responseText)
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

    // ── Snackbar ──

    fun showSnackbar(message: String) {
        _uiState.value = _uiState.value.copy(snackbarMessage = message)
    }

    fun clearSnackbar() {
        _uiState.value = _uiState.value.copy(snackbarMessage = null)
    }

    // ── Chat History ──

    fun openHistorySheet() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(showHistorySheet = true, isHistoryLoading = true)
            try {
                val conversations = getConversationsUseCase()
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

    fun loadConversation(conversation: com.swastricare.health.domain.model.ai.Conversation) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(showHistorySheet = false, isLoading = true)
            try {
                val messages = getMessagesUseCase(conversation.id)
                val uiMessages = messages.map { it.toUi(shouldAnimate = false) }
                currentConversationId = conversation.id
                _uiState.value = _uiState.value.copy(
                    messages = uiMessages,
                    showEmptyState = uiMessages.isEmpty(),
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
                deleteConversationUseCase(id)
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

    // ── Follow-Up Suggestions ──

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

    // ── Health Analysis ──

    private fun analyzeCurrentHealth() {
        _uiState.value = _uiState.value.copy(analysisState = AnalysisState.Analyzing)

        viewModelScope.launch {
            try {
                val result = analyzeHealthUseCase()
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

    // ── Helper Extensions ──

    private fun Message.toUi(shouldAnimate: Boolean = false): ChatMessageUi {
        return ChatMessageUi(
            id = id,
            content = content,
            isUser = isUserMessage(),
            timestamp = createdAt.atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli(),
            shouldAnimate = shouldAnimate
        )
    }

    private fun ChatMessageUi.toDomain(): Message {
        return Message(
            id = id,
            conversationId = currentConversationId ?: "",
            role = if (isUser) MessageRole.USER else MessageRole.ASSISTANT,
            content = content,
            createdAt = LocalDateTime.ofInstant(
                java.time.Instant.ofEpochMilli(timestamp),
                java.time.ZoneId.systemDefault()
            )
        )
    }
}
