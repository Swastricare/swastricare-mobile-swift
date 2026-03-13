package com.swastricare.health.domain.usecase.runactivity

import com.swastricare.health.domain.model.RoutePoint
import com.swastricare.health.domain.model.WorkoutRecoveryState
import com.swastricare.health.domain.repository.RunActivityRepository
import javax.inject.Inject

/**
 * Use case for recording GPS route points during a workout.
 *
 * Responsibilities:
 * - Validate route point data
 * - Update workout recovery state with distance
 * - Persist state for crash recovery
 *
 * @param repository RunActivity repository
 */
class RecordRoutePointUseCase @Inject constructor(
    private val repository: RunActivityRepository
) {

    /**
     * Record a new route point and update workout state.
     *
     * @param point GPS point to record
     * @param currentState Current workout state
     * @param distanceMeters Updated total distance
     * @param elapsedSeconds Updated elapsed time
     * @param calories Updated calories burned
     * @return Updated recovery state
     */
    suspend operator fun invoke(
        point: RoutePoint,
        currentState: WorkoutRecoveryState,
        distanceMeters: Double,
        elapsedSeconds: Long,
        calories: Int
    ): Result<WorkoutRecoveryState> {
        return try {
            // Validate point
            if (!isValidCoordinate(point.latitude, point.longitude)) {
                return Result.failure(IllegalArgumentException("Invalid GPS coordinates"))
            }

            // Update state with new metrics
            val updatedState = currentState.copy(
                distanceMeters = distanceMeters,
                elapsedSeconds = elapsedSeconds,
                caloriesBurned = calories
            )

            // Persist for crash recovery
            repository.saveWorkoutState(updatedState)

            Result.success(updatedState)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private fun isValidCoordinate(latitude: Double, longitude: Double): Boolean {
        return latitude in -90.0..90.0 && longitude in -180.0..180.0
    }
}
