package com.swastricare.health.domain.usecase.heartrate

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.heartrate.HeartRateMeasurement
import com.swastricare.health.domain.repository.HeartRateRepository
import java.time.LocalDate
import javax.inject.Inject

/**
 * Use case: Get heart rate measurement history.
 * Retrieves historical heart rate data from local storage.
 */
class GetHeartRateHistoryUseCase @Inject constructor(
    private val repository: HeartRateRepository
) {
    /**
     * Get all heart rate measurements from local storage.
     *
     * @return List of heart rate measurements
     */
    suspend operator fun invoke(): ResultWrapper<List<HeartRateMeasurement>> {
        return try {
            val measurements = repository.loadLocalMeasurements()
            ResultWrapper.Success(measurements)
        } catch (e: Exception) {
            ResultWrapper.Error(
                com.swastricare.health.core.result.AppException.UnknownException(
                    "Failed to load heart rate history: ${e.message}",
                    e
                )
            )
        }
    }

    /**
     * Get heart rate measurements for a specific date.
     *
     * @param date The date to filter by
     * @return List of measurements for that date
     */
    suspend fun forDate(date: LocalDate): ResultWrapper<List<HeartRateMeasurement>> {
        return try {
            val measurements = repository.loadMeasurementsForDate(date)
            ResultWrapper.Success(measurements)
        } catch (e: Exception) {
            ResultWrapper.Error(
                com.swastricare.health.core.result.AppException.UnknownException(
                    "Failed to load heart rate history for date: ${e.message}",
                    e
                )
            )
        }
    }

    /**
     * Get the most recent heart rate measurement.
     *
     * @return The last measurement, or null if none exists
     */
    suspend fun getLastMeasurement(): HeartRateMeasurement? {
        return repository.getLastMeasurement()
    }
}
