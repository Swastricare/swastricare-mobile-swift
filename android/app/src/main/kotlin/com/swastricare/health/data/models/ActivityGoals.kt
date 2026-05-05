package com.swastricare.health.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ActivityGoals(
    val dailyStepsGoal: Int = 10_000,
    val dailyDistanceMeters: Int = 8_000,
    val dailyCaloriesGoal: Int = 500,
    val dailyActiveMinutes: Int = 30
) {
    val dailyDistanceKm: Double get() = dailyDistanceMeters / 1000.0
}

@Serializable
internal data class ActivityGoalsDto(
    @SerialName("health_profile_id") val healthProfileId: String,
    @SerialName("daily_steps_goal") val dailyStepsGoal: Int = 10_000,
    @SerialName("daily_distance_meters") val dailyDistanceMeters: Int = 8_000,
    @SerialName("daily_calories_goal") val dailyCaloriesGoal: Int = 500,
    @SerialName("daily_active_minutes") val dailyActiveMinutes: Int = 30
) {
    fun toDomain() = ActivityGoals(
        dailyStepsGoal = dailyStepsGoal,
        dailyDistanceMeters = dailyDistanceMeters,
        dailyCaloriesGoal = dailyCaloriesGoal,
        dailyActiveMinutes = dailyActiveMinutes
    )
}
