package com.swastricare.health.domain.model.menstrualcycle

/**
 * Enum representing the four phases of the menstrual cycle.
 */
enum class CyclePhase(
    val displayName: String,
    val emoji: String,
    val description: String
) {
    MENSTRUAL(
        displayName = "Menstrual",
        emoji = "🩸",
        description = "Your period phase. Rest and take care of yourself."
    ),
    FOLLICULAR(
        displayName = "Follicular",
        emoji = "🌱",
        description = "Your body is preparing for ovulation. Energy levels are rising."
    ),
    OVULATION(
        displayName = "Ovulation",
        emoji = "🌸",
        description = "Peak fertility window. You may feel more energetic and social."
    ),
    LUTEAL(
        displayName = "Luteal",
        emoji = "🍂",
        description = "Post-ovulation phase. You may experience PMS symptoms."
    ),
    UNKNOWN(
        displayName = "Unknown",
        emoji = "❓",
        description = "Log your period to get phase predictions."
    );

    companion object {
        /**
         * Determines the cycle phase based on day in cycle and cycle parameters.
         */
        fun fromDayInCycle(
            dayInCycle: Int,
            periodLength: Int,
            cycleLength: Int
        ): CyclePhase {
            if (dayInCycle <= 0 || dayInCycle > cycleLength) return UNKNOWN

            val ovulationDay = cycleLength - 14 // Standard 14-day luteal phase

            return when {
                dayInCycle <= periodLength -> MENSTRUAL
                dayInCycle < ovulationDay - 3 -> FOLLICULAR
                dayInCycle in (ovulationDay - 3)..ovulationDay -> OVULATION
                dayInCycle <= cycleLength -> LUTEAL
                else -> UNKNOWN
            }
        }
    }
}
