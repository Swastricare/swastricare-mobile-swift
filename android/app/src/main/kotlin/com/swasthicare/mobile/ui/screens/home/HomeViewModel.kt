package com.swasthicare.mobile.ui.screens.home

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.models.CyclePhase
import com.swasthicare.mobile.data.models.HydrationEntry
import com.swasthicare.mobile.data.models.MenstrualSettings
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.components.DailyMetric
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

data class ServerNudge(
    val id: String,
    val title: String,
    val message: String,
    val icon: String = "heart.fill",
    val color: String = "#007AFF",
    val deepLink: String? = null
)

data class HomeState(
    val userName: String = "",
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
    val isLoading: Boolean = true,
    val isDemoMode: Boolean = false,
    val isAuthorized: Boolean = false,
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
    val cyclePhase: String = "Cycle Tracker"
)

class HomeViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(HomeState())
    val uiState: StateFlow<HomeState> = _uiState.asStateFlow()

    private val healthConnectService = AppContainer.healthConnectService
    private val hydrationRepository = AppContainer.hydrationRepository
    private val dietRepository = AppContainer.dietRepository
    private val medicationRepository = AppContainer.medicationRepository
    private val menstrualCycleRepository = AppContainer.menstrualCycleRepository

    private val isoFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")

    init {
        loadData()
    }

    /** Re-read local data sources (hydration, diet, etc.) to refresh the home cards. */
    fun refresh() {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            try {
                val hour = LocalDateTime.now().hour
                val greeting = when (hour) {
                    in 5..11 -> "Good Morning,"
                    in 12..16 -> "Good Afternoon,"
                    in 17..20 -> "Good Evening,"
                    else -> "Good Night,"
                }

                // Resolve user name
                val userName = AppContainer.authRepository.currentUser?.fullName
                    ?: AppContainer.authRepository.currentUser?.email?.substringBefore("@")
                    ?: ""

                // Load real data from Health Connect
                val summary = healthConnectService.getTodaySummary()
                val weeklyStepEntries = healthConnectService.getWeeklySteps()

                // Load hydration data from local store
                val todayStr = LocalDate.now().toString()
                val hydrationEntries = try { hydrationRepository.loadLocalEntries() } catch (_: Exception) { emptyList() }
                val todayHydration = hydrationEntries
                    .filter { it.consumedAt.startsWith(todayStr) }
                    .sumOf { it.effectiveMl }

                // Load diet data from local store
                val dietEntries = try { dietRepository.loadLocalLogs() } catch (_: Exception) { emptyList() }
                val todayCalories = dietEntries
                    .filter { it.loggedAt.startsWith(todayStr) }
                    .sumOf { it.calories }
                val dietGoals = try { dietRepository.loadGoals() } catch (_: Exception) { null }

                // Load medication counts from repository
                val profileId = AppContainer.authRepository.currentUser?.id
                val medicationsTotal: Int
                val medicationsTaken: Int
                if (profileId != null) {
                    val medications = try { medicationRepository.fetchMedications(profileId) } catch (_: Exception) { medicationRepository.getCachedMedications() }
                    val todayLogs = try { medicationRepository.fetchTodayLogs(profileId) } catch (_: Exception) { emptyList() }
                    medicationsTotal = medications.size
                    medicationsTaken = todayLogs.count { it.status == "taken" }
                } else {
                    medicationsTotal = medicationRepository.getCachedMedications().size
                    medicationsTaken = 0
                }

                // Load cycle phase from local cycles
                val cycles = try { menstrualCycleRepository.loadLocalCycles() } catch (_: Exception) { emptyList() }
                val settings = try { menstrualCycleRepository.loadSettings() } catch (_: Exception) { MenstrualSettings() }
                val phase = menstrualCycleRepository.detectCurrentPhase(cycles, settings)
                val cyclePhaseLabel = when (phase) {
                    CyclePhase.MENSTRUAL -> "Menstrual"
                    CyclePhase.FOLLICULAR -> "Follicular"
                    CyclePhase.OVULATION -> "Ovulation"
                    CyclePhase.LUTEAL -> "Luteal"
                    else -> "Cycle Tracker"
                }

                // Convert weekly steps to DailyMetric
                val weekDates = generateWeekDates()
                val weeklySteps = weeklyStepEntries.map { entry ->
                    DailyMetric(
                        date = java.util.Date.from(
                            entry.date.atStartOfDay(java.time.ZoneId.systemDefault()).toInstant()
                        ),
                        steps = entry.steps,
                        dayName = entry.dayName
                    )
                }

                _uiState.value = HomeState(
                    userName = userName,
                    greeting = greeting,
                    stepCount = summary.steps,
                    calories = summary.activeCalories,
                    activeMinutes = summary.exerciseMinutes,
                    standHours = summary.standHours,
                    heartRate = summary.heartRate,
                    sleepHours = summary.sleepFormatted,
                    distance = summary.distanceKm,
                    hydrationCurrent = todayHydration,
                    hydrationGoal = 2500,
                    medicationsTaken = medicationsTaken,
                    medicationsTotal = medicationsTotal,
                    isLoading = false,
                    isDemoMode = false,
                    isAuthorized = healthConnectService.isAvailable,
                    weekDates = weekDates,
                    selectedDate = Date(),
                    weeklySteps = weeklySteps,
                    calorieCurrent = todayCalories.toInt(),
                    calorieGoal = dietGoals?.dailyCalories ?: 2000,
                    cyclePhase = cyclePhaseLabel
                )
                loadNudges()
            } catch (e: Exception) {
                Log.w("HomeViewModel", "Error loading home data: ${e.message}")
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }

    fun loadNudges() {
        viewModelScope.launch {
            try {
                val profileId = AppContainer.authRepository.currentUser?.id ?: return@launch
                val nudges = AppContainer.nudgeRepository.fetchActiveNudges(profileId)
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
                val profileId = AppContainer.authRepository.currentUser?.id ?: return@syncCloud
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

    fun requestHealthPermissions() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isAuthorized = true, isDemoMode = false)
        }
    }

    fun syncToCloud() {
        // Sync handled by individual repositories
    }

    private fun generateWeekDates(): List<Date> {
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.DAY_OF_WEEK, calendar.firstDayOfWeek)
        return (0..6).map {
            val date = calendar.time
            calendar.add(Calendar.DAY_OF_MONTH, 1)
            date
        }
    }

    private fun isSameDay(date1: Date, date2: Date): Boolean {
        val cal1 = Calendar.getInstance().apply { time = date1 }
        val cal2 = Calendar.getInstance().apply { time = date2 }
        return cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
               cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
    }
}
