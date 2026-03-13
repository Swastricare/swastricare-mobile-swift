package com.swastricare.health.domain.usecase.runactivity

import com.swastricare.health.domain.model.WorkoutRecoveryState
import com.swastricare.health.domain.repository.RunActivityRepository
import javax.inject.Inject

/**
 * Use case for recovering a crashed workout session.
 *
 * Responsibilities:
 * - Check for abandoned workout state
 * - Validate recovery state
 * - Provide options to resume or discard
 *
 * @param repository RunActivity repository
 */
class RecoverWorkoutUseCase @Inject constructor(
    private val repository: RunActivityRepository
) {

    /**
     * Check if there's a recoverable workout session.
     *
     * @return Workout recovery state if available, null otherwise
     */
    suspend operator fun invoke(): WorkoutRecoveryState? {
        return try {
            val state = repository.loadWorkoutState()

            // Only return state if it's active and not too old (e.g., within 24 hours)
            if (state?.isActive == true) {
                val ageMillis = System.currentTimeMillis() - state.startTimeMs
                val maxAgeMillis = 24 * 60 * 60 * 1000 // 24 hours

                if (ageMillis < maxAgeMillis) {
                    state
                } else {
                    // State is too old, clear it
                    repository.clearWorkoutState()
                    null
                }
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Discard a recovered workout session.
     */
    suspend fun discardRecovery(): Result<Unit> {
        return try {
            repository.clearWorkoutState()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
