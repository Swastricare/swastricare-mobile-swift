package com.swastricare.health.ui.screens.runactivity

import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalDate
import java.time.YearMonth
import javax.inject.Inject
import kotlin.random.Random

// ─────────────────────────────────────
// MARK: - Data Models
// ─────────────────────────────────────

data class WorkoutSummary(
    val id: String,
    val type: String, // "running", "walking", "cycling"
    val date: LocalDate,
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
    val totalDurationMinutes: Int = 0
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
class RunCalendarViewModel @Inject constructor() : ViewModel() {

    private val _uiState = MutableStateFlow(RunCalendarUiState(isLoading = true))
    val uiState: StateFlow<RunCalendarUiState> = _uiState.asStateFlow()

    // All demo workouts (spans current and previous month)
    private val allWorkouts: List<WorkoutSummary> = generateDemoWorkouts()

    init {
        loadMonth(YearMonth.now())
    }

    // ─────────────────────────────────
    // Public API
    // ─────────────────────────────────

    fun changeMonth(delta: Int) {
        val current = _uiState.value.selectedMonth
        val newMonth = current.plusMonths(delta.toLong())
        // Don't allow navigating past current month
        if (newMonth.isAfter(YearMonth.now())) return
        loadMonth(newMonth)
    }

    fun selectDate(date: LocalDate) {
        val current = _uiState.value
        // Toggle selection
        val newSelection = if (current.selectedDate == date) null else date
        _uiState.value = current.copy(selectedDate = newSelection)
    }

    // ─────────────────────────────────
    // Private helpers
    // ─────────────────────────────────

    private fun loadMonth(month: YearMonth) {
        val monthWorkouts = allWorkouts.filter { YearMonth.from(it.date) == month }
        val byDate = monthWorkouts.groupBy { it.date }

        val stats = MonthlyStats(
            totalDistanceKm = monthWorkouts.sumOf { it.distanceKm },
            totalWorkouts = monthWorkouts.size,
            activeDays = byDate.keys.size,
            totalCalories = monthWorkouts.sumOf { it.caloriesBurned },
            totalDurationMinutes = monthWorkouts.sumOf { it.durationMinutes }
        )

        _uiState.value = RunCalendarUiState(
            selectedMonth = month,
            workoutsByDate = byDate,
            selectedDate = null,
            monthlyStats = stats,
            isLoading = false
        )
    }

    private fun generateDemoWorkouts(): List<WorkoutSummary> {
        val today = LocalDate.now()
        val random = Random(42) // Fixed seed for consistency
        val types = listOf("running", "walking", "cycling")
        val workouts = mutableListOf<WorkoutSummary>()

        // Generate 12-15 workouts scattered across current and previous month
        val targetDays = mutableSetOf<LocalDate>()

        // Current month: 7-9 workouts
        val currentMonth = YearMonth.now()
        repeat(8) {
            var day: LocalDate
            do {
                val dayOfMonth = random.nextInt(1, minOf(today.dayOfMonth + 1, currentMonth.lengthOfMonth() + 1))
                day = currentMonth.atDay(dayOfMonth)
            } while (day.isAfter(today)) // Don't generate future workouts
            targetDays.add(day)
        }

        // Previous month: 5-7 workouts
        val prevMonth = currentMonth.minusMonths(1)
        repeat(6) {
            val dayOfMonth = random.nextInt(1, prevMonth.lengthOfMonth() + 1)
            targetDays.add(prevMonth.atDay(dayOfMonth))
        }

        var idCounter = 1
        for (day in targetDays.sorted()) {
            val type = types[random.nextInt(types.size)]
            val distance = when (type) {
                "running" -> 3.0 + random.nextDouble() * 8.0  // 3-11 km
                "walking" -> 1.5 + random.nextDouble() * 4.0  // 1.5-5.5 km
                "cycling" -> 5.0 + random.nextDouble() * 20.0 // 5-25 km
                else -> 3.0
            }
            val duration = when (type) {
                "running" -> (distance * (4.5 + random.nextDouble() * 2.0)).toInt() // 4.5-6.5 min/km
                "walking" -> (distance * (9.0 + random.nextDouble() * 3.0)).toInt() // 9-12 min/km
                "cycling" -> (distance * (2.0 + random.nextDouble() * 1.5)).toInt() // 2-3.5 min/km
                else -> 30
            }
            val calories = (distance * (if (type == "running") 65 else if (type == "cycling") 40 else 50)).toInt()
            val pace = if (type != "cycling") duration.toDouble() / distance else null

            workouts.add(
                WorkoutSummary(
                    id = "workout_${idCounter++}",
                    type = type,
                    date = day,
                    distanceKm = Math.round(distance * 100.0) / 100.0,
                    durationMinutes = duration,
                    caloriesBurned = calories,
                    avgPaceMinPerKm = pace?.let { Math.round(it * 100.0) / 100.0 }
                )
            )

            // Occasionally add a second workout on the same day (10% chance)
            if (random.nextFloat() < 0.10f) {
                val type2 = types.filter { it != type }.random(random)
                val dist2 = 2.0 + random.nextDouble() * 4.0
                val dur2 = (dist2 * 6.0).toInt()
                val cal2 = (dist2 * 55).toInt()
                workouts.add(
                    WorkoutSummary(
                        id = "workout_${idCounter++}",
                        type = type2,
                        date = day,
                        distanceKm = Math.round(dist2 * 100.0) / 100.0,
                        durationMinutes = dur2,
                        caloriesBurned = cal2,
                        avgPaceMinPerKm = Math.round(dur2.toDouble() / dist2 * 100.0) / 100.0
                    )
                )
            }
        }

        return workouts
    }
}
