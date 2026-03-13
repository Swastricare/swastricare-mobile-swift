package com.swastricare.health.domain.model.menstrualcycle

/**
 * Domain model for menstrual cycle user settings.
 */
data class CycleSettings(
    val averageCycleLength: Int = 28,
    val averagePeriodLength: Int = 5,
    val reminderEnabled: Boolean = true,
    val reminderTime: String = "09:00"
) {
    /**
     * Returns a validated cycle length constrained to medical normal range (21-45 days).
     * Use this for predictions to prevent invalid calculations.
     */
    val validatedCycleLength: Int
        get() = averageCycleLength.coerceIn(21, 45)

    /**
     * Returns a validated period length constrained to normal range (2-10 days).
     */
    val validatedPeriodLength: Int
        get() = averagePeriodLength.coerceIn(2, 10)

    /**
     * Validates if the settings are within acceptable ranges.
     */
    fun isValid(): Boolean {
        return averageCycleLength in 21..45 &&
                averagePeriodLength in 2..10 &&
                reminderTime.matches(Regex("^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$"))
    }
}
