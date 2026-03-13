package com.swastricare.health.domain.usecase.heartrate

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.HeartRateRepository
import javax.inject.Inject

/**
 * Use case: Clear all heart rate measurement history.
 * Removes all stored heart rate data from local storage.
 */
class ClearHeartRateHistoryUseCase @Inject constructor(
    private val repository: HeartRateRepository
) {
    /**
     * Clear all heart rate measurements from local storage.
     *
     * @return Result indicating success or failure
     */
    suspend operator fun invoke(): ResultWrapper<Unit> {
        return repository.clearAllMeasurements()
    }
}
