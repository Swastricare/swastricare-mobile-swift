package com.swastricare.health.domain.usecase.diet

import com.swastricare.health.core.base.BaseUseCase
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.FoodEntry
import com.swastricare.health.domain.model.MealType
import com.swastricare.health.domain.repository.DietRepository
import java.time.LocalDate
import javax.inject.Inject

/**
 * Use case for getting food entries for a specific date.
 * Can optionally filter by meal type.
 */
class GetFoodEntriesUseCase @Inject constructor(
    private val repository: DietRepository
) : BaseUseCase<GetFoodEntriesUseCase.Params, List<FoodEntry>>() {

    override suspend fun execute(params: Params): ResultWrapper<List<FoodEntry>> {
        return repository.getFoodEntriesForDate(params.date).map { entries ->
            val filtered = if (params.mealType != null) {
                entries.filter { it.mealType == params.mealType }
            } else {
                entries
            }

            // Sort by logged time, newest first
            filtered.sortedByDescending { it.loggedAt }
        }
    }

    data class Params(
        val date: LocalDate = LocalDate.now(),
        val mealType: MealType? = null
    )
}
