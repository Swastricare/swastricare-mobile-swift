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

    suspend fun sendChatMessage(message: String, context: List<ChatMessage>): String {
        val contextMessages = context.takeLast(10).map { msg ->
            ContextMessage(
                role = if (msg.isUser) "user" else "assistant",
                content = msg.content
            )
        }
        val request = ChatRequest(message = message, context = contextMessages)

        val response = client.functions.invoke(
            function = "ai-router",
            body = request
        )
        val body = response.body<String>()
        return Json.decodeFromString<ChatResponse>(body).response
    }

    suspend fun analyzeHealth(metrics: HealthMetrics): HealthAnalysisResponse {
        return try {
            val response = client.functions.invoke(
                function = "ai-router",
                body = mapOf(
                    "type" to "health_analysis",
                    "metrics" to metrics
                )
            )
            val body = response.body<String>()
            Json.decodeFromString<HealthAnalysisResponse>(body)
        } catch (e: Exception) {
            HealthAnalysisResponse(
                assessment = "Unable to analyze at this time.",
                insights = "",
                recommendations = listOf("Please check your connection and try again.")
            )
        }
    }
}
