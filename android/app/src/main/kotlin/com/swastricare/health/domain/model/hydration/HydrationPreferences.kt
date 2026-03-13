package com.swastricare.health.domain.model.hydration

/**
 * Domain model for user hydration preferences.
 */
data class HydrationPreferences(
    val activityLevel: ActivityLevel = ActivityLevel.MODERATE,
    val weightKg: Double? = null,
    val customGoalMl: Int? = null
) {
    companion object {
        val Default = HydrationPreferences()
    }
}

/**
 * Activity level enum for hydration calculations.
 */
enum class ActivityLevel(
    val dbValue: String,
    val displayName: String,
    val description: String,
    val multiplier: Double,
    val icon: String
) {
    SEDENTARY("sedentary", "Sedentary", "Desk job, minimal exercise", 0.9, "🪑"),
    MODERATE("moderate", "Moderate Activity", "Regular exercise, active lifestyle", 1.0, "🚶"),
    HIGH("high", "High Activity", "Intense workouts, athlete", 1.15, "🏃"),
    OUTDOOR("outdoor", "Outdoor/Hot Climate", "Outdoor work, hot climate exposure", 1.2, "☀️");

    companion object {
        fun fromDb(value: String): ActivityLevel =
            entries.firstOrNull { it.dbValue == value } ?: MODERATE
    }
}
