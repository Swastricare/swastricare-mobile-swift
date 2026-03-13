package com.swastricare.health.domain.model.ai

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Domain model for an AI conversation.
 * Pure business model with no Android/Framework dependencies.
 */
data class Conversation(
    val id: String,
    val title: String,
    val createdAt: LocalDateTime,
    val updatedAt: LocalDateTime,
    val isArchived: Boolean = false
) {
    /**
     * Business logic: Get formatted date (e.g., "Today", "Yesterday", or specific date).
     */
    fun getFormattedDate(now: LocalDateTime = LocalDateTime.now()): String {
        val date = updatedAt.toLocalDate()
        val today = now.toLocalDate()
        return when {
            date == today -> "Today"
            date == today.minusDays(1) -> "Yesterday"
            else -> {
                val formatter = DateTimeFormatter.ofPattern("MMM dd, yyyy")
                date.format(formatter)
            }
        }
    }

    /**
     * Business logic: Get formatted time (12-hour format).
     */
    fun getFormattedTime(): String {
        val formatter = DateTimeFormatter.ofPattern("h:mm a")
        return updatedAt.format(formatter)
    }

    /**
     * Business logic: Check if conversation is new (created recently).
     */
    fun isNew(now: LocalDateTime = LocalDateTime.now()): Boolean {
        val minutesAgo = java.time.Duration.between(createdAt, now).toMinutes()
        return minutesAgo < 5
    }
}
