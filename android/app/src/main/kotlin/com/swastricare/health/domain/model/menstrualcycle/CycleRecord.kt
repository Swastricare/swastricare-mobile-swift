package com.swastricare.health.domain.model.menstrualcycle

import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Domain model for a complete menstrual cycle record.
 * Represents one full cycle from start date to end date (or ongoing).
 */
data class CycleRecord(
    val id: String,
    val userId: String,
    val startDate: LocalDate,
    val endDate: LocalDate? = null,
    val cycleLength: Int? = null,
    val periodLength: Int? = null,
    val notes: String? = null,
    val isPredicted: Boolean = false
) {
    /**
     * Indicates if this cycle is currently active (no end date yet).
     */
    val isActive: Boolean
        get() = endDate == null

    /**
     * Calculates the period length from start to end date if both are available.
     */
    val calculatedPeriodLength: Int?
        get() = endDate?.let {
            ChronoUnit.DAYS.between(startDate, it).toInt() + 1
        }

    /**
     * Returns the effective period length (explicit or calculated).
     */
    val effectivePeriodLength: Int?
        get() = periodLength ?: calculatedPeriodLength
}
