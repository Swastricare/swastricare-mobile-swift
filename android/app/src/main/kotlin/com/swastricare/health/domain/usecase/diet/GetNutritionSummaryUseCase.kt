package com.swastricare.health.domain.usecase.diet

import com.swastricare.health.core.base.BaseUseCase
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.NutritionSummary
import com.swastricare.health.domain.repository.DietRepository
import java.time.LocalDate
import javax.inject.Inject

/**
 * Use case for calculating nutrition summary for a specific date.
 */
class GetNutritionSummaryUseCase @Inject constructor(
    private val repository: DietRepository
) : BaseUseCase<GetNutritionSummaryUseCase.Params, NutritionSummary>() {

    override suspend fun execute(params: Params): ResultWrapper<NutritionSummary> {
        return repository.getFoodEntriesForDate(params.date).map { entries ->
            NutritionSummary.fromEntries(entries)
        }
    }

    data class Params(
        val date: LocalDate = LocalDate.now()
    )
}
