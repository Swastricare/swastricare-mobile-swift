package com.swastricare.health.domain.model.hydration

/**
 * Domain model for hydration goal.
 * Contains daily goal and breakdown details.
 */
data class HydrationGoal(
    val dailyGoalMl: Int = 2500,
    val breakdown: GoalBreakdown = GoalBreakdown()
) {
    data class GoalBreakdown(
        val baseAmount: Int = 2310,
        val activityBonus: Int = 0
    ) {
        /**
         * Business logic: Get breakdown description.
         */
        fun getDescription(): String {
            val parts = mutableListOf("${baseAmount}ml base")
            if (activityBonus != 0) {
                val sign = if (activityBonus > 0) "+" else ""
                parts.add("${sign}${activityBonus}ml activity")
            }
            return parts.joinToString(", ")
        }
    }

    companion object {
        /** Base multiplier: 33ml per kg body weight */
        const val BASE_MULTIPLIER = 33.0

        /** Default goal if no weight available */
        const val DEFAULT_GOAL = 2500

        /**
         * Calculate hydration goal from preferences.
         */
        fun calculate(preferences: HydrationPreferences): HydrationGoal {
            // If custom goal is set, use it directly
            preferences.customGoalMl?.let { custom ->
                return HydrationGoal(
                    dailyGoalMl = custom,
                    breakdown = GoalBreakdown(baseAmount = custom, activityBonus = 0)
                )
            }

            val weight = preferences.weightKg ?: 70.0
            val baseAmount = (weight * BASE_MULTIPLIER).toInt()
            val activityLevel = preferences.activityLevel

            val activityAdjusted = (baseAmount * activityLevel.multiplier).toInt()
            val activityBonus = activityAdjusted - baseAmount

            return HydrationGoal(
                dailyGoalMl = activityAdjusted,
                breakdown = GoalBreakdown(
                    baseAmount = baseAmount,
                    activityBonus = activityBonus
                )
            )
        }
    }
}
