package com.swastricare.health.data.mapper

import com.swastricare.health.data.remote.dto.diet.AnalyzedFoodDto
import com.swastricare.health.data.remote.dto.diet.DietGoalsDto
import com.swastricare.health.data.remote.dto.diet.DietLogDto
import com.swastricare.health.data.remote.dto.diet.FoodItemDto
import com.swastricare.health.data.remote.dto.diet.LocalFoodEntryDto
import com.swastricare.health.domain.model.AnalyzedFood
import com.swastricare.health.domain.model.DietGoal
import com.swastricare.health.domain.model.FoodCategory
import com.swastricare.health.domain.model.FoodEntry
import com.swastricare.health.domain.model.FoodItem
import com.swastricare.health.domain.model.MealType
import com.swastricare.health.domain.model.NutritionInfo
import com.swastricare.health.domain.model.ServingUnit
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Mapper for Diet feature.
 * Converts between DTOs (data layer) and domain models (business logic layer).
 */
object DietMapper {

    private val isoFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")

    // ─────────────────────────────────────
    // MARK: - FoodItem Mapping
    // ─────────────────────────────────────

    fun FoodItemDto.toDomain(): FoodItem {
        return FoodItem(
            id = id,
            name = name,
            brand = brand,
            servingSize = servingSize.coerceAtLeast(0.1),
            servingUnit = servingUnit.toServingUnit(),
            nutritionInfo = NutritionInfo(
                calories = calories.coerceAtLeast(0.0),
                proteinG = proteinG.coerceAtLeast(0.0),
                carbsG = carbsG.coerceAtLeast(0.0),
                fatG = fatG.coerceAtLeast(0.0),
                fiberG = fiberG?.coerceAtLeast(0.0) ?: 0.0
            ),
            category = category.toFoodCategory(),
            isVegetarian = isVegetarian,
            isVegan = isVegan
        )
    }

    // ─────────────────────────────────────
    // MARK: - FoodEntry Mapping
    // ─────────────────────────────────────

    fun LocalFoodEntryDto.toDomain(): FoodEntry {
        return FoodEntry(
            id = id,
            foodItemId = foodItemId,
            mealType = mealType.toMealType(),
            foodName = foodName,
            quantity = quantity.coerceAtLeast(0.0),
            servingUnit = servingUnit.toServingUnit(),
            nutritionInfo = NutritionInfo(
                calories = calories.coerceAtLeast(0.0),
                proteinG = proteinG.coerceAtLeast(0.0),
                carbsG = carbsG.coerceAtLeast(0.0),
                fatG = fatG.coerceAtLeast(0.0),
                fiberG = fiberG?.coerceAtLeast(0.0) ?: 0.0
            ),
            loggedAt = LocalDateTime.parse(loggedAt, isoFormatter),
            notes = notes,
            synced = synced
        )
    }

    fun FoodEntry.toLocalDto(): LocalFoodEntryDto {
        return LocalFoodEntryDto(
            id = id,
            foodItemId = foodItemId,
            mealType = mealType.toDbValue(),
            foodName = foodName,
            quantity = quantity,
            servingUnit = servingUnit.toDbValue(),
            calories = nutritionInfo.calories,
            proteinG = nutritionInfo.proteinG,
            carbsG = nutritionInfo.carbsG,
            fatG = nutritionInfo.fatG,
            fiberG = nutritionInfo.fiberG,
            loggedAt = loggedAt.format(isoFormatter),
            notes = notes,
            synced = synced
        )
    }

    fun FoodEntry.toRemoteDto(healthProfileId: String): DietLogDto {
        return DietLogDto(
            id = id,
            healthProfileId = healthProfileId,
            foodItemId = foodItemId,
            mealType = mealType.toDbValue(),
            foodName = foodName,
            quantity = quantity,
            servingUnit = servingUnit.toDbValue(),
            calories = nutritionInfo.calories,
            proteinG = nutritionInfo.proteinG,
            carbsG = nutritionInfo.carbsG,
            fatG = nutritionInfo.fatG,
            fiberG = nutritionInfo.fiberG,
            loggedAt = loggedAt.format(isoFormatter),
            notes = notes
        )
    }

    // ─────────────────────────────────────
    // MARK: - DietGoal Mapping
    // ─────────────────────────────────────

    fun DietGoalsDto.toDomain(): DietGoal {
        return DietGoal(
            dailyCalories = dailyCalories.coerceAtLeast(1000),
            proteinPercent = proteinPercent.coerceIn(10, 50),
            carbsPercent = carbsPercent.coerceIn(20, 70),
            fatPercent = fatPercent.coerceIn(10, 50),
            waterGoalMl = waterGoalMl.coerceAtLeast(500),
            mealRemindersEnabled = mealRemindersEnabled
        )
    }

    fun DietGoal.toDto(): DietGoalsDto {
        return DietGoalsDto(
            dailyCalories = dailyCalories,
            proteinPercent = proteinPercent,
            carbsPercent = carbsPercent,
            fatPercent = fatPercent,
            waterGoalMl = waterGoalMl,
            mealRemindersEnabled = mealRemindersEnabled
        )
    }

    // ─────────────────────────────────────
    // MARK: - AnalyzedFood Mapping
    // ─────────────────────────────────────

    fun AnalyzedFoodDto.toDomain(): AnalyzedFood {
        return AnalyzedFood(
            name = name,
            servingSize = servingSize.coerceAtLeast(0.1),
            servingUnit = servingUnit.toServingUnit(),
            nutritionInfo = NutritionInfo(
                calories = calories.coerceAtLeast(0.0),
                proteinG = proteinG.coerceAtLeast(0.0),
                carbsG = carbsG.coerceAtLeast(0.0),
                fatG = fatG.coerceAtLeast(0.0),
                fiberG = fiberG.coerceAtLeast(0.0)
            ),
            category = category.toFoodCategory()
        )
    }

    // ─────────────────────────────────────
    // MARK: - Enum Conversion Helpers
    // ─────────────────────────────────────

    private fun String.toMealType(): MealType = when (this.lowercase()) {
        "breakfast" -> MealType.BREAKFAST
        "morning_snack" -> MealType.MORNING_SNACK
        "lunch" -> MealType.LUNCH
        "evening_snack" -> MealType.EVENING_SNACK
        "dinner" -> MealType.DINNER
        "late_night" -> MealType.LATE_NIGHT
        else -> MealType.BREAKFAST
    }

    private fun MealType.toDbValue(): String = when (this) {
        MealType.BREAKFAST -> "breakfast"
        MealType.MORNING_SNACK -> "morning_snack"
        MealType.LUNCH -> "lunch"
        MealType.EVENING_SNACK -> "evening_snack"
        MealType.DINNER -> "dinner"
        MealType.LATE_NIGHT -> "late_night"
    }

    private fun String.toServingUnit(): ServingUnit = when (this.lowercase()) {
        "g" -> ServingUnit.G
        "ml" -> ServingUnit.ML
        "piece" -> ServingUnit.PIECE
        "cup" -> ServingUnit.CUP
        "tbsp" -> ServingUnit.TBSP
        "tsp" -> ServingUnit.TSP
        "oz" -> ServingUnit.OZ
        "bowl" -> ServingUnit.BOWL
        "plate" -> ServingUnit.PLATE
        else -> ServingUnit.G
    }

    private fun ServingUnit.toDbValue(): String = when (this) {
        ServingUnit.G -> "g"
        ServingUnit.ML -> "ml"
        ServingUnit.PIECE -> "piece"
        ServingUnit.CUP -> "cup"
        ServingUnit.TBSP -> "tbsp"
        ServingUnit.TSP -> "tsp"
        ServingUnit.OZ -> "oz"
        ServingUnit.BOWL -> "bowl"
        ServingUnit.PLATE -> "plate"
    }

    private fun String.toFoodCategory(): FoodCategory = when (this.lowercase()) {
        "fruits" -> FoodCategory.FRUITS
        "vegetables" -> FoodCategory.VEGETABLES
        "grains" -> FoodCategory.GRAINS
        "protein" -> FoodCategory.PROTEIN
        "dairy" -> FoodCategory.DAIRY
        "beverages" -> FoodCategory.BEVERAGES
        "snacks" -> FoodCategory.SNACKS
        "sweets" -> FoodCategory.SWEETS
        else -> FoodCategory.OTHER
    }
}
