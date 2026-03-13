package com.swastricare.health.domain.usecase.ai

import com.swastricare.health.domain.model.ai.HealthContext
import com.swastricare.health.domain.model.ai.Message
import com.swastricare.health.domain.repository.AIRepository
import javax.inject.Inject

/**
 * Use case: Send a message to AI and get response.
 * Handles message sending logic and conversation context.
 */
class SendMessageUseCase @Inject constructor(
    private val repository: AIRepository
) {
    /**
     * Send a message with conversation history and optional health context.
     */
    suspend operator fun invoke(
        message: String,
        conversationHistory: List<Message>,
        healthContext: HealthContext? = null
    ): String {
        return repository.sendChatMessage(
            message = message,
            conversationHistory = conversationHistory,
            healthContext = healthContext
        )
    }

    /**
     * Send a message with health context automatically included.
     */
    suspend fun sendWithHealthContext(
        message: String,
        conversationHistory: List<Message>,
        healthContext: HealthContext
    ): String {
        return repository.sendChatMessage(
            message = message,
            conversationHistory = conversationHistory,
            healthContext = healthContext
        )
    }
}
