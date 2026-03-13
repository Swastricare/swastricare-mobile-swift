package com.swastricare.health.domain.usecase.diet

import com.swastricare.health.core.base.BaseUseCase
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.FoodItem
import com.swastricare.health.domain.repository.DietRepository
import javax.inject.Inject

/**
 * Use case for searching food items.
 * Searches in cached food items for fast response.
 */
class SearchFoodUseCase @Inject constructor(
    private val repository: DietRepository
) : BaseUseCase<SearchFoodUseCase.Params, List<FoodItem>>() {

    override suspend fun execute(params: Params): ResultWrapper<List<FoodItem>> {
        if (params.query.isBlank()) {
            return ResultWrapper.Success(emptyList())
        }

        return repository.searchFoodItems(params.query)
    }

    data class Params(
        val query: String
    )
}
