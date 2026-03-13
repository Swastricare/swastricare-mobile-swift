package com.swastricare.health.domain.usecase.runactivity

import com.swastricare.health.domain.model.ActivityType
import com.swastricare.health.domain.model.WorkoutRecoveryState
import com.swastricare.health.domain.repository.RunActivityRepository
import javax.inject.Inject

/**
 * Use case for starting a new workout session.
 *
 * Responsibilities:
 * - Initialize workout recovery state
 * - Persist state for crash recovery
 * - Validate activity type
 *
 * @param repository RunActivity repository
 */
class StartWorkoutUseCase @Inject constructor(
    private val repository: RunActivityRepository
) {

    /**
     * Start a new workout session.
     *
     * @param activityType Type of activity to start
     * @return Result with recovery state or error
     */
    suspend operator fun invoke(activityType: ActivityType): Result<WorkoutRecoveryState> {
        return try {
            val state = WorkoutRecoveryState(
                activityType = activityType,
                startTimeMs = System.currentTimeMillis(),
                elapsedSeconds = 0,
                distanceMeters = 0.0,
                caloriesBurned = 0,
                isActive = true
            )

            repository.saveWorkoutState(state)
            Result.success(state)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
