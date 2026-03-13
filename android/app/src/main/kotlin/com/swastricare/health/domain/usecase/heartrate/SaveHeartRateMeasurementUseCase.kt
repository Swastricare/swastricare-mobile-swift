package com.swastricare.health.domain.usecase.heartrate

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.heartrate.HeartRateMeasurement
import com.swastricare.health.domain.repository.HeartRateRepository
import javax.inject.Inject

/**
 * Use case: Save a heart rate measurement.
 * Validates and persists heart rate data to local storage and Health Connect.
 */
class SaveHeartRateMeasurementUseCase @Inject constructor(
    private val repository: HeartRateRepository
) {
    /**
     * Save a heart rate measurement.
     *
     * @param measurement The measurement to save
     * @param writeToHealthConnect Whether to also write to Health Connect
     * @return Result indicating success or failure
     */
    suspend operator fun invoke(
        measurement: HeartRateMeasurement,
        writeToHealthConnect: Boolean = true
    ): ResultWrapper<Unit> {
        // Validate measurement
        if (!measurement.isValid()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom(
                    "Invalid heart rate measurement: BPM must be between 30-220 and confidence >= 0.5"
                )
            )
        }

        // Save to local storage
        val saveResult = repository.addMeasurement(measurement)
        if (saveResult is ResultWrapper.Error) {
            return saveResult
        }

        // Optionally write to Health Connect
        if (writeToHealthConnect) {
            repository.writeToHealthConnect(measurement.bpm.toLong())
            // Note: We don't fail the operation if Health Connect write fails
        }

        return ResultWrapper.Success(Unit)
    }
}
