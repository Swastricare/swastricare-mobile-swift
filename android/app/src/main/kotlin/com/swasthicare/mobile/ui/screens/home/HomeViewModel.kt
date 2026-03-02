package com.swasthicare.mobile.ui.screens.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.services.HealthConnectService
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.components.DailyMetric
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.Calendar
import java.util.Date

data class ServerNudge(
    val id: String,
    val title: String,
    val message: String,
    val icon: String = "heart.fill",
    val color: String = "#007AFF",
    val deepLink: String? = null
)

data class HomeState(
    val userName: String = "Alex Johnson",
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
    val medicationsTotal: Int = 4,
    val isLoading: Boolean = true,
    val isDemoMode: Boolean = true,
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

    private val healthConnectService: HealthConnectService = AppContainer.healthConnectService

    init {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            val hour = LocalDateTime.now().hour
            val greeting = when (hour) {
                in 5..11 -> "Good Morning,"
                in 12..16 -> "Good Afternoon,"
                in 17..20 -> "Good Evening,"
                else -> "Good Night,"
            }

            // Generate week dates
            val weekDates = generateWeekDates()

            // Check if Health Connect is available and has permissions
            val hasPermissions = try { healthConnectService.hasAllPermissions() } catch (_: Exception) { false }
            val isAvailable = healthConnectService.isAvailable

            if (isAvailable && hasPermissions) {
                // Load real data from Health Connect
                loadRealHealthData(greeting, weekDates)
            } else {
                // Show demo data
                loadDemoData(greeting, weekDates)
            }

            loadNudges()
        }
    }

    private suspend fun loadRealHealthData(greeting: String, weekDates: List<Date>) {
        try {
            val summary = healthConnectService.getTodaySummary()
            val weeklyStepEntries = healthConnectService.getWeeklySteps()

            // Convert weekly steps to DailyMetric
            val weeklySteps = weeklyStepEntries.map { entry ->
                DailyMetric(
                    date = Date.from(entry.date.atStartOfDay(ZoneId.systemDefault()).toInstant()),
                    steps = entry.steps,
                    dayName = entry.dayName
                )
            }.ifEmpty { generateSampleWeeklySteps() }

            _uiState.value = HomeState(
                userName = "Alex Johnson",
                greeting = greeting,
                stepCount = summary.steps,
                calories = summary.activeCalories,
                activeMinutes = summary.exerciseMinutes,
                standHours = summary.standHours,
                heartRate = summary.heartRate,
                sleepHours = summary.sleepFormatted,
                distance = summary.distanceKm,
                hydrationCurrent = 0, // Populated by HydrationViewModel
                hydrationGoal = 2500,
                medicationsTaken = 0, // Populated by MedicationsViewModel
                medicationsTotal = 4,
                isLoading = false,
                isDemoMode = false,
                isAuthorized = true,
                weekDates = weekDates,
                selectedDate = Date(),
                weeklySteps = weeklySteps,
                calorieCurrent = 0,
                calorieGoal = 2000
            )
        } catch (e: Exception) {
            // Fallback to demo data on error
            loadDemoData(greeting, weekDates)
        }
    }

    private fun loadDemoData(greeting: String, weekDates: List<Date>) {
        val weeklySteps = generateSampleWeeklySteps()

        _uiState.value = HomeState(
            userName = "Alex Johnson",
            greeting = greeting,
            stepCount = 8432,
            calories = 450,
            activeMinutes = 45,
            standHours = 8,
            heartRate = 72,
            sleepHours = "7h 30m",
            distance = 5.2,
            hydrationCurrent = 1250,
            hydrationGoal = 2500,
            medicationsTaken = 2,
            medicationsTotal = 4,
            isLoading = false,
            isDemoMode = true,
            isAuthorized = false,
            weekDates = weekDates,
            selectedDate = Date(),
            weeklySteps = weeklySteps,
            calorieCurrent = 1240,
            calorieGoal = 2000
        )
    }

    fun loadNudges() {
        viewModelScope.launch {
            try {
                val demoNudges = listOf(
                    ServerNudge(
                        id = "1",
                        title = "Stay Hydrated",
                        message = "You're 750ml short of your daily water goal. Drink up!",
                        icon = "drop.fill",
                        color = "#00C7BE"
                    ),
                    ServerNudge(
                        id = "2",
                        title = "Medication Due",
                        message = "Your evening Vitamin D dose is due in 30 minutes.",
                        icon = "pills.fill",
                        color = "#30D158"
                    )
                )
                _uiState.value = _uiState.value.copy(serverNudges = demoNudges)
            } catch (_: Exception) {}
        }
    }

    fun dismissNudge(nudgeId: String) {
        val current = _uiState.value.serverNudges.filter { it.id != nudgeId }
        _uiState.value = _uiState.value.copy(serverNudges = current)
    }

    fun incrementHydration() {
        val current = _uiState.value
        if (current.hydrationCurrent < current.hydrationGoal) {
            _uiState.value = current.copy(hydrationCurrent = current.hydrationCurrent + 250)
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

    /** Refresh health data from Health Connect. */
    fun refreshHealthData() {
        viewModelScope.launch {
            val hasPermissions = try { healthConnectService.hasAllPermissions() } catch (_: Exception) { false }
            if (healthConnectService.isAvailable && hasPermissions) {
                val summary = healthConnectService.getTodaySummary()
                val weeklyStepEntries = healthConnectService.getWeeklySteps()
                val weeklySteps = weeklyStepEntries.map { entry ->
                    DailyMetric(
                        date = Date.from(entry.date.atStartOfDay(ZoneId.systemDefault()).toInstant()),
                        steps = entry.steps,
                        dayName = entry.dayName
                    )
                }.ifEmpty { _uiState.value.weeklySteps }

                _uiState.value = _uiState.value.copy(
                    stepCount = summary.steps,
                    calories = summary.activeCalories,
                    activeMinutes = summary.exerciseMinutes,
                    standHours = summary.standHours,
                    heartRate = summary.heartRate,
                    sleepHours = summary.sleepFormatted,
                    distance = summary.distanceKm,
                    isDemoMode = false,
                    isAuthorized = true,
                    weeklySteps = weeklySteps
                )
            }
        }
    }

    fun syncToCloud() {
        viewModelScope.launch {
            delay(1000)
        }
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

    private fun generateSampleWeeklySteps(): List<DailyMetric> {
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.DAY_OF_WEEK, calendar.firstDayOfWeek)
        val sampleSteps = listOf(6500, 8200, 7800, 9100, 8432, 5600, 4200)
        val dayNames = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
        return sampleSteps.mapIndexed { index, steps ->
            val date = calendar.time
            calendar.add(Calendar.DAY_OF_MONTH, 1)
            DailyMetric(date = date, steps = steps, dayName = dayNames[index])
        }
    }

    private fun isSameDay(date1: Date, date2: Date): Boolean {
        val cal1 = Calendar.getInstance().apply { time = date1 }
        val cal2 = Calendar.getInstance().apply { time = date2 }
        return cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
               cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
    }
}
