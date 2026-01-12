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

data class AIUiState(
    val messages: List<ChatMessage> = emptyList(),
    val inputText: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
    val showEmptyState: Boolean = true,
    val analysisState: AnalysisState = AnalysisState.Idle,
    val isRecording: Boolean = false
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
            showEmptyState = false
        )

        viewModelScope.launch {
            try {
                // Remove loading message logic handled by updating list
                val responseText = aiService.sendChatMessage(text, _uiState.value.messages.filter { !it.isLoading })
                
                val newMessages = _uiState.value.messages.filter { !it.isLoading }.toMutableList()
                newMessages.add(ChatMessage.assistantMessage(responseText))
                
                _uiState.value = _uiState.value.copy(
                    messages = newMessages,
                    isLoading = false
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

    fun clearChat() {
        _uiState.value = AIUiState(showEmptyState = true)
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

    private fun analyzeCurrentHealth() {
        _uiState.value = _uiState.value.copy(analysisState = AnalysisState.Analyzing)
        
        viewModelScope.launch {
            try {
                // Mock fetching health metrics since we don't have HealthManager yet
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
