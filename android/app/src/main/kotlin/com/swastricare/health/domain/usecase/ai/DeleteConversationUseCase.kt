package com.swastricare.health.domain.usecase.ai

import com.swastricare.health.domain.repository.AIRepository
import javax.inject.Inject

/**
 * Use case: Delete a conversation and all its messages.
 */
class DeleteConversationUseCase @Inject constructor(
    private val repository: AIRepository
) {
    /**
     * Delete a conversation by ID.
     */
    suspend operator fun invoke(conversationId: String) {
        repository.deleteConversation(conversationId)
    }

    /**
     * Delete multiple conversations.
     */
    suspend fun deleteMultiple(conversationIds: List<String>) {
        conversationIds.forEach { id ->
            repository.deleteConversation(id)
        }
    }
}
