package com.swasthicare.mobile.data.models

import kotlinx.serialization.Serializable
import java.util.UUID
import java.util.Date

// MARK: - Chat Message Model

data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val content: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
    val isLoading: Boolean = false
) {
    companion object {
        fun userMessage(content: String) = ChatMessage(content = content, isUser = true)
        fun assistantMessage(content: String) = ChatMessage(content = content, isUser = false)
        fun loadingMessage() = ChatMessage(content = "", isUser = false, isLoading = true)
    }
}

// MARK: - AI Feature Type

enum class AIFeature(val title: String, val icon: String, val description: String) {
    Chat("Chat", "bubble_left_and_bubble_right_fill", "Ask health questions"),
    Analysis("Analysis", "waveform_path_ecg", "Analyze your vitals");
}

// MARK: - Health Analysis Request

@Serializable
data class HealthAnalysisRequest(
    val steps: Int,
    val heartRate: Int,
    val sleepHours: Double,
    val activeCalories: Int,
    val exerciseMinutes: Int,
    val weight: Double?,
    val bloodPressure: String?
)

// MARK: - Health Analysis Response

@Serializable
data class HealthAnalysisResponse(
    val assessment: String,
    val insights: String,
    val recommendations: List<String>
) {
    companion object {
        val empty = HealthAnalysisResponse(
            assessment = "",
            insights = "",
            recommendations = emptyList()
        )
    }
}

// MARK: - Health Analysis Result

data class HealthAnalysisResult(
    val id: String = UUID.randomUUID().toString(),
    val metrics: HealthMetrics, // Need to define HealthMetrics or import it
    val analysis: HealthAnalysisResponse,
    val timestamp: Long = System.currentTimeMillis()
)

// MARK: - Quick Action

data class QuickAction(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val icon: String, // System icon name or resource
    val prompt: String
) {
    companion object {
        val suggestions = listOf(
            QuickAction(title = "Analyze My Health", icon = "waveform.path.ecg", prompt = "Analyze my current health metrics and give me insights"),
            QuickAction(title = "Sleep Tips", icon = "moon.fill", prompt = "How can I improve my sleep quality?"),
            QuickAction(title = "Exercise Ideas", icon = "figure.run", prompt = "What exercises are good for beginners?"),
            QuickAction(title = "Nutrition", icon = "leaf.fill", prompt = "What should I eat for better heart health?")
        )
    }
}

// Placeholder for HealthMetrics if not exists in Android yet
@Serializable
data class HealthMetrics(
    val steps: Int = 0,
    val heartRate: Int = 0,
    val sleep: String = "0h 0m",
    val activeCalories: Int = 0,
    val exerciseMinutes: Int = 0,
    val standHours: Int = 0,
    val distance: Double = 0.0,
    val bloodPressure: String = "--/--",
    val weight: String = "--",
    val timestamp: Long = System.currentTimeMillis()
) {
    fun isEmpty(): Boolean = steps == 0 && heartRate == 0 && sleep == "0h 0m"
}

@Serializable
data class ChatRequest(
    val message: String,
    val context: List<ContextMessage>
)

@Serializable
data class ContextMessage(
    val role: String,
    val content: String
)

@Serializable
data class ChatResponse(
    val response: String
)
