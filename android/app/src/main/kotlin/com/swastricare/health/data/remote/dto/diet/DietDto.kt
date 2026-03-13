package com.swastricare.health.data.remote.dto.diet

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ─────────────────────────────────────
// MARK: - Data Transfer Objects (DTOs)
// ─────────────────────────────────────

/**
 * DTO for food_items table.
 * Maps directly to Supabase table structure.
 */
@Serializable
data class FoodItemDto(
    val id: String,
    val name: String,
    val brand: String? = null,
    @SerialName("serving_size") val servingSize: Double = 100.0,
    @SerialName("serving_unit") val servingUnit: String = "g",
    val calories: Double = 0.0,
    @SerialName("protein_g") val proteinG: Double = 0.0,
    @SerialName("carbs_g") val carbsG: Double = 0.0,
    @SerialName("fat_g") val fatG: Double = 0.0,
    @SerialName("fiber_g") val fiberG: Double? = null,
    @SerialName("is_vegetarian") val isVegetarian: Boolean = true,
    @SerialName("is_vegan") val isVegan: Boolean = false,
    val category: String = "other"
)

/**
 * DTO for diet_logs table.
 * Used for both reading from and writing to Supabase.
 */
@Serializable
data class DietLogDto(
    val id: String,
    @SerialName("health_profile_id") val healthProfileId: String? = null,
    @SerialName("food_item_id") val foodItemId: String? = null,
    @SerialName("meal_type") val mealType: String,
    @SerialName("food_name") val foodName: String,
    val quantity: Double,
    @SerialName("serving_unit") val servingUnit: String = "g",
    val calories: Double,
    @SerialName("protein_g") val proteinG: Double = 0.0,
    @SerialName("carbs_g") val carbsG: Double = 0.0,
    @SerialName("fat_g") val fatG: Double = 0.0,
    @SerialName("fiber_g") val fiberG: Double? = null,
    @SerialName("logged_at") val loggedAt: String,   // ISO datetime string
    val notes: String? = null
)

/**
 * DTO for diet goals stored in SharedPreferences.
 */
@Serializable
data class DietGoalsDto(
    @SerialName("daily_calories") val dailyCalories: Int = 2000,
    @SerialName("protein_percent") val proteinPercent: Int = 25,
    @SerialName("carbs_percent") val carbsPercent: Int = 50,
    @SerialName("fat_percent") val fatPercent: Int = 25,
    @SerialName("water_goal_ml") val waterGoalMl: Int = 2500,
    @SerialName("meal_reminders_enabled") val mealRemindersEnabled: Boolean = true
)

/**
 * DTO for local food entry cache.
 * Includes synced flag for tracking cloud sync status.
 */
@Serializable
data class LocalFoodEntryDto(
    val id: String,
    @SerialName("food_item_id") val foodItemId: String? = null,
    @SerialName("meal_type") val mealType: String,
    @SerialName("food_name") val foodName: String,
    val quantity: Double,
    @SerialName("serving_unit") val servingUnit: String = "g",
    val calories: Double,
    @SerialName("protein_g") val proteinG: Double = 0.0,
    @SerialName("carbs_g") val carbsG: Double = 0.0,
    @SerialName("fat_g") val fatG: Double = 0.0,
    @SerialName("fiber_g") val fiberG: Double? = null,
    @SerialName("logged_at") val loggedAt: String,
    val notes: String? = null,
    val synced: Boolean = false
)

/**
 * DTO for AI food analysis response.
 */
@Serializable
data class AnalyzedFoodDto(
    val name: String,
    val calories: Double,
    @SerialName("protein_g") val proteinG: Double,
    @SerialName("carbs_g") val carbsG: Double,
    @SerialName("fat_g") val fatG: Double,
    @SerialName("fiber_g") val fiberG: Double = 0.0,
    @SerialName("serving_size") val servingSize: Double = 1.0,
    @SerialName("serving_unit") val servingUnit: String = "piece",
    val category: String = "other"
)
