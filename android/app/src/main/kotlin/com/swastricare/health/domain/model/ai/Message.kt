package com.swastricare.health.domain.model.ai

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Domain model for an AI chat message.
 * Pure business model with no Android/Framework dependencies.
 */
data class Message(
    val id: String,
    val conversationId: String,
    val role: MessageRole,
    val content: String,
    val isBookmarked: Boolean = false,
    val feedback: MessageFeedback? = null,
    val createdAt: LocalDateTime
) {
    /**
     * Business logic: Get formatted time (12-hour format).
     */
    fun getFormattedTime(): String {
        val formatter = DateTimeFormatter.ofPattern("h:mm a")
        return createdAt.format(formatter)
    }

    /**
     * Business logic: Check if message is from user.
     */
    fun isUserMessage(): Boolean = role == MessageRole.USER

    /**
     * Business logic: Check if message is from assistant.
     */
    fun isAssistantMessage(): Boolean = role == MessageRole.ASSISTANT

    /**
     * Business logic: Check if message has positive feedback.
     */
    fun hasPositiveFeedback(): Boolean = feedback == MessageFeedback.POSITIVE

    /**
     * Business logic: Check if message has negative feedback.
     */
    fun hasNegativeFeedback(): Boolean = feedback == MessageFeedback.NEGATIVE
}

/**
 * Message role enum.
 */
enum class MessageRole {
    USER,
    ASSISTANT
}

/**
 * Message feedback enum.
 */
enum class MessageFeedback {
    POSITIVE,
    NEGATIVE
}
