package com.swastricare.health.domain.usecase.ai

import com.swastricare.health.domain.model.ai.Message
import com.swastricare.health.domain.repository.AIRepository
import javax.inject.Inject

/**
 * Use case: Get messages for a conversation.
 */
class GetMessagesUseCase @Inject constructor(
    private val repository: AIRepository
) {
    /**
     * Get all messages for a conversation.
     */
    suspend operator fun invoke(conversationId: String): List<Message> {
        return repository.getMessages(conversationId)
            .sortedBy { it.createdAt }
    }

    /**
     * Get bookmarked messages across all conversations.
     */
    suspend fun getBookmarked(): List<Message> {
        return repository.getBookmarkedMessages()
            .sortedByDescending { it.createdAt }
    }

    /**
     * Get recent messages from a conversation (last N messages).
     */
    suspend fun getRecent(conversationId: String, limit: Int = 20): List<Message> {
        return repository.getMessages(conversationId)
            .sortedBy { it.createdAt }
            .takeLast(limit)
    }
}
