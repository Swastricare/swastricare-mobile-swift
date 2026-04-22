package com.swastricare.health.domain.model.menstrualcycle

/**
 * Domain model for menstrual cycle user settings.
 */
data class CycleSettings(
    val averageCycleLength: Int = 28,
    val averagePeriodLength: Int = 5,
    val reminderEnabled: Boolean = true,
    val reminderTime: String = "09:00",
    val reminderDaysBefore: Int = 2,
    val fertileReminderEnabled: Boolean = false,
    val pmsReminderEnabled: Boolean = false,
    val ovulationReminderEnabled: Boolean = false,
    val lutealPhaseLength: Int = 14
) {
    val validatedCycleLength: Int
        get() = averageCycleLength.coerceIn(21, 45)

    val validatedPeriodLength: Int
        get() = averagePeriodLength.coerceIn(2, 10)

    val validatedReminderDaysBefore: Int
        get() = reminderDaysBefore.coerceIn(1, 7)

    val validatedLutealPhaseLength: Int
        get() = lutealPhaseLength.coerceIn(10, 16)

    fun isValid(): Boolean {
        return averageCycleLength in 21..45 &&
                averagePeriodLength in 2..10 &&
                reminderDaysBefore in 1..7 &&
                lutealPhaseLength in 10..16 &&
                reminderTime.matches(Regex("^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$"))
    }
}
