package com.swastricare.health.domain.usecase.diet

import com.swastricare.health.core.base.BaseUseCase
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.DietGoal
import com.swastricare.health.domain.repository.DietRepository
import javax.inject.Inject

/**
 * Use case for updating diet goals.
 */
class UpdateDietGoalsUseCase @Inject constructor(
    private val repository: DietRepository
) : BaseUseCase<UpdateDietGoalsUseCase.Params, Unit>() {

    override suspend fun execute(params: Params): ResultWrapper<Unit> {
        return repository.updateDietGoals(params.goals)
    }

    data class Params(
        val goals: DietGoal
    )
}
