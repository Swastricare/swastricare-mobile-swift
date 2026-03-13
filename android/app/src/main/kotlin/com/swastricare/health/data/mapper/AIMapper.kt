package com.swastricare.health.data.mapper

import com.swastricare.health.data.remote.dto.ai.ConversationDto
import com.swastricare.health.data.remote.dto.ai.ContextMessageDto
import com.swastricare.health.data.remote.dto.ai.MessageDto
import com.swastricare.health.domain.model.ai.Conversation
import com.swastricare.health.domain.model.ai.Message
import com.swastricare.health.domain.model.ai.MessageFeedback
import com.swastricare.health.domain.model.ai.MessageRole
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Mapper for AI domain models <-> DTOs.
 */
object AIMapper {

    // ── Conversation Mapping ──

    fun ConversationDto.toDomain(): Conversation {
        return Conversation(
            id = id,
            title = title,
            createdAt = parseDateTime(created_at),
            updatedAt = parseDateTime(updated_at),
            isArchived = is_archived
        )
    }

    fun Conversation.toDto(): ConversationDto {
        return ConversationDto(
            id = id,
            title = title,
            created_at = createdAt.atZone(ZoneId.systemDefault()).toInstant().toString(),
            updated_at = updatedAt.atZone(ZoneId.systemDefault()).toInstant().toString(),
            is_archived = isArchived
        )
    }

    // ── Message Mapping ──

    fun MessageDto.toDomain(): Message {
        return Message(
            id = id,
            conversationId = conversation_id,
            role = role.toMessageRole(),
            content = content,
            isBookmarked = is_bookmarked,
            feedback = feedback?.toMessageFeedback(),
            createdAt = parseDateTime(created_at)
        )
    }

    fun Message.toDto(): MessageDto {
        return MessageDto(
            id = id,
            conversation_id = conversationId,
            role = role.toStringRole(),
            content = content,
            is_bookmarked = isBookmarked,
            feedback = feedback?.toStringFeedback(),
            created_at = createdAt.atZone(ZoneId.systemDefault()).toInstant().toString()
        )
    }

    // ── Context Message Mapping ──

    fun Message.toContextDto(): ContextMessageDto {
        return ContextMessageDto(
            role = role.toStringRole(),
            content = content
        )
    }

    // ── Helper Functions ──

    private fun parseDateTime(dateString: String): LocalDateTime {
        return try {
            val instant = Instant.parse(dateString)
            LocalDateTime.ofInstant(instant, ZoneId.systemDefault())
        } catch (e: Exception) {
            // Fallback to current time if parsing fails
            LocalDateTime.now()
        }
    }

    private fun String.toMessageRole(): MessageRole {
        return when (this.lowercase()) {
            "user" -> MessageRole.USER
            "assistant" -> MessageRole.ASSISTANT
            else -> MessageRole.ASSISTANT
        }
    }

    private fun MessageRole.toStringRole(): String {
        return when (this) {
            MessageRole.USER -> "user"
            MessageRole.ASSISTANT -> "assistant"
        }
    }

    private fun String.toMessageFeedback(): MessageFeedback {
        return when (this.lowercase()) {
            "up", "positive" -> MessageFeedback.POSITIVE
            "down", "negative" -> MessageFeedback.NEGATIVE
            else -> MessageFeedback.NEGATIVE
        }
    }

    private fun MessageFeedback.toStringFeedback(): String {
        return when (this) {
            MessageFeedback.POSITIVE -> "up"
            MessageFeedback.NEGATIVE -> "down"
        }
    }
}
