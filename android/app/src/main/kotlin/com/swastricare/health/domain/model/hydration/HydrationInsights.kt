package com.swastricare.health.domain.model.hydration

/**
 * Domain model for hydration insights and statistics.
 */
data class HydrationInsights(
    val streakDays: Int = 0,
    val avgDailyIntake: Int = 0,
    val mostCommonDrink: String? = null,
    val caffeineCount: Int = 0,
    val caffeineAmountMl: Int = 0
) {
    /**
     * Business logic: Check if has active streak.
     */
    fun hasActiveStreak(): Boolean = streakDays > 0

    /**
     * Business logic: Check if caffeine intake is high.
     */
    fun hasHighCaffeineIntake(): Boolean = caffeineCount >= 3 || caffeineAmountMl >= 400
}
