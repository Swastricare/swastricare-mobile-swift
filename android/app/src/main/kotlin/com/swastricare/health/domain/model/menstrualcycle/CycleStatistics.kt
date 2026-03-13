package com.swastricare.health.domain.model.menstrualcycle

/**
 * Domain model for menstrual cycle statistics and insights.
 */
data class CycleStatistics(
    val averageCycleLength: Double,
    val averagePeriodLength: Double,
    val longestCycle: Int,
    val shortestCycle: Int,
    val totalCyclesTracked: Int,
    val regularity: CycleRegularity
) {
    /**
     * Returns the standard deviation of cycle lengths (if calculable).
     */
    val cycleVariability: Double
        get() = (longestCycle - shortestCycle).toDouble()

    /**
     * Returns true if enough data is available for reliable statistics.
     */
    val hasReliableData: Boolean
        get() = totalCyclesTracked >= 3
}

/**
 * Enum representing cycle regularity classification.
 */
enum class CycleRegularity(val displayName: String) {
    REGULAR("Regular"),
    SOMEWHAT_IRREGULAR("Somewhat Irregular"),
    IRREGULAR("Irregular"),
    INSUFFICIENT_DATA("Insufficient Data");

    companion object {
        /**
         * Determines regularity based on cycle length variability.
         * @param variability Standard deviation of cycle lengths
         */
        fun fromVariability(variability: Double, totalCycles: Int): CycleRegularity {
            if (totalCycles < 3) return INSUFFICIENT_DATA

            return when {
                variability <= 2.0 -> REGULAR
                variability <= 4.0 -> SOMEWHAT_IRREGULAR
                else -> IRREGULAR
            }
        }
    }
}
