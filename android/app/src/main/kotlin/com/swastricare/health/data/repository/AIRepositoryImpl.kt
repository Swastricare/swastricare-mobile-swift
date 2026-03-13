package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.data.mapper.AIMapper
import com.swastricare.health.data.mapper.AIMapper.toDomain
import com.swastricare.health.data.mapper.AIMapper.toDto
import com.swastricare.health.data.remote.dto.ai.ChatRequestDto
import com.swastricare.health.data.remote.dto.ai.ChatResponseDto
import com.swastricare.health.data.remote.dto.ai.ContextMessageDto
import com.swastricare.health.data.remote.dto.ai.ConversationDto
import com.swastricare.health.data.remote.dto.ai.MessageDto
import com.swastricare.health.domain.model.ai.Conversation
import com.swastricare.health.domain.model.ai.HealthContext
import com.swastricare.health.domain.model.ai.Message
import com.swastricare.health.domain.model.ai.MessageFeedback
import com.swastricare.health.domain.repository.AIRepository
import com.swastricare.health.domain.repository.HealthAnalysisResult
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from
import io.ktor.client.call.body
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Implementation of AIRepository using Supabase.
 * Handles AI conversation persistence and AI service calls.
 */
@Singleton
class AIRepositoryImpl @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val prefs: SharedPreferences
) : AIRepository {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    // ── Conversations ──

    override suspend fun getConversations(): List<Conversation> = withContext(Dispatchers.IO) {
        try {
            supabaseClient.from("ai_conversations")
                .select {
                    filter { eq("is_archived", false) }
                }
                .decodeList<ConversationDto>()
                .map { it.toDomain() }
                .sortedByDescending { it.updatedAt }
        } catch (e: Exception) {
            // Fallback to local storage
            loadLocalConversations().filter { !it.isArchived }
        }
    }

    override suspend fun getArchivedConversations(): List<Conversation> = withContext(Dispatchers.IO) {
        try {
            supabaseClient.from("ai_conversations")
                .select {
                    filter { eq("is_archived", true) }
                }
                .decodeList<ConversationDto>()
                .map { it.toDomain() }
                .sortedByDescending { it.updatedAt }
        } catch (e: Exception) {
            // Fallback to local storage
            loadLocalConversations().filter { it.isArchived }
        }
    }

    override suspend fun createConversation(title: String): Conversation = withContext(Dispatchers.IO) {
        val dto = ConversationDto(title = title)
        try {
            supabaseClient.from("ai_conversations").insert(dto)
        } catch (e: Exception) {
            // Save locally
            val local = loadLocalConversations().toMutableList()
            local.add(dto.toDomain())
            saveLocalConversations(local)
        }
        dto.toDomain()
    }

    override suspend fun deleteConversation(id: String): Unit = withContext(Dispatchers.IO) {
        try {
            // Delete all messages first
            supabaseClient.from("ai_messages").delete {
                filter { eq("conversation_id", id) }
            }
            // Delete conversation
            supabaseClient.from("ai_conversations").delete {
                filter { eq("id", id) }
            }
        } catch (e: Exception) {
            // Delete from local storage
            val conversations = loadLocalConversations().filter { it.id != id }
            saveLocalConversations(conversations)
            val messages = loadLocalMessages().filter { it.conversationId != id }
            saveLocalMessages(messages)
        }
    }

    override suspend fun archiveConversation(id: String): Unit = withContext(Dispatchers.IO) {
        try {
            supabaseClient.from("ai_conversations").update(
                { set("is_archived", true) }
            ) {
                filter { eq("id", id) }
            }
        } catch (e: Exception) {
            // Update local storage
            val conversations = loadLocalConversations().map {
                if (it.id == id) it.copy(isArchived = true) else it
            }
            saveLocalConversations(conversations)
        }
    }

    override suspend fun unarchiveConversation(id: String): Unit = withContext(Dispatchers.IO) {
        try {
            supabaseClient.from("ai_conversations").update(
                { set("is_archived", false) }
            ) {
                filter { eq("id", id) }
            }
        } catch (e: Exception) {
            // Update local storage
            val conversations = loadLocalConversations().map {
                if (it.id == id) it.copy(isArchived = false) else it
            }
            saveLocalConversations(conversations)
        }
    }

    // ── Messages ──

    override suspend fun getMessages(conversationId: String): List<Message> = withContext(Dispatchers.IO) {
        try {
            supabaseClient.from("ai_messages")
                .select {
                    filter { eq("conversation_id", conversationId) }
                }
                .decodeList<MessageDto>()
                .map { it.toDomain() }
                .sortedBy { it.createdAt }
        } catch (e: Exception) {
            // Fallback to local storage
            loadLocalMessages().filter { it.conversationId == conversationId }
        }
    }

    override suspend fun addMessage(message: Message): Unit = withContext(Dispatchers.IO) {
        val dto = message.toDto()
        try {
            supabaseClient.from("ai_messages").insert(dto)
        } catch (e: Exception) {
            // Save locally
            val local = loadLocalMessages().toMutableList()
            local.add(message)
            saveLocalMessages(local)
        }
    }

    override suspend fun updateMessageBookmark(messageId: String, bookmarked: Boolean): Unit =
        withContext(Dispatchers.IO) {
            try {
                supabaseClient.from("ai_messages").update(
                    { set("is_bookmarked", bookmarked) }
                ) {
                    filter { eq("id", messageId) }
                }
            } catch (e: Exception) {
                // Update local storage
                val messages = loadLocalMessages().map {
                    if (it.id == messageId) it.copy(isBookmarked = bookmarked) else it
                }
                saveLocalMessages(messages)
            }
        }

    override suspend fun updateMessageFeedback(messageId: String, feedback: MessageFeedback?): Unit =
        withContext(Dispatchers.IO) {
            try {
                val feedbackValue = feedback?.let {
                    when (it) {
                        MessageFeedback.POSITIVE -> "up"
                        MessageFeedback.NEGATIVE -> "down"
                    }
                }
                supabaseClient.from("ai_messages").update(
                    { set("feedback", feedbackValue) }
                ) {
                    filter { eq("id", messageId) }
                }
            } catch (e: Exception) {
                // Update local storage
                val messages = loadLocalMessages().map {
                    if (it.id == messageId) it.copy(feedback = feedback) else it
                }
                saveLocalMessages(messages)
            }
        }

    override suspend fun getBookmarkedMessages(): List<Message> = withContext(Dispatchers.IO) {
        try {
            supabaseClient.from("ai_messages")
                .select {
                    filter { eq("is_bookmarked", true) }
                }
                .decodeList<MessageDto>()
                .map { it.toDomain() }
                .sortedByDescending { it.createdAt }
        } catch (e: Exception) {
            // Fallback to local storage
            loadLocalMessages().filter { it.isBookmarked }
        }
    }

    // ── AI Operations ──

    override suspend fun sendChatMessage(
        message: String,
        conversationHistory: List<Message>,
        healthContext: HealthContext?
    ): String = withContext(Dispatchers.IO) {
        val contextMessages = conversationHistory.takeLast(10).map { msg ->
            ContextMessageDto(
                role = if (msg.isUserMessage()) "user" else "assistant",
                content = msg.content
            )
        }

        val request = ChatRequestDto(
            message = message,
            conversationHistory = contextMessages,
            healthContext = healthContext?.toContextString()
        )

        val response = supabaseClient.functions.invoke(
            function = "ai-router",
            body = request
        )
        val body = response.body<String>()
        json.decodeFromString<ChatResponseDto>(body).response
    }

    override suspend fun analyzeHealth(healthContext: HealthContext): HealthAnalysisResult =
        withContext(Dispatchers.IO) {
            val prompt = buildString {
                appendLine("Analyze my current health metrics and provide a detailed health assessment.")
                appendLine()
                appendLine(healthContext.toContextString())
                appendLine()
                appendLine("Please respond in exactly this format:")
                appendLine("ASSESSMENT: <overall health assessment in 2-3 sentences>")
                appendLine("INSIGHTS: <key observations about the metrics in 2-3 sentences>")
                appendLine("RECOMMENDATIONS:")
                appendLine("- <recommendation 1>")
                appendLine("- <recommendation 2>")
                appendLine("- <recommendation 3>")
            }

            try {
                val responseText = sendChatMessage(prompt, emptyList(), healthContext)
                parseHealthAnalysisResponse(responseText)
            } catch (e: Exception) {
                HealthAnalysisResult(
                    assessment = "Unable to analyze at this time.",
                    insights = "Could not connect to the health analysis service.",
                    recommendations = listOf("Please check your connection and try again.")
                )
            }
        }

    override suspend fun analyzeImage(prompt: String, imageBase64: String): String =
        withContext(Dispatchers.IO) {
            val request = ChatRequestDto(
                message = prompt,
                conversationHistory = emptyList(),
                imageData = imageBase64
            )

            val response = supabaseClient.functions.invoke(
                function = "ai-router",
                body = request
            )
            val body = response.body<String>()
            json.decodeFromString<ChatResponseDto>(body).response
        }

    // ── Local Storage Fallback ──

    private fun loadLocalConversations(): List<Conversation> {
        return try {
            val raw = prefs.getString("ai_conversations", null) ?: return emptyList()
            json.decodeFromString<List<ConversationDto>>(raw)
                .map { it.toDomain() }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun saveLocalConversations(conversations: List<Conversation>) {
        try {
            val dtos = conversations.map { it.toDto() }
            prefs.edit().putString("ai_conversations", json.encodeToString(dtos)).apply()
        } catch (e: Exception) {
            // Ignore save errors
        }
    }

    private fun loadLocalMessages(): List<Message> {
        return try {
            val raw = prefs.getString("ai_messages", null) ?: return emptyList()
            json.decodeFromString<List<MessageDto>>(raw)
                .map { it.toDomain() }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun saveLocalMessages(messages: List<Message>) {
        try {
            val dtos = messages.map { it.toDto() }
            prefs.edit().putString("ai_messages", json.encodeToString(dtos)).apply()
        } catch (e: Exception) {
            // Ignore save errors
        }
    }

    // ── Helper Functions ──

    private fun parseHealthAnalysisResponse(text: String): HealthAnalysisResult {
        var assessment = ""
        var insights = ""
        val recommendations = mutableListOf<String>()

        // Try to parse structured response
        val assessmentMatch = Regex(
            "ASSESSMENT:\\s*(.+?)(?=INSIGHTS:|RECOMMENDATIONS:|$)",
            RegexOption.DOT_MATCHES_ALL
        ).find(text)
        val insightsMatch = Regex(
            "INSIGHTS:\\s*(.+?)(?=RECOMMENDATIONS:|$)",
            RegexOption.DOT_MATCHES_ALL
        ).find(text)
        val recsMatch = Regex(
            "RECOMMENDATIONS:\\s*(.+?)$",
            RegexOption.DOT_MATCHES_ALL
        ).find(text)

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

        return HealthAnalysisResult(
            assessment = assessment,
            insights = insights,
            recommendations = recommendations
        )
    }
}
