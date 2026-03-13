package com.swastricare.health.presentation.feature.ai

import com.swastricare.health.domain.model.ai.Conversation
import com.swastricare.health.domain.repository.HealthAnalysisResult

/**
 * UI state for AI screen.
 * Represents the complete state of the AI chat interface.
 */
data class AIUiState(
    // ── Chat State ──
    val messages: List<ChatMessageUi> = emptyList(),
    val inputText: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
    val showEmptyState: Boolean = true,

    // ── Analysis State ──
    val analysisState: AnalysisState = AnalysisState.Idle,

    // ── Voice Input ──
    val isRecording: Boolean = false,

    // ── Mode & Image ──
    val currentMode: AIMode = AIMode.General,
    val selectedImageType: ImageType? = null,
    val showImageTypeSheet: Boolean = false,
    val pendingImageUri: String? = null,

    // ── Follow-up Suggestions ──
    val followUpSuggestions: List<String> = emptyList(),

    // ── Mode Switching ──
    val showModeSwitchDialog: Boolean = false,
    val pendingModeSwitch: AIMode? = null,

    // ── Snackbar ──
    val snackbarMessage: String? = null,

    // ── History ──
    val showHistorySheet: Boolean = false,
    val historyConversations: List<Conversation> = emptyList(),
    val isHistoryLoading: Boolean = false
)

/**
 * UI model for chat message (presentation layer).
 * Separated from domain Message to include UI-specific properties.
 */
data class ChatMessageUi(
    val id: String,
    val content: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
    val isLoading: Boolean = false,
    val shouldAnimate: Boolean = false,
    val imageUri: String? = null
) {
    companion object {
        fun userMessage(content: String, imageUri: String? = null) =
            ChatMessageUi(
                id = java.util.UUID.randomUUID().toString(),
                content = content,
                isUser = true,
                imageUri = imageUri
            )

        fun assistantMessage(content: String) =
            ChatMessageUi(
                id = java.util.UUID.randomUUID().toString(),
                content = content,
                isUser = false,
                shouldAnimate = true
            )

        fun loadingMessage() =
            ChatMessageUi(
                id = "loading",
                content = "",
                isUser = false,
                isLoading = true
            )
    }
}

/**
 * AI mode enum.
 */
enum class AIMode(val label: String) {
    General("General"),
    Medical("Medical"),
    ImageAnalysis("Image Analysis")
}

/**
 * Image type for analysis.
 */
enum class ImageType(val label: String, val icon: String) {
    XRay("X-Ray", "radiology"),
    MRI("MRI", "mri"),
    CTScan("CT Scan", "ct_scan"),
    SkinPhoto("Skin Photo", "skin"),
    LabReport("Lab Report", "lab"),
    Prescription("Prescription", "prescription"),
    Other("Other", "other")
}

/**
 * Analysis state for health analysis.
 */
sealed class AnalysisState {
    object Idle : AnalysisState()
    object Analyzing : AnalysisState()
    data class Completed(val result: HealthAnalysisResult) : AnalysisState()
    data class Error(val message: String) : AnalysisState()
}

/**
 * Quick action suggestion.
 */
data class QuickAction(
    val id: String = java.util.UUID.randomUUID().toString(),
    val title: String,
    val icon: String,
    val prompt: String
) {
    companion object {
        val suggestions = listOf(
            QuickAction(
                title = "Analyze My Health",
                icon = "waveform.path.ecg",
                prompt = "Analyze my current health metrics and give me insights"
            ),
            QuickAction(
                title = "Sleep Tips",
                icon = "moon.fill",
                prompt = "How can I improve my sleep quality?"
            ),
            QuickAction(
                title = "Exercise Ideas",
                icon = "figure.run",
                prompt = "What exercises are good for beginners?"
            ),
            QuickAction(
                title = "Nutrition",
                icon = "leaf.fill",
                prompt = "What should I eat for better heart health?"
            )
        )
    }
}
