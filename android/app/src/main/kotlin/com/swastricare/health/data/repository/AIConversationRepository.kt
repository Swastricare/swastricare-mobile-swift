package com.swastricare.health.data.repository

import android.content.SharedPreferences
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

private val aiJson = Json { ignoreUnknownKeys = true; isLenient = true }

// ── Models ──

@Serializable
data class EmbeddedMessage(
    val role: String = "",
    val content: String = "",
    val timestamp: String? = null
)

@Serializable
data class AIConversation(
    val id: String = java.util.UUID.randomUUID().toString(),
    val title: String = "New Conversation",
    val created_at: String = java.time.Instant.now().toString(),
    val updated_at: String = java.time.Instant.now().toString(),
    val is_archived: Boolean = false,
    val messages: List<EmbeddedMessage>? = null
)

@Serializable
data class AIMessageRecord(
    val id: String = java.util.UUID.randomUUID().toString(),
    val conversation_id: String,
    val role: String, // "user" or "assistant"
    val content: String,
    val is_bookmarked: Boolean = false,
    val feedback: String? = null, // "up" or "down" or null
    val created_at: String = java.time.Instant.now().toString()
)

// ── Interface ──

interface AIConversationRepository {
    // Conversations
    suspend fun getConversations(): List<AIConversation>
    suspend fun createConversation(title: String): AIConversation
    suspend fun deleteConversation(id: String)
    suspend fun archiveConversation(id: String)

    // Messages
    suspend fun getMessages(conversationId: String): List<AIMessageRecord>
    suspend fun addMessage(message: AIMessageRecord)
    suspend fun updateMessageBookmark(messageId: String, bookmarked: Boolean)
    suspend fun updateMessageFeedback(messageId: String, feedback: String?)
    suspend fun getBookmarkedMessages(): List<AIMessageRecord>
}

// ── Supabase Implementation ──

@Singleton
class SupabaseAIConversationRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val prefs: SharedPreferences
) : AIConversationRepository {

    // ── Conversations ──

    override suspend fun getConversations(): List<AIConversation> = withContext(Dispatchers.IO) {
        try {
            supabaseClient.from("ai_conversations")
                .select()
                .decodeList<AIConversation>()
                .sortedByDescending { it.updated_at }
        } catch (e: Exception) {
            // Fallback to local
            loadLocalConversations()
        }
    }

    override suspend fun createConversation(title: String): AIConversation = withContext(Dispatchers.IO) {
        val conversation = AIConversation(title = title)
        try {
            supabaseClient.from("ai_conversations").insert(conversation)
        } catch (e: Exception) {
            // Save locally
            val local = loadLocalConversations().toMutableList()
            local.add(conversation)
            saveLocalConversations(local)
        }
        conversation
    }

    override suspend fun deleteConversation(id: String): Unit = withContext(Dispatchers.IO) {
        try {
            supabaseClient.from("ai_messages").delete { filter { eq("conversation_id", id) } }
            supabaseClient.from("ai_conversations").delete { filter { eq("id", id) } }
        } catch (e: Exception) {
            val local = loadLocalConversations().filter { it.id != id }
            saveLocalConversations(local)
            val msgs = loadLocalMessages().filter { it.conversation_id != id }
            saveLocalMessages(msgs)
        }
    }

    override suspend fun archiveConversation(id: String): Unit = withContext(Dispatchers.IO) {
        try {
            supabaseClient.from("ai_conversations").update(
                { set("is_archived", true) }
            ) { filter { eq("id", id) } }
        } catch (e: Exception) {
            val local = loadLocalConversations().map {
                if (it.id == id) it.copy(is_archived = true) else it
            }
            saveLocalConversations(local)
        }
    }

    // ── Messages ──

    override suspend fun getMessages(conversationId: String): List<AIMessageRecord> =
        withContext(Dispatchers.IO) {
            try {
                // Try ai_messages table first (Android approach)
                val messages = supabaseClient.from("ai_messages")
                    .select { filter { eq("conversation_id", conversationId) } }
                    .decodeList<AIMessageRecord>()
                    .sortedBy { it.created_at }

                if (messages.isNotEmpty()) return@withContext messages

                // Fallback: read embedded messages from ai_conversations (iOS approach)
                val conversation = supabaseClient.from("ai_conversations")
                    .select { filter { eq("id", conversationId) } }
                    .decodeList<AIConversation>()
                    .firstOrNull()

                conversation?.messages?.mapIndexed { index, msg ->
                    AIMessageRecord(
                        id = "${conversationId}_$index",
                        conversation_id = conversationId,
                        role = msg.role,
                        content = msg.content,
                        created_at = msg.timestamp ?: conversation.created_at
                    )
                } ?: emptyList()
            } catch (e: Exception) {
                loadLocalMessages().filter { it.conversation_id == conversationId }
            }
        }

    override suspend fun addMessage(message: AIMessageRecord): Unit = withContext(Dispatchers.IO) {
        try {
            supabaseClient.from("ai_messages").insert(message)
        } catch (e: Exception) {
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
                ) { filter { eq("id", messageId) } }
            } catch (e: Exception) {
                val local = loadLocalMessages().map {
                    if (it.id == messageId) it.copy(is_bookmarked = bookmarked) else it
                }
                saveLocalMessages(local)
            }
        }

    override suspend fun updateMessageFeedback(messageId: String, feedback: String?): Unit =
        withContext(Dispatchers.IO) {
            try {
                supabaseClient.from("ai_messages").update(
                    { set("feedback", feedback) }
                ) { filter { eq("id", messageId) } }
            } catch (e: Exception) {
                val local = loadLocalMessages().map {
                    if (it.id == messageId) it.copy(feedback = feedback) else it
                }
                saveLocalMessages(local)
            }
        }

    override suspend fun getBookmarkedMessages(): List<AIMessageRecord> =
        withContext(Dispatchers.IO) {
            try {
                supabaseClient.from("ai_messages")
                    .select { filter { eq("is_bookmarked", true) } }
                    .decodeList<AIMessageRecord>()
            } catch (e: Exception) {
                loadLocalMessages().filter { it.is_bookmarked }
            }
        }

    // ── Local fallback ──

    private fun loadLocalConversations(): List<AIConversation> {
        return try {
            val raw = prefs.getString("ai_conversations", null) ?: return emptyList()
            aiJson.decodeFromString<List<AIConversation>>(raw)
        } catch (_: Exception) { emptyList() }
    }

    private fun saveLocalConversations(conversations: List<AIConversation>) {
        prefs.edit().putString("ai_conversations", aiJson.encodeToString(conversations)).apply()
    }

    private fun loadLocalMessages(): List<AIMessageRecord> {
        return try {
            val raw = prefs.getString("ai_messages", null) ?: return emptyList()
            aiJson.decodeFromString<List<AIMessageRecord>>(raw)
        } catch (_: Exception) { emptyList() }
    }

    private fun saveLocalMessages(messages: List<AIMessageRecord>) {
        prefs.edit().putString("ai_messages", aiJson.encodeToString(messages)).apply()
    }
}
