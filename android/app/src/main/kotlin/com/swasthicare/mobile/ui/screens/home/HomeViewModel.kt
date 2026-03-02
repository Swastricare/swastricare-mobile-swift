package com.swasthicare.mobile.ui.screens.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.services.DailyStepCount
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.components.DailyMetric
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Calendar
import java.util.Date
import java.util.Locale

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
    // Real weekly steps from Health Connect
    val weeklyStepCounts: List<DailyStepCount> = emptyList(),
    val dailyStepGoal: Int = 10000,
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

    private val healthConnectService by lazy {
        try { AppContainer.healthConnectService } catch (_: Exception) { null }
    }

    init {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            // Simulate network delay
            delay(1500)

            val hour = LocalDateTime.now().hour
            val greeting = when (hour) {
                in 5..11 -> "Good Morning,"
                in 12..16 -> "Good Afternoon,"
                in 17..20 -> "Good Evening,"
                else -> "Good Night,"
            }

            // Generate week dates and sample data
            val weekDates = generateWeekDates()
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
            loadNudges()

            // Load real weekly steps from Health Connect
            loadRealWeeklySteps()
        }
    }

    /**
     * Fetch real weekly steps from Health Connect.
     * Falls back to sample data if Health Connect is not available.
     */
    private fun loadRealWeeklySteps() {
        viewModelScope.launch {
            try {
                val service = healthConnectService ?: return@launch
                val weeklyStepCounts = service.getWeeklySteps()

                // Convert DailyStepCount to DailyMetric for chart compatibility
                val realWeeklyMetrics = weeklyStepCounts.map { dsc ->
                    val dayName = dsc.date.dayOfWeek.getDisplayName(
                        TextStyle.SHORT, Locale.getDefault()
                    ).take(3)
                    val calendar = Calendar.getInstance().apply {
                        set(Calendar.YEAR, dsc.date.year)
                        set(Calendar.MONTH, dsc.date.monthValue - 1)
                        set(Calendar.DAY_OF_MONTH, dsc.date.dayOfMonth)
                    }
                    DailyMetric(
                        date = calendar.time,
                        steps = dsc.steps.toInt(),
                        dayName = dayName
                    )
                }

                // Update today's step count from real data
                val today = LocalDate.now()
                val todaySteps = weeklyStepCounts.firstOrNull { it.date == today }?.steps?.toInt()

                _uiState.value = _uiState.value.copy(
                    weeklySteps = realWeeklyMetrics,
                    weeklyStepCounts = weeklyStepCounts,
                    stepCount = todaySteps ?: _uiState.value.stepCount,
                    isDemoMode = false
                )
            } catch (_: Exception) {
                // Keep sample data on failure
            }
        }
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

        // Update step count based on weekly data
        val metric = current.weeklySteps.find { isSameDay(it.date, date) }
        metric?.let {
            _uiState.value = _uiState.value.copy(stepCount = it.steps)
        }
    }

    fun requestHealthPermissions() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isAuthorized = true, isDemoMode = false)
            loadRealWeeklySteps()
        }
    }

    fun syncToCloud() {
        viewModelScope.launch {
            delay(1000)
        }
    }

    // Helper function to generate week dates
    private fun generateWeekDates(): List<Date> {
        val calendar = Calendar.getInstance()

        // Start from beginning of week
        calendar.set(Calendar.DAY_OF_WEEK, calendar.firstDayOfWeek)

        return (0..6).map {
            val date = calendar.time
            calendar.add(Calendar.DAY_OF_MONTH, 1)
            date
        }
    }

    // Generate sample weekly steps data
    private fun generateSampleWeeklySteps(): List<DailyMetric> {
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.DAY_OF_WEEK, calendar.firstDayOfWeek)

        val sampleSteps = listOf(6500, 8200, 7800, 9100, 8432, 5600, 4200)
        val dayNames = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")

        return sampleSteps.mapIndexed { index, steps ->
            val date = calendar.time
            calendar.add(Calendar.DAY_OF_MONTH, 1)
            DailyMetric(
                date = date,
                steps = steps,
                dayName = dayNames[index]
            )
        }
    }

    // Helper function to compare dates
    private fun isSameDay(date1: Date, date2: Date): Boolean {
        val cal1 = Calendar.getInstance().apply { time = date1 }
        val cal2 = Calendar.getInstance().apply { time = date2 }
        return cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
                cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
    }
}
