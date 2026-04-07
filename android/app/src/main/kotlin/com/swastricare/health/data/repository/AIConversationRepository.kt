package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.domain.repository.AuthRepository
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
    val timestamp: String? = null,
    // Per-message state stored inside the JSONB array (matches iOS schema)
    val is_bookmarked: Boolean? = null,
    val user_feedback: String? = null
)

@Serializable
data class AIConversation(
    val id: String = java.util.UUID.randomUUID().toString(),
    val user_id: String? = null,
    val title: String = "New Conversation",
    val created_at: String = java.time.Instant.now().toString(),
    val updated_at: String = java.time.Instant.now().toString(),
    // DB column is `status` ("active" / "archived" / "flagged"). There is no
    // `is_archived` column — that mismatch was silently breaking inserts and
    // archive updates against Supabase.
    val status: String = "active",
    val messages: List<EmbeddedMessage>? = null
)

// Partial-update DTO for writing the messages JSONB without touching other columns.
@Serializable
private data class ConversationMessagesUpdate(
    val messages: List<EmbeddedMessage>,
    val updated_at: String
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
    private val prefs: SharedPreferences,
    private val authRepository: AuthRepository
) : AIConversationRepository {

    // ── Conversations ──

    override suspend fun getConversations(): List<AIConversation> = withContext(Dispatchers.IO) {
        try {
            val userId = authRepository.getCurrentUser()?.id
            if (userId != null) {
                supabaseClient.from("ai_conversations")
                    .select { filter { eq("user_id", userId) } }
                    .decodeList<AIConversation>()
                    .sortedByDescending { it.updated_at }
            } else {
                loadLocalConversations()
            }
        } catch (e: Exception) {
            // Fallback to local
            loadLocalConversations()
        }
    }

    override suspend fun createConversation(title: String): AIConversation = withContext(Dispatchers.IO) {
        val userId = authRepository.getCurrentUser()?.id
        val conversation = AIConversation(title = title, user_id = userId)
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
            // Messages live inside ai_conversations.messages (JSONB) — there is no
            // separate ai_messages table, so deleting the conversation row removes them.
            // Scope by user_id to mirror iOS and stay safe if RLS is added later.
            val userId = authRepository.getCurrentUser()?.id
            if (userId != null) {
                supabaseClient.from("ai_conversations").delete {
                    filter {
                        eq("id", id)
                        eq("user_id", userId)
                    }
                }
            }
            // Always mirror the deletion to local fallback storage so offline-created
            // conversations are also removed.
            val local = loadLocalConversations().filter { it.id != id }
            saveLocalConversations(local)
            val msgs = loadLocalMessages().filter { it.conversation_id != id }
            saveLocalMessages(msgs)
        } catch (e: Exception) {
            val local = loadLocalConversations().filter { it.id != id }
            saveLocalConversations(local)
            val msgs = loadLocalMessages().filter { it.conversation_id != id }
            saveLocalMessages(msgs)
        }
    }

    override suspend fun archiveConversation(id: String): Unit = withContext(Dispatchers.IO) {
        try {
            val userId = authRepository.getCurrentUser()?.id
            supabaseClient.from("ai_conversations").update(
                { set("status", "archived") }
            ) {
                filter {
                    eq("id", id)
                    if (userId != null) eq("user_id", userId)
                }
            }
        } catch (e: Exception) {
            val local = loadLocalConversations().map {
                if (it.id == id) it.copy(status = "archived") else it
            }
            saveLocalConversations(local)
        }
    }

    // ── Messages ──
    //
    // Messages are stored as a JSONB array on `ai_conversations.messages` (matching
    // iOS). There is no separate `ai_messages` table — earlier code targeting one
    // was silently failing and falling back to local SharedPreferences only.

    override suspend fun getMessages(conversationId: String): List<AIMessageRecord> =
        withContext(Dispatchers.IO) {
            try {
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
                        is_bookmarked = msg.is_bookmarked ?: false,
                        feedback = msg.user_feedback,
                        created_at = msg.timestamp ?: conversation.created_at
                    )
                } ?: emptyList()
            } catch (e: Exception) {
                loadLocalMessages().filter { it.conversation_id == conversationId }
            }
        }

    override suspend fun addMessage(message: AIMessageRecord): Unit = withContext(Dispatchers.IO) {
        try {
            val userId = authRepository.getCurrentUser()?.id
                ?: throw IllegalStateException("Not authenticated")

            // Fetch the existing conversation row so we can append to its messages
            // array. iOS uses the same fetch-then-overwrite pattern via saveChatHistory.
            val existing = supabaseClient.from("ai_conversations")
                .select { filter { eq("id", message.conversation_id) } }
                .decodeList<AIConversation>()
                .firstOrNull()
                ?: throw IllegalStateException("Conversation ${message.conversation_id} not found")

            val newMessage = EmbeddedMessage(
                role = message.role,
                content = message.content,
                timestamp = message.created_at
            )
            val updatedMessages = (existing.messages ?: emptyList()) + newMessage
            val now = java.time.Instant.now().toString()

            supabaseClient.from("ai_conversations").update(
                ConversationMessagesUpdate(messages = updatedMessages, updated_at = now)
            ) {
                filter {
                    eq("id", message.conversation_id)
                    eq("user_id", userId)
                }
            }
        } catch (e: Exception) {
            val local = loadLocalMessages().toMutableList()
            local.add(message)
            saveLocalMessages(local)
        }
    }

    // The methods below are not currently called from the active AI screen, but the
    // interface keeps them. Per-message bookmark/feedback would require updating an
    // element inside the JSONB array; until that UI exists, store locally only so we
    // never crash trying to hit a non-existent table.

    override suspend fun updateMessageBookmark(messageId: String, bookmarked: Boolean): Unit =
        withContext(Dispatchers.IO) {
            val local = loadLocalMessages().map {
                if (it.id == messageId) it.copy(is_bookmarked = bookmarked) else it
            }
            saveLocalMessages(local)
        }

    override suspend fun updateMessageFeedback(messageId: String, feedback: String?): Unit =
        withContext(Dispatchers.IO) {
            val local = loadLocalMessages().map {
                if (it.id == messageId) it.copy(feedback = feedback) else it
            }
            saveLocalMessages(local)
        }

    override suspend fun getBookmarkedMessages(): List<AIMessageRecord> =
        withContext(Dispatchers.IO) {
            loadLocalMessages().filter { it.is_bookmarked }
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
