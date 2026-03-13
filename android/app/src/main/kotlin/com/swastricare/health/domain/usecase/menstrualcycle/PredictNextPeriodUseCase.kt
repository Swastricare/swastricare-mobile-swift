package com.swastricare.health.domain.usecase.menstrualcycle

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.menstrualcycle.CyclePrediction
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import javax.inject.Inject

/**
 * Use case for predicting the next menstrual period.
 * Uses cycle history and user settings to calculate predictions.
 */
class PredictNextPeriodUseCase @Inject constructor(
    private val repository: MenstrualCycleRepository
) {
    /**
     * Calculates prediction for next period, ovulation, and fertile window.
     * Returns null if insufficient data is available for prediction.
     */
    suspend operator fun invoke(): ResultWrapper<CyclePrediction?> {
        return repository.getPrediction()
    }
}
