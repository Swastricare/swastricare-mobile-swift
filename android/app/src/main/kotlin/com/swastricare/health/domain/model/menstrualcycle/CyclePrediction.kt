package com.swastricare.health.domain.model.menstrualcycle

import java.time.LocalDate

/**
 * Domain model for menstrual cycle predictions.
 * Contains predicted dates for next period, ovulation, and fertile window.
 */
data class CyclePrediction(
    val nextPeriodDate: LocalDate,
    val ovulationDate: LocalDate,
    val fertileWindowStart: LocalDate,
    val fertileWindowEnd: LocalDate
) {
    /**
     * Returns the number of days until the next predicted period.
     */
    fun daysUntilNextPeriod(from: LocalDate = LocalDate.now()): Int {
        return java.time.temporal.ChronoUnit.DAYS.between(from, nextPeriodDate).toInt()
            .coerceAtLeast(0)
    }

    /**
     * Checks if a given date falls within the fertile window.
     */
    fun isInFertileWindow(date: LocalDate): Boolean {
        return !date.isBefore(fertileWindowStart) && !date.isAfter(fertileWindowEnd)
    }

    /**
     * Checks if a given date is the predicted period start.
     */
    fun isPredictedPeriodDate(date: LocalDate, periodLength: Int = 5): Boolean {
        val periodEnd = nextPeriodDate.plusDays((periodLength - 1).toLong())
        return !date.isBefore(nextPeriodDate) && !date.isAfter(periodEnd)
    }
}
