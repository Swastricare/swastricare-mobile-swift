package com.swastricare.health.ui.screens.menstrualcycle

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.menstrualcycle.CalendarDayData
import com.swastricare.health.domain.model.menstrualcycle.CyclePhase
import com.swastricare.health.domain.model.menstrualcycle.CyclePrediction
import com.swastricare.health.domain.model.menstrualcycle.CycleRecord
import com.swastricare.health.domain.model.menstrualcycle.CycleSettings
import com.swastricare.health.domain.model.menstrualcycle.CycleStatistics
import com.swastricare.health.domain.model.menstrualcycle.FlowLevel
import com.swastricare.health.domain.model.menstrualcycle.Mood
import com.swastricare.health.domain.model.menstrualcycle.Symptom
import com.swastricare.health.domain.usecase.menstrualcycle.EndPeriodUseCase
import com.swastricare.health.domain.usecase.menstrualcycle.GetCalendarDataUseCase
import com.swastricare.health.domain.usecase.menstrualcycle.GetCycleHistoryUseCase
import com.swastricare.health.domain.usecase.menstrualcycle.GetCycleInsightsUseCase
import com.swastricare.health.domain.usecase.menstrualcycle.LogPeriodUseCase
import com.swastricare.health.domain.usecase.menstrualcycle.LogSymptomsUseCase
import com.swastricare.health.domain.usecase.menstrualcycle.PredictNextPeriodUseCase
import com.swastricare.health.domain.usecase.menstrualcycle.UpdateCycleSettingsUseCase
import com.swastricare.health.presentation.feature.menstrualcycle.MenstrualCycleEvent
import com.swastricare.health.presentation.feature.menstrualcycle.MenstrualCycleUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import javax.inject.Inject

/**
 * ViewModel for menstrual cycle tracking screen.
 * Uses Clean Architecture with domain use cases and Hilt dependency injection.
 */
@HiltViewModel
class MenstrualCycleViewModelNew @Inject constructor(
    private val logPeriodUseCase: LogPeriodUseCase,
    private val endPeriodUseCase: EndPeriodUseCase,
    private val getCycleHistoryUseCase: GetCycleHistoryUseCase,
    private val predictNextPeriodUseCase: PredictNextPeriodUseCase,
    private val logSymptomsUseCase: LogSymptomsUseCase,
    private val getCycleInsightsUseCase: GetCycleInsightsUseCase,
    private val getCalendarDataUseCase: GetCalendarDataUseCase,
    private val updateCycleSettingsUseCase: UpdateCycleSettingsUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(MenstrualCycleUiState())
    val uiState: StateFlow<MenstrualCycleUiState> = _uiState.asStateFlow()

    private val dateFormatter = DateTimeFormatter.ofPattern("MMM dd, yyyy")

    init {
        loadData()
    }

    /**
     * Handles UI events from the screen.
     */
    fun onEvent(event: MenstrualCycleEvent) {
        when (event) {
            is MenstrualCycleEvent.LoadData -> loadData()
            is MenstrualCycleEvent.StartPeriod -> startPeriod(event.date, event.notes)
            is MenstrualCycleEvent.EndPeriod -> endPeriod(event.cycleId, event.date)
            is MenstrualCycleEvent.LogSymptoms -> logSymptoms(
                event.date,
                event.flowLevel,
                event.symptoms,
                event.mood,
                event.notes,
                event.painLevel
            )
            is MenstrualCycleEvent.UpdateSettings -> updateSettings(event.settings)
            is MenstrualCycleEvent.ChangeMonth -> changeMonth(event.delta)
            is MenstrualCycleEvent.TogglePeriodDate -> togglePeriodDate(event.date)
            is MenstrualCycleEvent.RefreshData -> loadData()
            is MenstrualCycleEvent.SyncData -> syncData()
            is MenstrualCycleEvent.DismissError -> dismissError()
        }
    }

    /**
     * Loads all cycle data (history, predictions, settings, calendar).
     */
    private fun loadData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            try {
                // Load cycle history
                val cycles: List<CycleRecord> = when (val cyclesResult = getCycleHistoryUseCase()) {
                    is ResultWrapper.Success -> cyclesResult.data
                    is ResultWrapper.Error -> {
                        handleError("Failed to load cycle history", cyclesResult.exception)
                        return@launch
                    }
                    else -> return@launch
                }

                // Get active cycle
                val activeCycle: CycleRecord? = when (val activeCycleResult = getCycleHistoryUseCase.getActiveCycle()) {
                    is ResultWrapper.Success -> activeCycleResult.data
                    else -> null
                }

                // Load prediction
                val prediction: CyclePrediction? = when (val predictionResult = predictNextPeriodUseCase()) {
                    is ResultWrapper.Success -> predictionResult.data
                    else -> null
                }

                // Load statistics
                val statistics: CycleStatistics? = when (val statsResult = getCycleInsightsUseCase()) {
                    is ResultWrapper.Success -> statsResult.data
                    else -> null
                }

                // Load calendar data
                val calendarData: List<CalendarDayData> = when (val calendarResult = getCalendarDataUseCase(
                    _uiState.value.selectedMonth
                )) {
                    is ResultWrapper.Success -> calendarResult.data
                    else -> emptyList()
                }

                // Calculate current cycle info
                val lastCycle = cycles.firstOrNull()
                val currentDay = if (lastCycle != null && lastCycle.isActive) {
                    ChronoUnit.DAYS.between(
                        lastCycle.startDate,
                        LocalDate.now()
                    ).toInt() + 1
                } else 1

                val settings: CycleSettings = _uiState.value.settings
                val daysUntil = prediction?.daysUntilNextPeriod() ?: 0

                // Determine current phase
                val phase = if (lastCycle != null && lastCycle.isActive) {
                    CyclePhase.fromDayInCycle(
                        dayInCycle = currentDay,
                        periodLength = lastCycle.effectivePeriodLength ?: settings.validatedPeriodLength,
                        cycleLength = settings.validatedCycleLength
                    )
                } else {
                    CyclePhase.UNKNOWN
                }

                _uiState.update {
                    it.copy(
                        isLoading = false,
                        cycles = cycles,
                        activeCycle = activeCycle,
                        currentPhase = phase,
                        currentDayInCycle = currentDay.coerceIn(1, settings.validatedCycleLength),
                        totalCycleDays = settings.validatedCycleLength,
                        daysUntilNextPeriod = daysUntil,
                        lastPeriodStart = lastCycle?.startDate,
                        prediction = prediction,
                        statistics = statistics,
                        calendarData = calendarData
                    )
                }
            } catch (e: Exception) {
                handleError("Failed to load data", e)
            }
        }
    }

    /**
     * Starts a new period/cycle.
     */
    private fun startPeriod(date: LocalDate, notes: String?) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            when (val result = logPeriodUseCase(date, notes)) {
                is ResultWrapper.Success -> {
                    loadData() // Reload all data
                }
                is ResultWrapper.Error -> {
                    handleError("Failed to start period", result.exception)
                }
                else -> {}
            }
        }
    }

    /**
     * Ends the current active period.
     */
    private fun endPeriod(cycleId: String, date: LocalDate) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            when (val result = endPeriodUseCase(cycleId, date)) {
                is ResultWrapper.Success -> {
                    loadData() // Reload all data
                }
                is ResultWrapper.Error -> {
                    handleError("Failed to end period", result.exception)
                }
                else -> {}
            }
        }
    }

    /**
     * Logs daily symptoms, flow, and mood.
     */
    private fun logSymptoms(
        date: LocalDate,
        flowLevel: FlowLevel,
        symptoms: List<Symptom>,
        mood: Mood?,
        notes: String?,
        painLevel: Int
    ) {
        viewModelScope.launch {
            when (val result = logSymptomsUseCase(
                date = date,
                flowLevel = flowLevel,
                symptoms = symptoms,
                mood = mood,
                notes = notes,
                painLevel = painLevel
            )) {
                is ResultWrapper.Success -> {
                    // Refresh calendar data to reflect the new log
                    loadCalendarData()
                }
                is ResultWrapper.Error -> {
                    handleError("Failed to log symptoms", result.exception)
                }
                else -> {}
            }
        }
    }

    /**
     * Updates cycle settings (average lengths, reminders).
     */
    private fun updateSettings(settings: CycleSettings) {
        viewModelScope.launch {
            when (val result = updateCycleSettingsUseCase(settings)) {
                is ResultWrapper.Success -> {
                    _uiState.update { it.copy(settings = result.data) }
                    loadData() // Recalculate predictions with new settings
                }
                is ResultWrapper.Error -> {
                    handleError("Failed to update settings", result.exception)
                }
                else -> {}
            }
        }
    }

    /**
     * Changes the displayed calendar month.
     */
    private fun changeMonth(delta: Int) {
        val newMonth = _uiState.value.selectedMonth.plusMonths(delta.toLong())
        _uiState.update { it.copy(selectedMonth = newMonth) }
        loadCalendarData()
    }

    /**
     * Toggles a period date on/off (for quick logging).
     */
    private fun togglePeriodDate(date: LocalDate) {
        viewModelScope.launch {
            val currentData = _uiState.value.calendarData.find { it.date == date }

            if (currentData?.isCurrentPeriod == true) {
                // Remove: log with NONE flow level
                logSymptoms(
                    date = date,
                    flowLevel = FlowLevel.NONE,
                    symptoms = emptyList(),
                    mood = null,
                    notes = null,
                    painLevel = 0
                )
            } else {
                // Add: log with MEDIUM flow level
                logSymptoms(
                    date = date,
                    flowLevel = FlowLevel.MEDIUM,
                    symptoms = emptyList(),
                    mood = null,
                    notes = null,
                    painLevel = 0
                )
            }
        }
    }

    /**
     * Syncs local data with cloud.
     */
    private fun syncData() {
        viewModelScope.launch {
            // Note: Sync functionality would be implemented in the repository
            // For now, we just reload data
            loadData()
        }
    }

    /**
     * Loads calendar data for the selected month.
     */
    private fun loadCalendarData() {
        viewModelScope.launch {
            when (val result = getCalendarDataUseCase(_uiState.value.selectedMonth)) {
                is ResultWrapper.Success -> {
                    _uiState.update { it.copy(calendarData = result.data) }
                }
                is ResultWrapper.Error -> {
                    handleError("Failed to load calendar", result.exception)
                }
                else -> {}
            }
        }
    }

    /**
     * Formats a date for display.
     */
    fun formatDate(date: LocalDate): String = date.format(dateFormatter)

    /**
     * Handles errors by updating UI state.
     */
    private fun handleError(message: String, exception: Throwable) {
        _uiState.update {
            it.copy(
                isLoading = false,
                error = "$message: ${exception.message}"
            )
        }
    }

    /**
     * Dismisses the current error message.
     */
    private fun dismissError() {
        _uiState.update { it.copy(error = null) }
    }
}
