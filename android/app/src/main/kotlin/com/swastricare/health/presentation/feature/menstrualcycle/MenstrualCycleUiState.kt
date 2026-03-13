package com.swastricare.health.presentation.feature.menstrualcycle

import com.swastricare.health.domain.model.menstrualcycle.*
import java.time.LocalDate

/**
 * UI state for the menstrual cycle tracker screen.
 * Represents the complete state of the cycle tracking UI.
 */
data class MenstrualCycleUiState(
    val isLoading: Boolean = true,
    val error: String? = null,

    // Current cycle info
    val currentPhase: CyclePhase = CyclePhase.UNKNOWN,
    val currentDayInCycle: Int = 1,
    val totalCycleDays: Int = 28,
    val daysUntilNextPeriod: Int = 0,
    val lastPeriodStart: LocalDate? = null,
    val activeCycle: CycleRecord? = null,

    // Calendar data
    val selectedMonth: LocalDate = LocalDate.now().withDayOfMonth(1),
    val calendarData: List<CalendarDayData> = emptyList(),

    // Predictions
    val prediction: CyclePrediction? = null,

    // Statistics
    val statistics: CycleStatistics? = null,

    // Settings
    val settings: CycleSettings = CycleSettings(),

    // Cycle history
    val cycles: List<CycleRecord> = emptyList(),

    // Daily logs
    val dailyLogs: List<DailyLog> = emptyList()
) {
    /**
     * Calculates cycle progress as a percentage (0.0 to 1.0).
     */
    val cycleProgress: Float
        get() = if (totalCycleDays > 0) {
            (currentDayInCycle.toFloat() / totalCycleDays).coerceIn(0f, 1f)
        } else 0f

    /**
     * Returns dates with logged periods for calendar display.
     */
    val loggedPeriodDates: Set<LocalDate>
        get() = calendarData
            .filter { it.isCurrentPeriod }
            .map { it.date }
            .toSet()

    /**
     * Returns predicted period dates for calendar display.
     */
    val predictedPeriodDates: Set<LocalDate>
        get() = calendarData
            .filter { it.isPredictedPeriod }
            .map { it.date }
            .toSet()

    /**
     * Returns fertile window dates for calendar display.
     */
    val fertileWindowDates: Set<LocalDate>
        get() = calendarData
            .filter { it.isFertile }
            .map { it.date }
            .toSet()

    /**
     * Returns true if there's enough data to show meaningful insights.
     */
    val hasReliableData: Boolean
        get() = statistics?.hasReliableData == true
}

/**
 * UI events for menstrual cycle screen interactions.
 */
sealed interface MenstrualCycleEvent {
    data object LoadData : MenstrualCycleEvent
    data class StartPeriod(val date: LocalDate, val notes: String? = null) : MenstrualCycleEvent
    data class EndPeriod(val cycleId: String, val date: LocalDate) : MenstrualCycleEvent
    data class LogSymptoms(
        val date: LocalDate,
        val flowLevel: FlowLevel,
        val symptoms: List<Symptom>,
        val mood: Mood?,
        val notes: String?,
        val painLevel: Int
    ) : MenstrualCycleEvent
    data class UpdateSettings(val settings: CycleSettings) : MenstrualCycleEvent
    data class ChangeMonth(val delta: Int) : MenstrualCycleEvent
    data class TogglePeriodDate(val date: LocalDate) : MenstrualCycleEvent
    data object RefreshData : MenstrualCycleEvent
    data object SyncData : MenstrualCycleEvent
    data object DismissError : MenstrualCycleEvent
}
