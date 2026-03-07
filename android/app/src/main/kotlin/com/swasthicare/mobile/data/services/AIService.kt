package com.swasthicare.mobile.data.services

import com.swasthicare.mobile.data.models.ChatMessage
import com.swasthicare.mobile.data.models.ChatRequest
import com.swasthicare.mobile.data.models.ChatResponse
import com.swasthicare.mobile.data.models.ContextMessage
import com.swasthicare.mobile.data.models.HealthAnalysisResponse
import com.swasthicare.mobile.data.models.HealthMetrics
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.call.body
import kotlinx.serialization.json.Json

class AIService(private val client: SupabaseClient) {

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun sendChatMessage(message: String, context: List<ChatMessage>): String {
        val contextMessages = context.takeLast(10).map { msg ->
            ContextMessage(
                role = if (msg.isUser) "user" else "assistant",
                content = msg.content
            )
        }
        val request = ChatRequest(message = message, conversationHistory = contextMessages)

        val response = client.functions.invoke(
            function = "ai-router",
            body = request
        )
        val body = response.body<String>()
        return json.decodeFromString<ChatResponse>(body).response
    }

    suspend fun analyzeHealth(metrics: HealthMetrics): HealthAnalysisResponse {
        // Build a structured prompt with health metrics for the ai-router
        val prompt = buildString {
            appendLine("Analyze my current health metrics and provide a detailed health assessment.")
            appendLine()
            appendLine("Here are my health metrics for today:")
            appendLine("- Steps: ${metrics.steps}")
            appendLine("- Heart Rate: ${metrics.heartRate} bpm")
            appendLine("- Sleep: ${metrics.sleep}")
            appendLine("- Active Calories: ${metrics.activeCalories} kcal")
            appendLine("- Exercise Minutes: ${metrics.exerciseMinutes}")
            appendLine("- Blood Pressure: ${metrics.bloodPressure}")
            appendLine("- Weight: ${metrics.weight} kg")
            appendLine()
            appendLine("Please respond in exactly this format:")
            appendLine("ASSESSMENT: <overall health assessment in 2-3 sentences>")
            appendLine("INSIGHTS: <key observations about the metrics in 2-3 sentences>")
            appendLine("RECOMMENDATIONS:")
            appendLine("- <recommendation 1>")
            appendLine("- <recommendation 2>")
            appendLine("- <recommendation 3>")
        }

        return try {
            val responseText = sendChatMessage(prompt, emptyList())
            parseHealthAnalysisResponse(responseText)
        } catch (e: Exception) {
            HealthAnalysisResponse(
                assessment = "Unable to analyze at this time.",
                insights = "Could not connect to the health analysis service.",
                recommendations = listOf("Please check your connection and try again.")
            )
        }
    }

    private fun parseHealthAnalysisResponse(text: String): HealthAnalysisResponse {
        var assessment = ""
        var insights = ""
        val recommendations = mutableListOf<String>()

        // Try to parse structured response
        val assessmentMatch = Regex("ASSESSMENT:\\s*(.+?)(?=INSIGHTS:|RECOMMENDATIONS:|$)", RegexOption.DOT_MATCHES_ALL).find(text)
        val insightsMatch = Regex("INSIGHTS:\\s*(.+?)(?=RECOMMENDATIONS:|$)", RegexOption.DOT_MATCHES_ALL).find(text)
        val recsMatch = Regex("RECOMMENDATIONS:\\s*(.+?)$", RegexOption.DOT_MATCHES_ALL).find(text)

        if (assessmentMatch != null) {
            assessment = assessmentMatch.groupValues[1].trim()
            insights = insightsMatch?.groupValues?.get(1)?.trim() ?: ""
            val recsText = recsMatch?.groupValues?.get(1)?.trim() ?: ""
            recommendations.addAll(
                recsText.lines()
                    .map { it.trim().removePrefix("-").removePrefix("•").removePrefix("*").trim() }
                    .filter { it.isNotBlank() }
            )
        } else {
            // If AI didn't follow the format, use the full response as assessment
            // and try to split into paragraphs
            val paragraphs = text.split("\n\n").filter { it.isNotBlank() }
            assessment = paragraphs.firstOrNull()?.trim() ?: text.trim()
            insights = paragraphs.getOrNull(1)?.trim() ?: ""
            if (paragraphs.size > 2) {
                paragraphs.drop(2).forEach { para ->
                    para.lines()
                        .map { it.trim().removePrefix("-").removePrefix("•").removePrefix("*").trim() }
                        .filter { it.isNotBlank() }
                        .let { recommendations.addAll(it) }
                }
            }
            if (recommendations.isEmpty()) {
                recommendations.add("Continue monitoring your health metrics daily.")
            }
        }

        return HealthAnalysisResponse(
            assessment = assessment,
            insights = insights,
            recommendations = recommendations
        )
    }
}
