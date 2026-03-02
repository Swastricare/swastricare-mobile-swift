package com.swasthicare.mobile.ui.screens.menstrualcycle

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.data.repository.MenstrualCycleRepository
import com.swasthicare.mobile.data.repository.ProfileRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

// ------------------------------------
// MARK: - UI State
// ------------------------------------

data class MenstrualCycleUiState(
    val cycles: List<MenstrualCycle> = emptyList(),
    val currentPhase: CyclePhase = CyclePhase.UNKNOWN,
    val predictions: CyclePrediction? = null,
    val dailyLogs: List<MenstrualDailyLog> = emptyList(),
    val settings: MenstrualSettings = MenstrualSettings(),
    val statistics: CycleStatistics = CycleStatistics(),
    val calendarData: List<CalendarDayData> = emptyList(),
    val selectedDate: LocalDate = LocalDate.now(),
    val selectedMonth: YearMonth = YearMonth.now(),
    val daysSinceLastPeriod: Int? = null,
    val daysUntilNextPeriod: Int? = null,
    val currentDayOfCycle: Int? = null,
    val selectedDayLog: MenstrualDailyLog? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
    // Sheet states
    val showDailyLogSheet: Boolean = false,
    val showSettingsSheet: Boolean = false,
    val showStatisticsSheet: Boolean = false
)

// ------------------------------------
// MARK: - ViewModel
// ------------------------------------

class MenstrualCycleViewModel(
    private val repository: MenstrualCycleRepository,
    private val profileRepository: ProfileRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(MenstrualCycleUiState(isLoading = true))
    val uiState: StateFlow<MenstrualCycleUiState> = _uiState.asStateFlow()

    private val demoProfileId = "demo-profile-id"

    init {
        loadData()
    }

    fun loadData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)

            val cycles = repository.loadLocalCycles()
            val dailyLogs = repository.loadLocalDailyLogs()
            val settings = repository.loadSettings()
            val predictions = repository.calculatePredictions(cycles, settings)
            val statistics = repository.calculateStatistics(cycles)
            val currentPhase = repository.detectCurrentPhase(cycles, settings)
            val calendarData = repository.generateCalendarData(
                cycles, dailyLogs, predictions, _uiState.value.selectedMonth.atDay(1)
            )

            val sorted = cycles.sortedByDescending { it.startDate }
            val lastCycle = sorted.firstOrNull()
            val today = LocalDate.now()

            val daysSinceLast = lastCycle?.let {
                java.time.temporal.ChronoUnit.DAYS.between(it.startDate, today).toInt()
            }
            val daysUntilNext = predictions?.let {
                java.time.temporal.ChronoUnit.DAYS.between(today, it.nextPeriodDate).toInt()
            }?.coerceAtLeast(0)

            _uiState.value = _uiState.value.copy(
                cycles = cycles,
                currentPhase = currentPhase,
                predictions = predictions,
                dailyLogs = dailyLogs,
                settings = settings,
                statistics = statistics,
                calendarData = calendarData,
                daysSinceLastPeriod = daysSinceLast,
                daysUntilNextPeriod = daysUntilNext,
                currentDayOfCycle = daysSinceLast?.plus(1),
                isLoading = false
            )

            // Background sync
            syncInBackground()
        }
    }

    fun logPeriodStart() {
        viewModelScope.launch {
            val today = LocalDate.now()
            val newCycle = MenstrualCycle(
                id = UUID.randomUUID().toString(),
                userId = demoProfileId,
                startDate = today,
                synced = false
            )
            val updated = _uiState.value.cycles + newCycle
            repository.saveLocalCycles(updated)
            refreshState(updated)

            // Sync to cloud
            launch { syncCycleToCloud(newCycle) }
        }
    }

    fun logPeriodEnd() {
        viewModelScope.launch {
            val cycles = _uiState.value.cycles.toMutableList()
            val activeIndex = cycles.indexOfFirst { it.isActive }
            if (activeIndex >= 0) {
                val today = LocalDate.now()
                val active = cycles[activeIndex]
                val ended = active.copy(
                    endDate = today,
                    periodLength = java.time.temporal.ChronoUnit.DAYS.between(active.startDate, today).toInt() + 1,
                    synced = false
                )
                cycles[activeIndex] = ended
                repository.saveLocalCycles(cycles)
                refreshState(cycles)

                launch { syncCycleToCloud(ended) }
            }
        }
    }

    fun addDailyLog(
        flowLevel: FlowLevel,
        symptoms: List<MenstrualSymptom>,
        mood: MenstrualMood?,
        painLevel: Int,
        notes: String?
    ) {
        viewModelScope.launch {
            val date = _uiState.value.selectedDate
            val activeCycle = _uiState.value.cycles.firstOrNull { it.isActive }

            // Update existing log or create new
            val existingLogs = _uiState.value.dailyLogs.toMutableList()
            val existingIdx = existingLogs.indexOfFirst { it.date == date }

            val log = MenstrualDailyLog(
                id = if (existingIdx >= 0) existingLogs[existingIdx].id else UUID.randomUUID().toString(),
                cycleId = activeCycle?.id ?: "",
                date = date,
                flowLevel = flowLevel,
                symptoms = symptoms,
                mood = mood,
                painLevel = painLevel,
                notes = notes,
                synced = false
            )

            if (existingIdx >= 0) {
                existingLogs[existingIdx] = log
            } else {
                existingLogs.add(log)
            }

            repository.saveLocalDailyLogs(existingLogs)

            _uiState.value = _uiState.value.copy(
                dailyLogs = existingLogs,
                selectedDayLog = log,
                showDailyLogSheet = false
            )
            refreshCalendar()

            launch { syncDailyLogToCloud(log) }
        }
    }

    fun updateSettings(settings: MenstrualSettings) {
        viewModelScope.launch {
            repository.saveSettings(settings)
            _uiState.value = _uiState.value.copy(
                settings = settings,
                showSettingsSheet = false
            )
            refreshState(_uiState.value.cycles)

            launch {
                val profileId = resolveProfileId()
                repository.syncSettingsToCloud(settings, profileId)
            }
        }
    }

    fun selectDate(date: LocalDate) {
        val log = _uiState.value.dailyLogs.firstOrNull { it.date == date }
        _uiState.value = _uiState.value.copy(
            selectedDate = date,
            selectedDayLog = log
        )
    }

    fun navigateMonth(forward: Boolean) {
        val current = _uiState.value.selectedMonth
        val newMonth = if (forward) current.plusMonths(1) else current.minusMonths(1)
        _uiState.value = _uiState.value.copy(selectedMonth = newMonth)
        refreshCalendar()
    }

    fun showDailyLogSheet() {
        _uiState.value = _uiState.value.copy(showDailyLogSheet = true)
    }

    fun hideDailyLogSheet() {
        _uiState.value = _uiState.value.copy(showDailyLogSheet = false)
    }

    fun showSettingsSheet() {
        _uiState.value = _uiState.value.copy(showSettingsSheet = true)
    }

    fun hideSettingsSheet() {
        _uiState.value = _uiState.value.copy(showSettingsSheet = false)
    }

    fun showStatisticsSheet() {
        _uiState.value = _uiState.value.copy(showStatisticsSheet = true)
    }

    fun hideStatisticsSheet() {
        _uiState.value = _uiState.value.copy(showStatisticsSheet = false)
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    // ------------------------------------
    // MARK: - Private Helpers
    // ------------------------------------

    private fun refreshState(cycles: List<MenstrualCycle>) {
        val settings = _uiState.value.settings
        val dailyLogs = _uiState.value.dailyLogs
        val predictions = repository.calculatePredictions(cycles, settings)
        val statistics = repository.calculateStatistics(cycles)
        val currentPhase = repository.detectCurrentPhase(cycles, settings)

        val sorted = cycles.sortedByDescending { it.startDate }
        val lastCycle = sorted.firstOrNull()
        val today = LocalDate.now()

        val daysSinceLast = lastCycle?.let {
            java.time.temporal.ChronoUnit.DAYS.between(it.startDate, today).toInt()
        }
        val daysUntilNext = predictions?.let {
            java.time.temporal.ChronoUnit.DAYS.between(today, it.nextPeriodDate).toInt()
        }?.coerceAtLeast(0)

        val calendarData = repository.generateCalendarData(
            cycles, dailyLogs, predictions, _uiState.value.selectedMonth.atDay(1)
        )

        _uiState.value = _uiState.value.copy(
            cycles = cycles,
            currentPhase = currentPhase,
            predictions = predictions,
            statistics = statistics,
            calendarData = calendarData,
            daysSinceLastPeriod = daysSinceLast,
            daysUntilNextPeriod = daysUntilNext,
            currentDayOfCycle = daysSinceLast?.plus(1)
        )
    }

    private fun refreshCalendar() {
        val state = _uiState.value
        val calendarData = repository.generateCalendarData(
            state.cycles, state.dailyLogs, state.predictions, state.selectedMonth.atDay(1)
        )
        _uiState.value = _uiState.value.copy(calendarData = calendarData)
    }

    private suspend fun syncInBackground() {
        try {
            val profileId = resolveProfileId()
            val unsynced = _uiState.value.cycles.filter { !it.synced }
            if (unsynced.isNotEmpty()) {
                repository.syncCyclesToCloud(_uiState.value.cycles, profileId)
            }
            val unsyncedLogs = _uiState.value.dailyLogs.filter { !it.synced }
            if (unsyncedLogs.isNotEmpty()) {
                repository.syncDailyLogsToCloud(_uiState.value.dailyLogs, profileId)
            }
        } catch (_: Exception) { }
    }

    private suspend fun syncCycleToCloud(cycle: MenstrualCycle) {
        try {
            val profileId = resolveProfileId()
            repository.syncCyclesToCloud(listOf(cycle), profileId)
        } catch (_: Exception) { }
    }

    private suspend fun syncDailyLogToCloud(log: MenstrualDailyLog) {
        try {
            val profileId = resolveProfileId()
            repository.syncDailyLogsToCloud(listOf(log), profileId)
        } catch (_: Exception) { }
    }

    private suspend fun resolveProfileId(): String = try {
        profileRepository.getHealthProfile(demoProfileId)?.userId ?: demoProfileId
    } catch (_: Exception) { demoProfileId }
}
