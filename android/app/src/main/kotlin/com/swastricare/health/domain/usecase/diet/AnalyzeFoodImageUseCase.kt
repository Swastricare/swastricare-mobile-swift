package com.swastricare.health.domain.usecase.diet

import com.swastricare.health.core.base.BaseUseCase
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.AnalyzedFood
import com.swastricare.health.domain.repository.DietRepository
import javax.inject.Inject

/**
 * Use case for analyzing food images using AI.
 * Delegates to the repository which handles AI service calls.
 */
class AnalyzeFoodImageUseCase @Inject constructor(
    private val repository: DietRepository
) : BaseUseCase<AnalyzeFoodImageUseCase.Params, AnalyzedFood>() {

    override suspend fun execute(params: Params): ResultWrapper<AnalyzedFood> {
        return repository.analyzeFoodImage(params.imageBase64)
    }

    data class Params(
        val imageBase64: String
    )
}
