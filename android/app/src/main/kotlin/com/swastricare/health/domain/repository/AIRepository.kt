package com.swastricare.health.domain.repository

import com.swastricare.health.domain.model.ai.Conversation
import com.swastricare.health.domain.model.ai.HealthContext
import com.swastricare.health.domain.model.ai.Message
import com.swastricare.health.domain.model.ai.MessageFeedback

/**
 * Repository interface for AI conversation operations.
 * Defines business operations for AI chat functionality.
 */
interface AIRepository {
    // ── Conversations ──

    /**
     * Get all conversations (non-archived).
     */
    suspend fun getConversations(): List<Conversation>

    /**
     * Get archived conversations.
     */
    suspend fun getArchivedConversations(): List<Conversation>

    /**
     * Create a new conversation.
     */
    suspend fun createConversation(title: String): Conversation

    /**
     * Delete a conversation and all its messages.
     */
    suspend fun deleteConversation(id: String)

    /**
     * Archive a conversation.
     */
    suspend fun archiveConversation(id: String)

    /**
     * Unarchive a conversation.
     */
    suspend fun unarchiveConversation(id: String)

    // ── Messages ──

    /**
     * Get all messages for a conversation.
     */
    suspend fun getMessages(conversationId: String): List<Message>

    /**
     * Add a new message to a conversation.
     */
    suspend fun addMessage(message: Message)

    /**
     * Update message bookmark status.
     */
    suspend fun updateMessageBookmark(messageId: String, bookmarked: Boolean)

    /**
     * Update message feedback (thumbs up/down).
     */
    suspend fun updateMessageFeedback(messageId: String, feedback: MessageFeedback?)

    /**
     * Get all bookmarked messages across all conversations.
     */
    suspend fun getBookmarkedMessages(): List<Message>

    // ── AI Operations ──

    /**
     * Send a chat message and get AI response.
     */
    suspend fun sendChatMessage(
        message: String,
        conversationHistory: List<Message>,
        healthContext: HealthContext? = null
    ): String

    /**
     * Analyze health metrics and get AI insights.
     */
    suspend fun analyzeHealth(healthContext: HealthContext): HealthAnalysisResult

    /**
     * Analyze an image (medical imaging, food, etc.).
     */
    suspend fun analyzeImage(prompt: String, imageBase64: String): String
}

/**
 * Result of health analysis.
 */
data class HealthAnalysisResult(
    val assessment: String,
    val insights: String,
    val recommendations: List<String>
)
