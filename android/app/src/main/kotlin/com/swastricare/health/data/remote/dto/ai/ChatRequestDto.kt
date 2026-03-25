package com.swastricare.health.data.remote.dto.ai

import kotlinx.serialization.Serializable

/**
 * DTO for chat request to AI router edge function.
 */
@Serializable
data class ChatRequestDto(
    val message: String,
    val conversationHistory: List<ContextMessageDto>,
    val imageData: String? = null,
    val healthContext: String? = null
)

/**
 * DTO for conversation context message.
 */
@Serializable
data class ContextMessageDto(
    val role: String,
    val content: String
)

/**
 * DTO for chat response from AI router.
 */
@Serializable
data class ChatResponseDto(
    val response: String,
    val error: Boolean? = null
)
