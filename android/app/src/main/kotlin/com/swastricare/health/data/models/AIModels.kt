package com.swastricare.health.data.models

import kotlinx.serialization.Serializable
import java.util.UUID

// MARK: - Chat Message Model

data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val content: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
    val isLoading: Boolean = false,
    val shouldAnimate: Boolean = false,
    val imageUri: String? = null,
    val foodResult: SnapFoodResult? = null
) {
    companion object {
        fun userMessage(content: String) = ChatMessage(content = content, isUser = true)
        fun userMessage(content: String, imageUri: String?) = ChatMessage(content = content, isUser = true, imageUri = imageUri)
        fun assistantMessage(content: String) = ChatMessage(content = content, isUser = false, shouldAnimate = true)
        fun foodAnalysisMessage(content: String, foodResult: SnapFoodResult) = ChatMessage(content = content, isUser = false, shouldAnimate = true, foodResult = foodResult)
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
    val icon: String, // iOS SF Symbol name, resolved to Material icon at the UI layer
    val prompt: String
) {
    companion object {
        /** Time-of-day contextual suggestions, mirroring iOS `QuickAction.contextualSuggestions`. */
        val suggestions: List<QuickAction>
            get() {
                val hour = java.util.Calendar.getInstance()
                    .get(java.util.Calendar.HOUR_OF_DAY)
                return when (hour) {
                    in 5..11 -> listOf(
                        QuickAction(title = "Sleep Review", icon = "bed.double.fill", prompt = "How was my sleep last night? Any tips to improve it?"),
                        QuickAction(title = "Morning Routine", icon = "sunrise.fill", prompt = "Suggest a healthy morning routine based on my health profile"),
                        QuickAction(title = "Breakfast Ideas", icon = "cup.and.saucer.fill", prompt = "What should I eat for a healthy breakfast today?"),
                        QuickAction(title = "Exercise Ideas", icon = "figure.run", prompt = "Suggest a workout I can do this morning based on my fitness level")
                    )
                    in 12..16 -> listOf(
                        QuickAction(title = "Midday Check-in", icon = "heart.text.square.fill", prompt = "How am I doing today? Review my steps, hydration, and activity so far."),
                        QuickAction(title = "Exercise Ideas", icon = "figure.run", prompt = "Suggest a workout I can do this afternoon based on my fitness level"),
                        QuickAction(title = "Nutrition", icon = "leaf.fill", prompt = "What should I eat for a balanced lunch?"),
                        QuickAction(title = "Hydration", icon = "drop.fill", prompt = "Am I drinking enough water today?")
                    )
                    in 17..21 -> listOf(
                        QuickAction(title = "Day Summary", icon = "chart.bar.fill", prompt = "Summarize my health metrics for today. How did I do?"),
                        QuickAction(title = "Wind Down", icon = "moon.stars.fill", prompt = "Help me create a relaxing evening routine for better sleep"),
                        QuickAction(title = "Dinner Tips", icon = "fork.knife", prompt = "What should I eat for a light, healthy dinner?"),
                        QuickAction(title = "Stretch", icon = "figure.cooldown", prompt = "Suggest a short evening stretch routine")
                    )
                    else -> listOf(
                        QuickAction(title = "Sleep Help", icon = "moon.zzz.fill", prompt = "I can't sleep. What relaxation techniques can help me fall asleep?"),
                        QuickAction(title = "Stress Relief", icon = "sparkles", prompt = "Guide me through a quick breathing exercise to relax"),
                        QuickAction(title = "Tomorrow Plan", icon = "calendar", prompt = "Help me plan a healthy day for tomorrow based on my health data"),
                        QuickAction(title = "Nutrition", icon = "leaf.fill", prompt = "What should I eat for better overall health?")
                    )
                }
            }
    }
}

// MARK: - AI Personality Roster
// Mirrors iOS `AIPersonality` (Models/MedicalAIModels.swift). Kept here so both
// platforms present the same 5 personas on the intro screen.

enum class AIPersonality(
    val displayName: String,
    val fullTitle: String,
    val icon: String,     // SF-Symbol-ish token, resolved to Material icon at the UI layer
    val colorHex: Long,
    val tagline: String
) {
    Assistant(
        displayName = "Swastri",
        fullTitle = "Swastri Assistant",
        icon = "sparkles",
        colorHex = 0xFF2E3192,
        tagline = "Your all-round health companion"
    ),
    Coach(
        displayName = "Coach",
        fullTitle = "Fitness Coach",
        icon = "figure.run",
        colorHex = 0xFFEF4444,
        tagline = "Push harder, recover smarter"
    ),
    Nutritionist(
        displayName = "Nutri",
        fullTitle = "Nutritionist",
        icon = "leaf.fill",
        colorHex = 0xFF22C55E,
        tagline = "Eat well, feel great"
    ),
    Therapist(
        displayName = "Zen",
        fullTitle = "Wellness Therapist",
        icon = "brain.head.profile",
        colorHex = 0xFF8B5CF6,
        tagline = "Breathe, reflect, grow"
    ),
    Sleep(
        displayName = "Luna",
        fullTitle = "Sleep Specialist",
        icon = "moon.stars.fill",
        colorHex = 0xFF6366F1,
        tagline = "Better nights, brighter days"
    );
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
    val conversationHistory: List<ContextMessage>,
    val imageData: String? = null,
    val healthContext: String? = null,
    val systemContext: String? = null,
    val forceModel: String? = null
)

@Serializable
data class ContextMessage(
    val role: String,
    val content: String
)

@Serializable
data class ChatResponse(
    val response: String,
    val error: Boolean? = null
)
