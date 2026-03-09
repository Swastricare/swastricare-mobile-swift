package com.swasthicare.mobile.ui.screens.runactivity

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.data.repository.ProfileRepository
import com.swasthicare.mobile.data.repository.RunActivityRepository
import com.swasthicare.mobile.data.services.FitnessAnalyticsService
import com.swasthicare.mobile.data.services.HealthConnectService
import com.swasthicare.mobile.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

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

                _uiState.value = _uiState.value.copy(
                    activities = activities,
                    statistics = stats,
                    isLoading = false,
                    todaySteps = summary.steps,
                    todayDistance = summary.distanceKm,
                    todayCalories = summary.activeCalories
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
