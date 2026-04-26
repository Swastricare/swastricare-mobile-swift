package com.swastricare.health.data.models

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
    init {
        require(servingSize > 0) { "Serving size must be positive" }
    }

    val categoryEnum: FoodCategory get() = FoodCategory.fromDb(category)
    val servingUnitEnum: ServingUnit get() = ServingUnit.fromDb(servingUnit)
    val displayServingSize: String get() = "${servingSize.toInt()} ${servingUnitEnum.displayName}"
    val caloriesPerServing: String get() = "${validatedCalories.toInt()} cal"
    val macroSummary: String get() = "P: ${validatedProteinG.toInt()}g · C: ${validatedCarbsG.toInt()}g · F: ${validatedFatG.toInt()}g"

    // Validated nutrition values
    val validatedCalories: Double get() = calories.coerceAtLeast(0.0)
    val validatedProteinG: Double get() = proteinG.coerceAtLeast(0.0)
    val validatedCarbsG: Double get() = carbsG.coerceAtLeast(0.0)
    val validatedFatG: Double get() = fatG.coerceAtLeast(0.0)
    val validatedFiberG: Double get() = fiberG?.coerceAtLeast(0.0) ?: 0.0
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

    // Validated nutrition values
    val validatedCalories: Double get() = calories.coerceAtLeast(0.0)
    val validatedProteinG: Double get() = proteinG.coerceAtLeast(0.0)
    val validatedCarbsG: Double get() = carbsG.coerceAtLeast(0.0)
    val validatedFatG: Double get() = fatG.coerceAtLeast(0.0)
    val validatedFiberG: Double get() = fiberG?.coerceAtLeast(0.0) ?: 0.0
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

        /**
         * Creates a nutrition summary from diet log entries with validated values
         */
        fun fromEntries(entries: List<DietLogEntry>): NutritionSummary {
            return NutritionSummary(
                totalCalories = entries.sumOf { it.validatedCalories },
                totalProteinG = entries.sumOf { it.validatedProteinG },
                totalCarbsG = entries.sumOf { it.validatedCarbsG },
                totalFatG = entries.sumOf { it.validatedFatG },
                totalFiberG = entries.sumOf { it.validatedFiberG },
                mealCount = entries.size
            )
        }
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
            calories = entry.validatedCalories,
            proteinG = entry.validatedProteinG,
            carbsG = entry.validatedCarbsG,
            fatG = entry.validatedFatG,
            fiberG = entry.validatedFiberG,
            loggedAt = entry.loggedAt,
            notes = entry.notes
        )
    }
}

// ─────────────────────────────────────
// MARK: - Food Snap Result
// ─────────────────────────────────────

data class SnapFoodResult(
    val name: String,
    val calories: Double,
    val proteinG: Double,
    val carbsG: Double,
    val fatG: Double,
    val fiberG: Double = 0.0,
    val servingSize: Double = 1.0,
    val servingUnit: String = "piece",
    val category: String = "other"
) {
    init {
        require(servingSize > 0) { "Serving size must be positive" }
    }

    fun toFoodItem(): FoodItem = FoodItem(
        name = name,
        servingSize = servingSize,
        servingUnit = servingUnit,
        calories = calories.coerceAtLeast(0.0),
        proteinG = proteinG.coerceAtLeast(0.0),
        carbsG = carbsG.coerceAtLeast(0.0),
        fatG = fatG.coerceAtLeast(0.0),
        fiberG = fiberG.coerceAtLeast(0.0),
        category = category
    )
}

// ─────────────────────────────────────
// MARK: - Goal Type
// ─────────────────────────────────────

enum class GoalType(val dbValue: String, val displayName: String) {
    WEIGHT_LOSS("weight_loss", "Lose weight"),
    MAINTENANCE("maintenance", "Maintain weight"),
    WEIGHT_GAIN("weight_gain", "Gain weight"),
    MUSCLE_BUILDING("muscle_building", "Build muscle");

    companion object {
        fun fromDb(value: String): GoalType =
            entries.firstOrNull { it.dbValue == value } ?: MAINTENANCE
    }
}

// ─────────────────────────────────────
// MARK: - Calorie Calculator
// ─────────────────────────────────────

/**
 * Mifflin-St Jeor BMR + TDEE + macro calculator.
 * Ports iOS DietModels.swift:782-857 — same equations, same multipliers.
 */
object CalorieCalculator {

    /** Mifflin-St Jeor BMR. Gender accepts "male"/"female"; anything else falls to female (more conservative). */
    fun calculateBMR(weightKg: Double, heightCm: Int, age: Int, gender: String): Int {
        val weight = 10 * weightKg
        val height = 6.25 * heightCm
        val ageCalc = 5 * age
        val bmr = if (gender.lowercase() == "male") {
            weight + height - ageCalc + 5
        } else {
            weight + height - ageCalc - 161
        }
        return bmr.toInt()
    }

    /** TDEE = BMR × activity multiplier (uses ActivityLevel.multiplier from HydrationModels). */
    fun calculateTDEE(bmr: Int, activityLevel: ActivityLevel): Int =
        (bmr * activityLevel.multiplier).toInt()

    /** Goal-adjusted daily calorie target (deficit/surplus per goal). */
    fun calculateCalorieGoal(tdee: Int, goalType: GoalType): Int = when (goalType) {
        GoalType.WEIGHT_LOSS -> tdee - 500       // ~0.5 kg/wk loss
        GoalType.WEIGHT_GAIN -> tdee + 500       // ~0.5 kg/wk gain
        GoalType.MAINTENANCE -> tdee
        GoalType.MUSCLE_BUILDING -> tdee + 300   // small surplus
    }

    /** Macro target percentages (P/C/F) per goal. Returns Triple(proteinPct, carbsPct, fatPct). */
    fun macroPercentsFor(goalType: GoalType): Triple<Int, Int, Int> = when (goalType) {
        GoalType.WEIGHT_LOSS -> Triple(30, 40, 30)
        GoalType.WEIGHT_GAIN -> Triple(25, 50, 25)
        GoalType.MAINTENANCE -> Triple(25, 50, 25)
        GoalType.MUSCLE_BUILDING -> Triple(35, 45, 20)
    }

    /** Convenience: full pipeline weight/height/age/gender/activity/goal → DietGoals. */
    fun computeGoals(
        weightKg: Double,
        heightCm: Int,
        age: Int,
        gender: String,
        activityLevel: ActivityLevel,
        goalType: GoalType
    ): DietGoals {
        val bmr = calculateBMR(weightKg, heightCm, age, gender)
        val tdee = calculateTDEE(bmr, activityLevel)
        val cal = calculateCalorieGoal(tdee, goalType)
        val (p, c, f) = macroPercentsFor(goalType)
        return DietGoals(
            dailyCalories = cal,
            proteinPercent = p,
            carbsPercent = c,
            fatPercent = f
        )
    }

    /** Compute age in years from a YYYY-MM-DD birth-date string. Returns null if unparseable. */
    fun ageFromDateOfBirth(dob: String?): Int? {
        if (dob.isNullOrBlank()) return null
        return try {
            val birth = java.time.LocalDate.parse(dob.take(10))
            java.time.Period.between(birth, java.time.LocalDate.now()).years
        } catch (_: Exception) {
            null
        }
    }
}
