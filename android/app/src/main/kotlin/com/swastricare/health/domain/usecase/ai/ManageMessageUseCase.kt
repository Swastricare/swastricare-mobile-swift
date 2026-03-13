package com.swastricare.health.domain.usecase.ai

import com.swastricare.health.domain.model.ai.Message
import com.swastricare.health.domain.model.ai.MessageFeedback
import com.swastricare.health.domain.repository.AIRepository
import javax.inject.Inject

/**
 * Use case: Manage messages (add, bookmark, feedback).
 */
class ManageMessageUseCase @Inject constructor(
    private val repository: AIRepository
) {
    /**
     * Add a new message to a conversation.
     */
    suspend fun add(message: Message) {
        repository.addMessage(message)
    }

    /**
     * Toggle bookmark status of a message.
     */
    suspend fun toggleBookmark(messageId: String, currentStatus: Boolean) {
        repository.updateMessageBookmark(messageId, !currentStatus)
    }

    /**
     * Add positive feedback to a message.
     */
    suspend fun addPositiveFeedback(messageId: String) {
        repository.updateMessageFeedback(messageId, MessageFeedback.POSITIVE)
    }

    /**
     * Add negative feedback to a message.
     */
    suspend fun addNegativeFeedback(messageId: String) {
        repository.updateMessageFeedback(messageId, MessageFeedback.NEGATIVE)
    }

    /**
     * Remove feedback from a message.
     */
    suspend fun removeFeedback(messageId: String) {
        repository.updateMessageFeedback(messageId, null)
    }
}
