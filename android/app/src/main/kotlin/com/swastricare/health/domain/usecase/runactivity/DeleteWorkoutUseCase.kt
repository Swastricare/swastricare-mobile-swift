package com.swastricare.health.domain.usecase.runactivity

import com.swastricare.health.domain.repository.RunActivityRepository
import javax.inject.Inject

/**
 * Use case for deleting a workout session.
 *
 * Responsibilities:
 * - Delete workout from local storage
 * - Validate deletion request
 *
 * @param repository RunActivity repository
 */
class DeleteWorkoutUseCase @Inject constructor(
    private val repository: RunActivityRepository
) {

    /**
     * Delete a workout session by ID.
     *
     * @param workoutId ID of the workout to delete
     * @return Result indicating success or failure
     */
    suspend operator fun invoke(workoutId: String): Result<Unit> {
        return try {
            if (workoutId.isBlank()) {
                return Result.failure(IllegalArgumentException("Workout ID cannot be blank"))
            }

            repository.deleteLocalActivity(workoutId)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
