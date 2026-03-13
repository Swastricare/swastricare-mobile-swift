package com.swastricare.health.data.remote.dto.hydration

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTO for hydration_logs table in Supabase.
 * Maps directly to database schema.
 */
@Serializable
data class HydrationEntryDto(
    @SerialName("id")
    val id: String,

    @SerialName("health_profile_id")
    val healthProfileId: String,

    @SerialName("beverage_type")
    val beverageType: String,

    @SerialName("amount_ml")
    val amountMl: Int,

    @SerialName("consumed_at")
    val consumedAt: String, // ISO-8601 datetime

    @SerialName("notes")
    val notes: String? = null,

    @SerialName("hydration_factor")
    val hydrationFactor: Double
)

/**
 * DTO for creating/updating hydration entries.
 */
@Serializable
data class CreateHydrationEntryDto(
    @SerialName("id")
    val id: String,

    @SerialName("health_profile_id")
    val healthProfileId: String,

    @SerialName("beverage_type")
    val beverageType: String,

    @SerialName("amount_ml")
    val amountMl: Int,

    @SerialName("consumed_at")
    val consumedAt: String,

    @SerialName("notes")
    val notes: String? = null,

    @SerialName("hydration_factor")
    val hydrationFactor: Double
)

/**
 * DTO for hydration preferences (stored in SharedPreferences).
 */
@Serializable
data class HydrationPreferencesDto(
    @SerialName("activity_level")
    val activityLevel: String = "moderate",

    @SerialName("weight_kg")
    val weightKg: Double? = null,

    @SerialName("custom_goal_ml")
    val customGoalMl: Int? = null
)
