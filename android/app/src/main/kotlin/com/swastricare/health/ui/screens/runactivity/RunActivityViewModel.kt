package com.swastricare.health.ui.screens.runactivity

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.models.*
import com.swastricare.health.data.repository.ProfileRepository
import com.swastricare.health.data.repository.RunActivityRepository
import com.swastricare.health.data.services.FitnessAnalyticsService
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

// ------------------------------------
// MARK: - Step Trend Enum
// ------------------------------------

enum class StepTrend {
    INCREASING,  // Up by >5%
    NEUTRAL,     // Within ±5%
    DECREASING   // Down by >5%
}

// ------------------------------------
// MARK: - UI State
// ------------------------------------

data class RunActivityUiState(
    val activities: List<RunActivity> = emptyList(),
    val statistics: ActivityStatistics = ActivityStatistics(),
    val timeRangeFilter: TimeRangeFilter = TimeRangeFilter.ONE_MONTH,
    val isLoading: Boolean = false,
    val error: String? = null,
    // Health Connect demo data
    val todaySteps: Int = 0,
    val todayDistance: Double = 0.0,
    val todayCalories: Int = 0,
    // Weekly comparison data
    val thisWeekSteps: Int = 0,
    val lastWeekSteps: Int = 0,
    val weeklyStepsDelta: Int = 0,
    val weeklyStepsTrend: StepTrend = StepTrend.NEUTRAL,
    // Fitness analytics
    val vo2Max: Double? = null,
    val vo2MaxSource: String = "",
    val weeklyTrainingLoad: Int = 0,
    val loadTrend: FitnessAnalyticsService.LoadTrend = FitnessAnalyticsService.LoadTrend.MAINTAINING
)

// ------------------------------------
// MARK: - ViewModel
// ------------------------------------

class RunActivityViewModel(
    private val repository: RunActivityRepository,
    private val profileRepository: ProfileRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(RunActivityUiState(isLoading = true))
    val uiState: StateFlow<RunActivityUiState> = _uiState.asStateFlow()

    private val healthConnectService: HealthConnectService = AppContainer.healthConnectService

    init {
        loadData()
    }

    fun loadData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)

            try {
                val activities = repository.loadLocalActivities()
                val stats = repository.calculateStatistics(activities, _uiState.value.timeRangeFilter)

                // Load real data from Health Connect
                val summary = healthConnectService.getTodaySummary()

                // Calculate weekly comparison
                val weeklyComparison = calculateWeeklyStepsComparison()

                _uiState.value = _uiState.value.copy(
                    activities = activities,
                    statistics = stats,
                    isLoading = false,
                    todaySteps = summary.steps,
                    todayDistance = summary.distanceKm,
                    todayCalories = summary.activeCalories,
                    thisWeekSteps = weeklyComparison.thisWeek,
                    lastWeekSteps = weeklyComparison.lastWeek,
                    weeklyStepsDelta = weeklyComparison.delta,
                    weeklyStepsTrend = weeklyComparison.trend
                )

                syncInBackground()

                // Load fitness analytics
                try {
                    val fitnessData = AppContainer.fitnessAnalyticsService.getFitnessData(activities)
                    _uiState.value = _uiState.value.copy(
                        vo2Max = fitnessData.vo2Max,
                        vo2MaxSource = fitnessData.vo2MaxSource,
                        weeklyTrainingLoad = fitnessData.weeklyTrainingLoad,
                        loadTrend = fitnessData.loadTrend
                    )
                } catch (_: Exception) { }
            } catch (_: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }

    fun setTimeRange(filter: TimeRangeFilter) {
        val activities = _uiState.value.activities
        val stats = repository.calculateStatistics(activities, filter)
        _uiState.value = _uiState.value.copy(
            timeRangeFilter = filter,
            statistics = stats
        )
    }

    fun deleteActivity(id: String) {
        viewModelScope.launch {
            repository.deleteLocalActivity(id)
            val activities = repository.loadLocalActivities()
            val stats = repository.calculateStatistics(activities, _uiState.value.timeRangeFilter)
            _uiState.value = _uiState.value.copy(
                activities = activities,
                statistics = stats
            )
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    private suspend fun calculateWeeklyStepsComparison(): WeeklyStepsComparison {
        return kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            try {
                val last14Days = healthConnectService.getLast14DaysSteps()

                val today = java.time.LocalDate.now()
                val thisWeekStart = today.minusDays(6)
                val lastWeekStart = today.minusDays(13)
                val lastWeekEnd = today.minusDays(7)

                // This week: last 7 days
                val thisWeekSteps = last14Days
                    .filter { it.date >= thisWeekStart }
                    .sumOf { it.steps.toInt() }

                // Last week: days 7-13 ago
                val lastWeekSteps = last14Days
                    .filter { it.date >= lastWeekStart && it.date <= lastWeekEnd }
                    .sumOf { it.steps.toInt() }

                val delta = thisWeekSteps - lastWeekSteps
                val trend = when {
                    lastWeekSteps == 0 -> StepTrend.NEUTRAL
                    delta > lastWeekSteps * 0.05 -> StepTrend.INCREASING
                    delta < -lastWeekSteps * 0.05 -> StepTrend.DECREASING
                    else -> StepTrend.NEUTRAL
                }

                WeeklyStepsComparison(
                    thisWeek = thisWeekSteps,
                    lastWeek = lastWeekSteps,
                    delta = delta,
                    trend = trend
                )
            } catch (e: Exception) {
                android.util.Log.w("RunActivityVM", "Weekly comparison failed: ${e.message}")
                WeeklyStepsComparison()
            }
        }
    }

    private data class WeeklyStepsComparison(
        val thisWeek: Int = 0,
        val lastWeek: Int = 0,
        val delta: Int = 0,
        val trend: StepTrend = StepTrend.NEUTRAL
    )

    private suspend fun syncInBackground() {
        try {
            val profileId = AppContainer.authRepository.currentUser?.id ?: return
            val unsynced = _uiState.value.activities.filter { !it.synced }
            if (unsynced.isNotEmpty()) {
                repository.syncActivitiesToCloud(unsynced, profileId)
            }
        } catch (e: Exception) {
            android.util.Log.w("RunActivityVM", "Sync failed: ${e.message}")
        }
    }
}
