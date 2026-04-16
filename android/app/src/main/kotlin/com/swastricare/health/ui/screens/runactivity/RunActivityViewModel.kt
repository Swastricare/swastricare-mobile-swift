package com.swastricare.health.ui.screens.runactivity

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.models.*
import java.time.LocalDate
import com.swastricare.health.data.repository.RunActivityRepository
import com.swastricare.health.data.repository.ProfileRepository
import com.swastricare.health.data.services.FitnessAnalyticsService
import com.swastricare.health.data.services.HealthConnectService
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

// ------------------------------------
// MARK: - UI State
// ------------------------------------

data class RunActivityUiState(
    val activities: List<RunActivity> = emptyList(),          // filtered for display
    val allActivities: List<RunActivity> = emptyList(),       // full list (used for re-filtering)
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

@HiltViewModel
class RunActivityViewModel @Inject constructor(
    private val repository: RunActivityRepository,
    private val profileRepository: ProfileRepository,
    private val healthConnectService: HealthConnectService,
    private val fitnessAnalyticsService: FitnessAnalyticsService,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(RunActivityUiState(isLoading = true))
    val uiState: StateFlow<RunActivityUiState> = _uiState.asStateFlow()

    init {
        loadData()
    }

    private fun filterActivities(all: List<RunActivity>, filter: TimeRangeFilter): List<RunActivity> {
        val cutoff = LocalDate.now().minusDays(filter.days.toLong()).atStartOfDay()
        return all.filter { it.startTime?.isAfter(cutoff) ?: true }
    }

    fun loadData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)

            try {
                // Local cache first — instant render after a successful sync.
                var allActivities = repository.loadLocalActivities()

                // Cloud restore: if the local cache is empty (e.g. right
                // after a reinstall) pull the user's activities from
                // Supabase so they don't appear to have been lost.
                if (allActivities.isEmpty()) {
                    val userId = supabaseClient.auth.currentUserOrNull()?.id
                    val healthProfileId = if (userId != null) {
                        runCatching { profileRepository.getHealthProfile(userId)?.id }
                            .getOrNull()
                    } else null
                    if (healthProfileId != null) {
                        val cloud = runCatching {
                            repository.fetchActivitiesFromCloud(healthProfileId)
                        }.getOrNull()
                        cloud?.getOrNull()?.takeIf { it.isNotEmpty() }?.let { fromCloud ->
                            repository.saveLocalActivities(fromCloud)
                            allActivities = fromCloud
                            android.util.Log.d(
                                "RunActivityVM",
                                "Restored ${fromCloud.size} activities from cloud"
                            )
                        }
                    }
                }

                val filter = _uiState.value.timeRangeFilter
                val filtered = filterActivities(allActivities, filter)
                val stats = repository.calculateStatistics(allActivities, filter)

                // Load real data from Health Connect
                val summary = healthConnectService.getTodaySummary()

                _uiState.value = _uiState.value.copy(
                    allActivities = allActivities,
                    activities = filtered,
                    statistics = stats,
                    isLoading = false,
                    todaySteps = summary.steps,
                    todayDistance = summary.distanceKm,
                    todayCalories = summary.activeCalories
                )

                syncInBackground()

                // Load fitness analytics
                try {
                    val fitnessData = fitnessAnalyticsService.getFitnessData(allActivities)
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
        val all = _uiState.value.allActivities
        val filtered = filterActivities(all, filter)
        val stats = repository.calculateStatistics(all, filter)
        _uiState.value = _uiState.value.copy(
            timeRangeFilter = filter,
            activities = filtered,
            statistics = stats
        )
    }

    fun deleteActivity(id: String) {
        viewModelScope.launch {
            repository.deleteLocalActivity(id)
            val all = repository.loadLocalActivities()
            val filter = _uiState.value.timeRangeFilter
            val filtered = filterActivities(all, filter)
            val stats = repository.calculateStatistics(all, filter)
            _uiState.value = _uiState.value.copy(
                allActivities = all,
                activities = filtered,
                statistics = stats
            )
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    private suspend fun syncInBackground() {
        try {
            // Get current user's health profile ID (NOT the auth user ID)
            val userId = supabaseClient.auth.currentUserOrNull()?.id ?: return
            val profile = profileRepository.getHealthProfile(userId)
            val healthProfileId = profile?.id ?: return

            val unsynced = _uiState.value.activities.filter { !it.synced }
            if (unsynced.isNotEmpty()) {
                repository.syncActivitiesToCloud(unsynced, healthProfileId)
            }
        } catch (e: Exception) {
            android.util.Log.w("RunActivityVM", "Sync failed: ${e.message}")
        }
    }
}
