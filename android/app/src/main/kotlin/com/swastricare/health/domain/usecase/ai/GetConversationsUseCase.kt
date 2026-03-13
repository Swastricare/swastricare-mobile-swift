package com.swastricare.health.domain.usecase.ai

import com.swastricare.health.domain.model.ai.Conversation
import com.swastricare.health.domain.repository.AIRepository
import javax.inject.Inject

/**
 * Use case: Get AI conversations with filtering options.
 */
class GetConversationsUseCase @Inject constructor(
    private val repository: AIRepository
) {
    /**
     * Get all active (non-archived) conversations.
     */
    suspend operator fun invoke(): List<Conversation> {
        return repository.getConversations()
            .sortedByDescending { it.updatedAt }
    }

    /**
     * Get archived conversations.
     */
    suspend fun getArchived(): List<Conversation> {
        return repository.getArchivedConversations()
            .sortedByDescending { it.updatedAt }
    }

    /**
     * Get all conversations (including archived).
     */
    suspend fun getAll(): List<Conversation> {
        val active = repository.getConversations()
        val archived = repository.getArchivedConversations()
        return (active + archived).sortedByDescending { it.updatedAt }
    }

    /**
     * Get recent conversations (last N conversations).
     */
    suspend fun getRecent(limit: Int = 10): List<Conversation> {
        return repository.getConversations()
            .sortedByDescending { it.updatedAt }
            .take(limit)
    }
}
