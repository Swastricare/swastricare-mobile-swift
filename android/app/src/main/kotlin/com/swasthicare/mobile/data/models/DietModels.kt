package com.swasthicare.mobile.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

// ─────────────────────────────────────
// MARK: - MealType
// ─────────────────────────────────────

enum class MealType(
    val dbValue: String,
    val displayName: String,
    val typicalTime: String
) {
    BREAKFAST("breakfast", "Breakfast", "7:00 AM – 9:00 AM"),
    MORNING_SNACK("morning_snack", "Morning Snack", "10:00 AM – 11:00 AM"),
    LUNCH("lunch", "Lunch", "12:00 PM – 2:00 PM"),
    EVENING_SNACK("evening_snack", "Evening Snack", "4:00 PM – 5:00 PM"),
    DINNER("dinner", "Dinner", "7:00 PM – 9:00 PM"),
    LATE_NIGHT("late_night", "Late Night", "10:00 PM – 11:00 PM");

    companion object {
        fun fromDb(value: String): MealType =
            values().firstOrNull { it.dbValue == value } ?: BREAKFAST
    }
}

// ─────────────────────────────────────
// MARK: - FoodCategory
// ─────────────────────────────────────

enum class FoodCategory(
    val dbValue: String,
    val displayName: String,
    val icon: String
) {
    FRUITS("fruits", "Fruits", "🍎"),
    VEGETABLES("vegetables", "Vegetables", "🥗"),
    GRAINS("grains", "Grains", "🌾"),
    PROTEIN("protein", "Protein", "🍗"),
    DAIRY("dairy", "Dairy", "🥛"),
    BEVERAGES("beverages", "Beverages", "☕"),
    SNACKS("snacks", "Snacks", "🍿"),
    SWEETS("sweets", "Sweets", "🍰"),
    OTHER("other", "Other", "🍽️");

    companion object {
        fun fromDb(value: String): FoodCategory =
            values().firstOrNull { it.dbValue == value } ?: OTHER
    }
}

// ─────────────────────────────────────
// MARK: - ServingUnit
// ─────────────────────────────────────

enum class ServingUnit(val dbValue: String, val displayName: String) {
    G("g", "g"),
    ML("ml", "ml"),
    PIECE("piece", "piece"),
    CUP("cup", "cup"),
    TBSP("tbsp", "tbsp"),
    TSP("tsp", "tsp"),
    OZ("oz", "oz"),
    BOWL("bowl", "bowl"),
    PLATE("plate", "plate");

    companion object {
        fun fromDb(value: String): ServingUnit =
            values().firstOrNull { it.dbValue == value } ?: G
    }
}

// ─────────────────────────────────────
// MARK: - FoodItem
// ─────────────────────────────────────

@Serializable
data class FoodItem(
    val id: String = UUID.randomUUID().toString(),
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
) {
    val categoryEnum: FoodCategory get() = FoodCategory.fromDb(category)
    val servingUnitEnum: ServingUnit get() = ServingUnit.fromDb(servingUnit)
    val displayServingSize: String get() = "${servingSize.toInt()} ${servingUnitEnum.displayName}"
    val caloriesPerServing: String get() = "${calories.toInt()} cal"
    val macroSummary: String get() = "P: ${proteinG.toInt()}g · C: ${carbsG.toInt()}g · F: ${fatG.toInt()}g"
}

// ─────────────────────────────────────
// MARK: - DietLogEntry
// ─────────────────────────────────────

@Serializable
data class DietLogEntry(
    val id: String = UUID.randomUUID().toString(),
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
    @SerialName("logged_at") val loggedAt: String,   // ISO datetime, e.g. "2026-03-02T08:30:00"
    val notes: String? = null,
    val synced: Boolean = false
) {
    val mealTypeEnum: MealType get() = MealType.fromDb(mealType)
    val servingUnitEnum: ServingUnit get() = ServingUnit.fromDb(servingUnit)
}

// ─────────────────────────────────────
// MARK: - DietGoals
// ─────────────────────────────────────

@Serializable
data class DietGoals(
    @SerialName("daily_calories") val dailyCalories: Int = 2000,
    @SerialName("protein_percent") val proteinPercent: Int = 25,
    @SerialName("carbs_percent") val carbsPercent: Int = 50,
    @SerialName("fat_percent") val fatPercent: Int = 25,
    @SerialName("water_goal_ml") val waterGoalMl: Int = 2500,
    @SerialName("meal_reminders_enabled") val mealRemindersEnabled: Boolean = true
) {
    val proteinGrams: Int get() = (dailyCalories * proteinPercent / 100.0 / 4.0).toInt()
    val carbsGrams: Int get() = (dailyCalories * carbsPercent / 100.0 / 4.0).toInt()
    val fatGrams: Int get() = (dailyCalories * fatPercent / 100.0 / 9.0).toInt()

    companion object {
        val Default = DietGoals()
    }
}

// ─────────────────────────────────────
// MARK: - NutritionSummary
// ─────────────────────────────────────

data class NutritionSummary(
    val totalCalories: Double = 0.0,
    val totalProteinG: Double = 0.0,
    val totalCarbsG: Double = 0.0,
    val totalFatG: Double = 0.0,
    val totalFiberG: Double = 0.0,
    val mealCount: Int = 0
) {
    companion object {
        val Empty = NutritionSummary()
    }
}

// ─────────────────────────────────────
// MARK: - DietInsights
// ─────────────────────────────────────

data class DietInsights(
    val weeklyAverageCalories: Int,
    val currentStreak: Int,
    val topFoods: List<String>,
    val macroBalance: String
)

// ─────────────────────────────────────
// MARK: - Supabase DTO for diet_logs
// ─────────────────────────────────────

@Serializable
data class DietLogRecord(
    val id: String,
    @SerialName("health_profile_id") val healthProfileId: String,
    @SerialName("food_item_id") val foodItemId: String? = null,
    @SerialName("meal_type") val mealType: String,
    @SerialName("food_name") val foodName: String,
    val quantity: Double,
    @SerialName("serving_unit") val servingUnit: String,
    val calories: Double,
    @SerialName("protein_g") val proteinG: Double = 0.0,
    @SerialName("carbs_g") val carbsG: Double = 0.0,
    @SerialName("fat_g") val fatG: Double = 0.0,
    @SerialName("fiber_g") val fiberG: Double? = null,
    @SerialName("logged_at") val loggedAt: String,
    val notes: String? = null
) {
    companion object {
        fun from(entry: DietLogEntry, profileId: String) = DietLogRecord(
            id = entry.id,
            healthProfileId = profileId,
            foodItemId = entry.foodItemId,
            mealType = entry.mealType,
            foodName = entry.foodName,
            quantity = entry.quantity,
            servingUnit = entry.servingUnit,
            calories = entry.calories,
            proteinG = entry.proteinG,
            carbsG = entry.carbsG,
            fatG = entry.fatG,
            fiberG = entry.fiberG,
            loggedAt = entry.loggedAt,
            notes = entry.notes
        )
    }
}
