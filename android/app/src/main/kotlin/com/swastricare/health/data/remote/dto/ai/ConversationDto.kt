package com.swastricare.health.data.remote.dto.ai

import kotlinx.serialization.Serializable

/**
 * Data Transfer Object for AI conversations.
 * Maps to the ai_conversations table in Supabase.
 */
@Serializable
data class ConversationDto(
    val id: String = java.util.UUID.randomUUID().toString(),
    val title: String = "New Conversation",
    val created_at: String = java.time.Instant.now().toString(),
    val updated_at: String = java.time.Instant.now().toString(),
    val is_archived: Boolean = false
)
