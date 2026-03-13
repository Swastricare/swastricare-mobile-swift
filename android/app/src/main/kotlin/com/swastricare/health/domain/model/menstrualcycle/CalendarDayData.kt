package com.swastricare.health.domain.model.menstrualcycle

import java.time.LocalDate

/**
 * Domain model for a single day's data in the cycle calendar.
 * Combines actual logged data with predictions.
 */
data class CalendarDayData(
    val date: LocalDate,
    val phase: CyclePhase,
    val isCurrentPeriod: Boolean = false,
    val isPredictedPeriod: Boolean = false,
    val flowLevel: FlowLevel? = null,
    val hasLog: Boolean = false
) {
    /**
     * Returns true if this day has any notable information.
     */
    val hasData: Boolean
        get() = isCurrentPeriod || isPredictedPeriod || hasLog

    /**
     * Returns true if this is today's date.
     */
    fun isToday(): Boolean = date == LocalDate.now()

    /**
     * Returns true if this day is in a fertile window.
     */
    val isFertile: Boolean
        get() = phase == CyclePhase.OVULATION
}
