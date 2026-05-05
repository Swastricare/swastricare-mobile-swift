package com.swastricare.health.ui.screens.runactivity

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.models.RunActivity
import com.swastricare.health.data.repository.RunActivityRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth
import javax.inject.Inject

// ─────────────────────────────────────
// MARK: - Data Models
// ─────────────────────────────────────

data class WorkoutSummary(
    val id: String,
    val type: String, // "running", "walking", "cycling", "hiking"
    val date: LocalDate,
    val startTime: LocalDateTime?,
    val distanceKm: Double,
    val durationMinutes: Int,
    val caloriesBurned: Int,
    val avgPaceMinPerKm: Double?
)

data class MonthlyStats(
    val totalDistanceKm: Double = 0.0,
    val totalWorkouts: Int = 0,
    val activeDays: Int = 0,
    val totalCalories: Int = 0,
    val totalDurationMinutes: Int = 0,
    val runsCount: Int = 0,
    val walksCount: Int = 0,
    val cyclesCount: Int = 0,
    val hikesCount: Int = 0
)

data class RunCalendarUiState(
    val selectedMonth: YearMonth = YearMonth.now(),
    val workoutsByDate: Map<LocalDate, List<WorkoutSummary>> = emptyMap(),
    val selectedDate: LocalDate? = null,
    val monthlyStats: MonthlyStats = MonthlyStats(),
    val isLoading: Boolean = false
)

// ─────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────

@HiltViewModel
class RunCalendarViewModel @Inject constructor(
    private val repository: RunActivityRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(RunCalendarUiState(isLoading = true))
    val uiState: StateFlow<RunCalendarUiState> = _uiState.asStateFlow()

    // Full list of real workouts — loaded once, re-filtered per month
    private var allWorkouts: List<WorkoutSummary> = emptyList()

    init {
        loadAllWorkouts()
    }

    // ─────────────────────────────────
    // Public API
    // ─────────────────────────────────

    fun changeMonth(delta: Int) {
        val current = _uiState.value.selectedMonth
        val newMonth = current.plusMonths(delta.toLong())
        if (newMonth.isAfter(YearMonth.now())) return
        showMonth(newMonth)
    }

    fun selectDate(date: LocalDate) {
        val current = _uiState.value
        val newSelection = if (current.selectedDate == date) null else date
        _uiState.value = current.copy(selectedDate = newSelection)
    }

    fun refresh() {
        loadAllWorkouts()
    }

    // ─────────────────────────────────
    // Private helpers
    // ─────────────────────────────────

    private fun loadAllWorkouts() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            allWorkouts = repository.loadLocalActivities().mapNotNull { activity: RunActivity ->
                val date = activity.startTime?.toLocalDate() ?: return@mapNotNull null
                WorkoutSummary(
                    id = activity.id,
                    type = activity.activityType.dbValue,
                    date = date,
                    startTime = activity.startTime,
                    distanceKm = activity.distanceMeters / 1000.0,
                    durationMinutes = (activity.durationSeconds / 60).toInt(),
                    caloriesBurned = activity.caloriesBurned,
                    avgPaceMinPerKm = if (activity.avgPaceSecondsPerKm > 0)
                        activity.avgPaceSecondsPerKm / 60.0 else null
                )
            }.sortedByDescending { it.date }

            showMonth(_uiState.value.selectedMonth)
        }
    }

    private fun showMonth(month: YearMonth) {
        val monthWorkouts = allWorkouts.filter { YearMonth.from(it.date) == month }
        val byDate = monthWorkouts.groupBy { it.date }

        val stats = MonthlyStats(
            totalDistanceKm = monthWorkouts.sumOf { it.distanceKm },
            totalWorkouts = monthWorkouts.size,
            activeDays = byDate.keys.size,
            totalCalories = monthWorkouts.sumOf { it.caloriesBurned },
            totalDurationMinutes = monthWorkouts.sumOf { it.durationMinutes },
            runsCount = monthWorkouts.count { it.type == "running" },
            walksCount = monthWorkouts.count { it.type == "walking" },
            cyclesCount = monthWorkouts.count { it.type == "cycling" },
            hikesCount = monthWorkouts.count { it.type == "hiking" }
        )

        _uiState.value = RunCalendarUiState(
            selectedMonth = month,
            workoutsByDate = byDate,
            selectedDate = null,
            monthlyStats = stats,
            isLoading = false
        )
    }
}
