package com.swastricare.health.domain.usecase.diet

import com.swastricare.health.core.base.BaseUseCase
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.FoodEntry
import com.swastricare.health.domain.model.FoodItem
import com.swastricare.health.domain.model.MealType
import com.swastricare.health.domain.repository.DietRepository
import java.time.LocalDateTime
import java.util.UUID
import javax.inject.Inject

/**
 * Use case for adding a food entry to the diet log.
 * Handles business logic for creating entries from food items or custom inputs.
 */
class AddFoodEntryUseCase @Inject constructor(
    private val repository: DietRepository
) : BaseUseCase<AddFoodEntryUseCase.Params, Unit>() {

    override suspend fun execute(params: Params): ResultWrapper<Unit> {
        val entry = when (params) {
            is Params.FromFoodItem -> createEntryFromFoodItem(params)
            is Params.Custom -> createCustomEntry(params)
        }

        return repository.addFoodEntry(entry)
    }

    private fun createEntryFromFoodItem(params: Params.FromFoodItem): FoodEntry {
        val multiplier = params.quantity / params.foodItem.servingSize
        return FoodEntry(
            id = UUID.randomUUID().toString(),
            foodItemId = params.foodItem.id,
            mealType = params.mealType,
            foodName = params.foodItem.name,
            quantity = params.quantity,
            servingUnit = params.foodItem.servingUnit,
            nutritionInfo = params.foodItem.nutritionInfo.scale(multiplier),
            loggedAt = params.loggedAt ?: LocalDateTime.now(),
            notes = params.notes,
            synced = false
        )
    }

    private fun createCustomEntry(params: Params.Custom): FoodEntry {
        return FoodEntry(
            id = UUID.randomUUID().toString(),
            foodItemId = null,
            mealType = params.mealType,
            foodName = params.foodName,
            quantity = params.quantity,
            servingUnit = params.servingUnit,
            nutritionInfo = params.nutritionInfo,
            loggedAt = params.loggedAt ?: LocalDateTime.now(),
            notes = params.notes,
            synced = false
        )
    }

    sealed class Params {
        /**
         * Parameters for adding a food entry from an existing food item.
         */
        data class FromFoodItem(
            val foodItem: FoodItem,
            val quantity: Double,
            val mealType: MealType,
            val loggedAt: LocalDateTime? = null,
            val notes: String? = null
        ) : Params()

        /**
         * Parameters for adding a custom food entry.
         */
        data class Custom(
            val foodName: String,
            val mealType: MealType,
            val quantity: Double,
            val servingUnit: com.swastricare.health.domain.model.ServingUnit,
            val nutritionInfo: com.swastricare.health.domain.model.NutritionInfo,
            val loggedAt: LocalDateTime? = null,
            val notes: String? = null
        ) : Params()
    }
}
