package com.swastricare.health.ui.screens.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.models.HydrationEntry
import com.swastricare.health.data.models.MedicationDose
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.data.repository.HomeDataPreloader
import com.swastricare.health.data.repository.SupabaseAuthRepository
import com.swastricare.health.data.repository.SupabaseHydrationRepository
import com.swastricare.health.data.repository.SupabaseNudgeRepository
import com.swastricare.health.ui.components.DailyMetric
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Calendar
import java.util.Date
import java.util.UUID
import javax.inject.Inject

data class ServerNudge(
    val id: String,
    val title: String,
    val message: String,
    val icon: String = "heart.fill",
    val color: String = "#007AFF",
    val deepLink: String? = null
)

enum class MetricType(
    val label: String,
    val unit: String
) {
    STEPS("Steps", "steps"),
    CALORIES("Calories", "kcal"),
    HEART_RATE("Heart Rate", "BPM"),
    SLEEP("Sleep", "hrs"),
    EXERCISE("Exercise", "min"),
    DISTANCE("Distance", "km")
}

sealed class HomeAIState {
    object Idle : HomeAIState()
    object Analyzing : HomeAIState()
    data class Result(val assessment: String, val recommendation: String) : HomeAIState()
    data class Error(val message: String) : HomeAIState()
}

data class HomeState(
    val activityGoals: com.swastricare.health.data.models.ActivityGoals =
        com.swastricare.health.data.models.ActivityGoals(),
    val userName: String = "",
    val userAvatarUrl: String? = null,
    val greeting: String = "Good Morning,",
    val stepCount: Int = 0,
    val calories: Int = 0,
    val activeMinutes: Int = 0,
    val standHours: Int = 0,
    val heartRate: Int = 0,
    val sleepHours: String = "--",
    val distance: Double = 0.0,
    val hydrationCurrent: Int = 0,
    val hydrationGoal: Int = 2500,
    val medicationsTaken: Int = 0,
    val medicationsTotal: Int = 0,
    val pendingMedicationDoses: List<MedicationDose> = emptyList(),
    val isLoading: Boolean = true,
    val isDemoMode: Boolean = false,
    val isAuthorized: Boolean = false,
    val needsHealthPermissions: Boolean = false,
    val healthConnectAvailable: Boolean = true,
    // Tracker state
    val weekDates: List<Date> = emptyList(),
    val selectedDate: Date = Date(),
    val weeklySteps: List<DailyMetric> = emptyList(),
    // Nudges
    val serverNudges: List<ServerNudge> = emptyList(),
    // Diet quick action data
    val calorieCurrent: Int = 0,
    val calorieGoal: Int = 2000,
    // Cycle tracker stub
    val cyclePhase: String = "Cycle Tracker",
    // True when HC is authorized but no data exists (e.g. no fitness app writing to HC)
    val hasNoHealthData: Boolean = false,
    val selectedMetric: MetricType = MetricType.STEPS,
    val aiAnalysisState: HomeAIState = HomeAIState.Idle,
)

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val healthConnectService: HealthConnectService,
    private val hydrationRepository: SupabaseHydrationRepository,
    private val authRepository: SupabaseAuthRepository,
    private val nudgeRepository: SupabaseNudgeRepository,
    private val activityGoalsRepository: com.swastricare.health.data.repository.ActivityGoalsRepository,
    private val preloader: HomeDataPreloader
) : ViewModel() {

    // Start with a non-loading empty state — the splash screen preloads the
    // real data before we get here. On rare cache-miss paths (e.g. user
    // navigating here via an unusual route), loadData() will fill it in.
    private val _uiState = MutableStateFlow(HomeState(isLoading = false))
    val uiState: StateFlow<HomeState> = _uiState.asStateFlow()

    private val isoFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")

    init {
        loadData()
    }

    /** Re-read data sources (hydration, diet, etc.) to refresh the home cards. */
    fun refresh() {
        preloader.invalidate()
        loadData()
    }

    /** Cheap refresh — reload only the locally cached activity goals. */
    fun refreshActivityGoals() {
        _uiState.value = _uiState.value.copy(
            activityGoals = activityGoalsRepository.loadLocalGoals()
        )
    }

    private fun loadData() {
        viewModelScope.launch {
            val cached = preloader.consumeCache()
            val baseState = if (cached != null) cached else preloader.fetchHomeState()
            val hcAvailable = healthConnectService.isAvailable
            val needsPerms = hcAvailable && !healthConnectService.hasAllPermissions()
            _uiState.value = baseState.copy(
                activityGoals = activityGoalsRepository.loadLocalGoals(),
                healthConnectAvailable = hcAvailable,
                needsHealthPermissions = needsPerms
            )
            loadNudges()
        }
    }

    /** Called by the screen after the auto-prompt has been launched so the
     *  flag doesn't trigger a second time during the same session. */
    fun markHealthPermissionsPrompted() {
        _uiState.value = _uiState.value.copy(needsHealthPermissions = false)
    }

    fun loadNudges() {
        viewModelScope.launch {
            try {
                val profileId = authRepository.currentUser?.id ?: return@launch
                val nudges = nudgeRepository.fetchActiveNudges(profileId)
                val serverNudges = nudges.map { nudge ->
                    ServerNudge(
                        id = nudge.id,
                        title = nudge.title,
                        message = nudge.message,
                        icon = nudge.type.name.lowercase(),
                        color = "#007AFF",
                        deepLink = nudge.actionUrl
                    )
                }
                _uiState.value = _uiState.value.copy(serverNudges = serverNudges)
            } catch (_: Exception) {
                // Nudges are non-critical
            }
        }
    }

    fun dismissNudge(nudgeId: String) {
        val current = _uiState.value.serverNudges.filter { it.id != nudgeId }
        _uiState.value = _uiState.value.copy(serverNudges = current)
    }

    fun incrementHydration() {
        viewModelScope.launch {
            val entry = HydrationEntry(
                id = UUID.randomUUID().toString(),
                drinkType = "water",
                amountMl = 250,
                effectiveMl = 250,
                consumedAt = LocalDateTime.now().format(isoFormatter),
                synced = false
            )
            hydrationRepository.addLocalEntry(entry)

            // Refresh total from local storage
            val todayStr = LocalDate.now().toString()
            val entries = hydrationRepository.loadLocalEntries()
            val todayTotal = entries.filter { it.consumedAt.startsWith(todayStr) }.sumOf { it.effectiveMl }
            _uiState.value = _uiState.value.copy(hydrationCurrent = todayTotal)

            // Sync unsynced entries to cloud in background
            launch syncCloud@{
                val profileId = authRepository.currentUser?.id ?: return@syncCloud
                val unsynced = hydrationRepository.loadLocalEntries().filter { !it.synced }
                if (unsynced.isNotEmpty()) {
                    hydrationRepository.syncEntriesToCloud(unsynced, profileId)
                }
            }
        }
    }

    fun selectDate(date: Date) {
        val current = _uiState.value
        _uiState.value = current.copy(selectedDate = date)
        val metric = current.weeklySteps.find { isSameDay(it.date, date) }
        metric?.let {
            _uiState.value = _uiState.value.copy(stepCount = it.steps)
        }
    }

    fun selectMetric(metric: MetricType) {
        _uiState.value = _uiState.value.copy(selectedMetric = metric)
    }

    fun requestAIAnalysis() {
        val state = _uiState.value
        _uiState.value = state.copy(aiAnalysisState = HomeAIState.Analyzing)
        viewModelScope.launch {
            try {
                kotlinx.coroutines.delay(1500)
                _uiState.value = _uiState.value.copy(
                    aiAnalysisState = HomeAIState.Result(
                        assessment = "Your activity looks good today with ${state.stepCount} steps and ${state.calories} kcal burned.",
                        recommendation = "Try to add 10 more minutes of exercise to reach your daily goal."
                    )
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    aiAnalysisState = HomeAIState.Error(e.message ?: "Analysis failed")
                )
            }
        }
    }

    fun dismissAnalysis() {
        _uiState.value = _uiState.value.copy(aiAnalysisState = HomeAIState.Idle)
    }

    /**
     * Call this after the Health Connect permission launcher returns its result.
     * Invalidates the HC cache and triggers a full data reload so the new
     * permissions are reflected on the home screen immediately.
     */
    fun onHealthPermissionsResult(grantedPermissions: Set<String>) {
        healthConnectService.invalidateCache()
        preloader.invalidate()
        loadData()
    }

    /** @deprecated Prefer [onHealthPermissionsResult]. Kept for source compatibility. */
    fun requestHealthPermissions() {
        healthConnectService.invalidateCache()
        preloader.invalidate()
        loadData()
    }

    fun syncToCloud() {
        // Sync handled by individual repositories
    }

    private fun isSameDay(date1: Date, date2: Date): Boolean {
        val cal1 = Calendar.getInstance().apply { time = date1 }
        val cal2 = Calendar.getInstance().apply { time = date2 }
        return cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
               cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
    }
}
