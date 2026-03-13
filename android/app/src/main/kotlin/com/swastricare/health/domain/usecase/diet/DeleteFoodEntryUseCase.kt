package com.swastricare.health.domain.usecase.diet

import com.swastricare.health.core.base.BaseUseCase
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.DietRepository
import javax.inject.Inject

/**
 * Use case for deleting a food entry from the diet log.
 */
class DeleteFoodEntryUseCase @Inject constructor(
    private val repository: DietRepository
) : BaseUseCase<DeleteFoodEntryUseCase.Params, Unit>() {

    override suspend fun execute(params: Params): ResultWrapper<Unit> {
        return repository.deleteFoodEntry(params.entryId)
    }

    data class Params(
        val entryId: String
    )
}
