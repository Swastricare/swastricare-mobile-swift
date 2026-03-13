package com.swastricare.health.presentation.feature.runactivity

import com.swastricare.health.data.services.FitnessAnalyticsService
import com.swastricare.health.domain.model.TimeRangeFilter
import com.swastricare.health.domain.model.WorkoutSession
import com.swastricare.health.domain.model.WorkoutStats

/**
 * UI state for the Run Activity screen.
 * Represents all data needed to render the UI.
 *
 * Following Clean Architecture principles:
 * - Contains only presentation-layer concerns
 * - Uses domain models (not DTOs)
 * - Immutable data class for predictable state updates
 */
data class RunActivityUiState(
    // Core workout data
    val activities: List<WorkoutSession> = emptyList(),
    val statistics: WorkoutStats = WorkoutStats(),
    val timeRangeFilter: TimeRangeFilter = TimeRangeFilter.ONE_MONTH,

    // Loading and error states
    val isLoading: Boolean = false,
    val error: String? = null,

    // Health Connect data
    val todaySteps: Int = 0,
    val todayDistance: Double = 0.0,
    val todayCalories: Int = 0,

    // Fitness analytics
    val vo2Max: Double? = null,
    val vo2MaxSource: String = "",
    val weeklyTrainingLoad: Int = 0,
    val loadTrend: FitnessAnalyticsService.LoadTrend = FitnessAnalyticsService.LoadTrend.MAINTAINING
)

/**
 * UI events for the Run Activity screen.
 * Represents user actions and system events.
 */
sealed class RunActivityEvent {
    data object LoadData : RunActivityEvent()
    data class SetTimeRange(val filter: TimeRangeFilter) : RunActivityEvent()
    data class DeleteActivity(val id: String) : RunActivityEvent()
    data object ClearError : RunActivityEvent()
    data object SyncWithCloud : RunActivityEvent()
}
