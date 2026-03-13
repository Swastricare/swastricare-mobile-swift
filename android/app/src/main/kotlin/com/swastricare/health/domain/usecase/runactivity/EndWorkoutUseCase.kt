package com.swastricare.health.domain.usecase.runactivity

import com.swastricare.health.domain.model.RoutePoint
import com.swastricare.health.domain.model.WorkoutSession
import com.swastricare.health.domain.model.WorkoutSplit
import com.swastricare.health.domain.repository.RunActivityRepository
import java.time.LocalDateTime
import java.util.UUID
import javax.inject.Inject

/**
 * Use case for ending a workout session and saving it.
 *
 * Responsibilities:
 * - Finalize workout metrics
 * - Create workout session entity
 * - Save to local storage
 * - Clear recovery state
 *
 * @param repository RunActivity repository
 */
class EndWorkoutUseCase @Inject constructor(
    private val repository: RunActivityRepository
) {

    /**
     * End the current workout and save it.
     *
     * @param userId User ID
     * @param activityType Type of activity
     * @param startTime When the workout started
     * @param durationSeconds Total duration
     * @param distanceMeters Total distance
     * @param avgPaceSecondsPerKm Average pace
     * @param caloriesBurned Calories burned
     * @param avgHeartRate Average heart rate (optional)
     * @param routePoints List of GPS points
     * @param splits List of kilometer splits
     * @return Result with saved workout session or error
     */
    suspend operator fun invoke(
        userId: String,
        activityType: com.swastricare.health.domain.model.ActivityType,
        startTime: LocalDateTime,
        durationSeconds: Long,
        distanceMeters: Double,
        avgPaceSecondsPerKm: Long,
        caloriesBurned: Int,
        avgHeartRate: Int?,
        routePoints: List<RoutePoint>,
        splits: List<WorkoutSplit>
    ): Result<WorkoutSession> {
        return try {
            // Validate inputs
            if (durationSeconds <= 0) {
                return Result.failure(IllegalArgumentException("Duration must be positive"))
            }
            if (distanceMeters < 0) {
                return Result.failure(IllegalArgumentException("Distance cannot be negative"))
            }

            // Create workout session
            val session = WorkoutSession(
                id = UUID.randomUUID().toString(),
                userId = userId,
                activityType = activityType,
                startTime = startTime,
                endTime = LocalDateTime.now(),
                distanceMeters = distanceMeters,
                durationSeconds = durationSeconds,
                avgPaceSecondsPerKm = avgPaceSecondsPerKm,
                caloriesBurned = caloriesBurned,
                avgHeartRate = avgHeartRate,
                routePoints = routePoints,
                splits = splits,
                synced = false
            )

            // Save to local storage
            repository.addLocalActivity(session)

            // Clear recovery state
            repository.clearWorkoutState()

            Result.success(session)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
