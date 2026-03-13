package com.swastricare.health.domain.model.hydration

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Domain model for a hydration entry.
 * Pure business model with no Android/Framework dependencies.
 */
data class HydrationEntry(
    val id: String,
    val drinkType: DrinkType,
    val amountMl: Int,
    val effectiveMl: Int,
    val consumedAt: LocalDateTime,
    val notes: String? = null,
    val synced: Boolean = false
) {
    /**
     * Business logic: Get formatted time (12-hour format).
     */
    fun getFormattedTime(): String {
        val formatter = DateTimeFormatter.ofPattern("h:mm a")
        return consumedAt.format(formatter)
    }

    /**
     * Business logic: Check if entry is for today.
     */
    fun isToday(now: LocalDateTime = LocalDateTime.now()): Boolean {
        return consumedAt.toLocalDate() == now.toLocalDate()
    }

    /**
     * Business logic: Check if contains caffeine.
     */
    fun containsCaffeine(): Boolean = drinkType.containsCaffeine
}
