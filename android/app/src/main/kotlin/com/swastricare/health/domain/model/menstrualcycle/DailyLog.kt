package com.swastricare.health.domain.model.menstrualcycle

import java.time.LocalDate

/**
 * Domain model for daily menstrual cycle logging.
 * Captures flow level, symptoms, mood, and pain for a specific day.
 */
data class DailyLog(
    val id: String,
    val cycleId: String,
    val date: LocalDate,
    val flowLevel: FlowLevel,
    val symptoms: List<Symptom>,
    val mood: Mood?,
    val notes: String?,
    val painLevel: Int // 0-10 scale
) {
    /**
     * Validates that pain level is within acceptable range.
     */
    fun isValidPainLevel(): Boolean = painLevel in 0..10

    /**
     * Returns true if this is a menstruation day (has flow).
     */
    val isMenstruationDay: Boolean
        get() = flowLevel != FlowLevel.NONE
}
