package com.swastricare.health.domain.model

import java.time.LocalDate
import java.time.LocalDateTime

// ─────────────────────────────────────
// MARK: - Domain Models (Business Logic Layer)
// ─────────────────────────────────────

/**
 * Domain model for a food entry in the diet log.
 * This is the business logic representation, independent of data sources.
 */
data class FoodEntry(
    val id: String,
    val foodItemId: String? = null,
    val mealType: MealType,
    val foodName: String,
    val quantity: Double,
    val servingUnit: ServingUnit,
    val nutritionInfo: NutritionInfo,
    val loggedAt: LocalDateTime,
    val notes: String? = null,
    val synced: Boolean = false
) {
    init {
        require(foodName.isNotBlank()) { "Food name cannot be blank" }
        require(quantity > 0) { "Quantity must be positive" }
    }
}

/**
 * Domain model for nutrition information.
 * All values are validated to be non-negative.
 */
data class NutritionInfo(
    val calories: Double,
    val proteinG: Double,
    val carbsG: Double,
    val fatG: Double,
    val fiberG: Double = 0.0
) {
    init {
        require(calories >= 0) { "Calories cannot be negative" }
        require(proteinG >= 0) { "Protein cannot be negative" }
        require(carbsG >= 0) { "Carbs cannot be negative" }
        require(fatG >= 0) { "Fat cannot be negative" }
        require(fiberG >= 0) { "Fiber cannot be negative" }
    }

    val caloriesFromProtein: Double get() = proteinG * 4.0
    val caloriesFromCarbs: Double get() = carbsG * 4.0
    val caloriesFromFat: Double get() = fatG * 9.0
    val totalCalculatedCalories: Double get() = caloriesFromProtein + caloriesFromCarbs + caloriesFromFat

    fun scale(multiplier: Double): NutritionInfo = copy(
        calories = calories * multiplier,
        proteinG = proteinG * multiplier,
        carbsG = carbsG * multiplier,
        fatG = fatG * multiplier,
        fiberG = fiberG * multiplier
    )
}

/**
 * Domain model for a food item in the database.
 */
data class FoodItem(
    val id: String,
    val name: String,
    val brand: String? = null,
    val servingSize: Double,
    val servingUnit: ServingUnit,
    val nutritionInfo: NutritionInfo,
    val category: FoodCategory,
    val isVegetarian: Boolean = true,
    val isVegan: Boolean = false
) {
    init {
        require(name.isNotBlank()) { "Food name cannot be blank" }
        require(servingSize > 0) { "Serving size must be positive" }
    }

    val displayName: String get() = if (brand != null) "$name ($brand)" else name
    val displayServingSize: String get() = "${servingSize.toInt()} ${servingUnit.displayName}"
}

/**
 * Domain model for daily diet goals.
 */
data class DietGoal(
    val dailyCalories: Int,
    val proteinPercent: Int,
    val carbsPercent: Int,
    val fatPercent: Int,
    val waterGoalMl: Int = 2500,
    val mealRemindersEnabled: Boolean = true
) {
    init {
        require(dailyCalories > 0) { "Daily calories must be positive" }
        require(proteinPercent + carbsPercent + fatPercent == 100) {
            "Macro percentages must sum to 100"
        }
    }

    val proteinGrams: Int get() = (dailyCalories * proteinPercent / 100.0 / 4.0).toInt()
    val carbsGrams: Int get() = (dailyCalories * carbsPercent / 100.0 / 4.0).toInt()
    val fatGrams: Int get() = (dailyCalories * fatPercent / 100.0 / 9.0).toInt()

    companion object {
        val Default = DietGoal(
            dailyCalories = 2000,
            proteinPercent = 25,
            carbsPercent = 50,
            fatPercent = 25,
            waterGoalMl = 2500,
            mealRemindersEnabled = true
        )
    }
}

/**
 * Domain model for nutrition summary of a day.
 */
data class NutritionSummary(
    val totalCalories: Double,
    val totalProteinG: Double,
    val totalCarbsG: Double,
    val totalFatG: Double,
    val totalFiberG: Double,
    val mealCount: Int
) {
    val proteinCalories: Double get() = totalProteinG * 4.0
    val carbsCalories: Double get() = totalCarbsG * 4.0
    val fatCalories: Double get() = totalFatG * 9.0

    fun getProgress(goals: DietGoal): MacroProgress = MacroProgress(
        calorieProgress = (totalCalories / goals.dailyCalories).toFloat().coerceIn(0f, 2f),
        proteinProgress = (totalProteinG / goals.proteinGrams).toFloat().coerceIn(0f, 2f),
        carbsProgress = (totalCarbsG / goals.carbsGrams).toFloat().coerceIn(0f, 2f),
        fatProgress = (totalFatG / goals.fatGrams).toFloat().coerceIn(0f, 2f)
    )

    companion object {
        val Empty = NutritionSummary(
            totalCalories = 0.0,
            totalProteinG = 0.0,
            totalCarbsG = 0.0,
            totalFatG = 0.0,
            totalFiberG = 0.0,
            mealCount = 0
        )

        fun fromEntries(entries: List<FoodEntry>): NutritionSummary {
            return NutritionSummary(
                totalCalories = entries.sumOf { it.nutritionInfo.calories },
                totalProteinG = entries.sumOf { it.nutritionInfo.proteinG },
                totalCarbsG = entries.sumOf { it.nutritionInfo.carbsG },
                totalFatG = entries.sumOf { it.nutritionInfo.fatG },
                totalFiberG = entries.sumOf { it.nutritionInfo.fiberG },
                mealCount = entries.size
            )
        }
    }
}

/**
 * Macro progress for UI display.
 */
data class MacroProgress(
    val calorieProgress: Float,
    val proteinProgress: Float,
    val carbsProgress: Float,
    val fatProgress: Float
)

/**
 * Domain model for diet insights.
 */
data class DietInsights(
    val weeklyAverageCalories: Int,
    val currentStreak: Int,
    val topFoods: List<String>,
    val macroBalancePercent: MacroBalance
)

/**
 * Macro balance percentages.
 */
data class MacroBalance(
    val proteinPercent: Int,
    val carbsPercent: Int,
    val fatPercent: Int
) {
    val displayText: String get() = "P${proteinPercent}% · C${carbsPercent}% · F${fatPercent}%"
}

/**
 * Result of food image analysis.
 */
data class AnalyzedFood(
    val name: String,
    val servingSize: Double,
    val servingUnit: ServingUnit,
    val nutritionInfo: NutritionInfo,
    val category: FoodCategory
) {
    init {
        require(name.isNotBlank()) { "Food name cannot be blank" }
        require(servingSize > 0) { "Serving size must be positive" }
    }

    fun toFoodItem(): FoodItem = FoodItem(
        id = java.util.UUID.randomUUID().toString(),
        name = name,
        servingSize = servingSize,
        servingUnit = servingUnit,
        nutritionInfo = nutritionInfo,
        category = category
    )
}

// ─────────────────────────────────────
// MARK: - Enums
// ─────────────────────────────────────

enum class MealType(val displayName: String, val typicalTime: String) {
    BREAKFAST("Breakfast", "7:00 AM – 9:00 AM"),
    MORNING_SNACK("Morning Snack", "10:00 AM – 11:00 AM"),
    LUNCH("Lunch", "12:00 PM – 2:00 PM"),
    EVENING_SNACK("Evening Snack", "4:00 PM – 5:00 PM"),
    DINNER("Dinner", "7:00 PM – 9:00 PM"),
    LATE_NIGHT("Late Night", "10:00 PM – 11:00 PM")
}

enum class ServingUnit(val displayName: String) {
    G("g"),
    ML("ml"),
    PIECE("piece"),
    CUP("cup"),
    TBSP("tbsp"),
    TSP("tsp"),
    OZ("oz"),
    BOWL("bowl"),
    PLATE("plate")
}

enum class FoodCategory(val displayName: String, val icon: String) {
    FRUITS("Fruits", "🍎"),
    VEGETABLES("Vegetables", "🥗"),
    GRAINS("Grains", "🌾"),
    PROTEIN("Protein", "🍗"),
    DAIRY("Dairy", "🥛"),
    BEVERAGES("Beverages", "☕"),
    SNACKS("Snacks", "🍿"),
    SWEETS("Sweets", "🍰"),
    OTHER("Other", "🍽️")
}
