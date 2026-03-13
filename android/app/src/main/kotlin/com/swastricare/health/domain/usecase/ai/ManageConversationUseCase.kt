package com.swastricare.health.domain.usecase.ai

import com.swastricare.health.domain.model.ai.Conversation
import com.swastricare.health.domain.repository.AIRepository
import javax.inject.Inject

/**
 * Use case: Manage conversations (create, archive, unarchive).
 */
class ManageConversationUseCase @Inject constructor(
    private val repository: AIRepository
) {
    /**
     * Create a new conversation.
     */
    suspend fun create(title: String = "New Conversation"): Conversation {
        return repository.createConversation(title)
    }

    /**
     * Archive a conversation.
     */
    suspend fun archive(conversationId: String) {
        repository.archiveConversation(conversationId)
    }

    /**
     * Unarchive a conversation.
     */
    suspend fun unarchive(conversationId: String) {
        repository.unarchiveConversation(conversationId)
    }

    /**
     * Delete a conversation.
     */
    suspend fun delete(conversationId: String) {
        repository.deleteConversation(conversationId)
    }
}
