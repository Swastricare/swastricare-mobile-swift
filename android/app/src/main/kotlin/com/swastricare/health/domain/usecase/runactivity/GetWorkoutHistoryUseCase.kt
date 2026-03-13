package com.swastricare.health.domain.usecase.runactivity

import com.swastricare.health.domain.model.TimeRangeFilter
import com.swastricare.health.domain.model.WorkoutSession
import com.swastricare.health.domain.model.WorkoutStats
import com.swastricare.health.domain.repository.RunActivityRepository
import javax.inject.Inject

/**
 * Use case for retrieving workout history and statistics.
 *
 * Responsibilities:
 * - Load workout sessions from local storage
 * - Calculate statistics for specified time range
 * - Sync with cloud in background
 *
 * @param repository RunActivity repository
 */
class GetWorkoutHistoryUseCase @Inject constructor(
    private val repository: RunActivityRepository
) {

    /**
     * Get workout history with calculated statistics.
     *
     * @param timeRange Time range filter for statistics
     * @return Result with history data or error
     */
    suspend operator fun invoke(timeRange: TimeRangeFilter): Result<WorkoutHistoryData> {
        return try {
            val activities = repository.loadLocalActivities()
            val statistics = repository.calculateStatistics(activities, timeRange)

            Result.success(
                WorkoutHistoryData(
                    activities = activities,
                    statistics = statistics
                )
            )
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Data class containing workout history and statistics.
     */
    data class WorkoutHistoryData(
        val activities: List<WorkoutSession>,
        val statistics: WorkoutStats
    )
}
