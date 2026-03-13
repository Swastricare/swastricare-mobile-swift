package com.swastricare.health.data.remote.dto.ai

import kotlinx.serialization.Serializable

/**
 * Data Transfer Object for AI messages.
 * Maps to the ai_messages table in Supabase.
 */
@Serializable
data class MessageDto(
    val id: String = java.util.UUID.randomUUID().toString(),
    val conversation_id: String,
    val role: String, // "user" or "assistant"
    val content: String,
    val is_bookmarked: Boolean = false,
    val feedback: String? = null, // "up" or "down" or null
    val created_at: String = java.time.Instant.now().toString()
)
