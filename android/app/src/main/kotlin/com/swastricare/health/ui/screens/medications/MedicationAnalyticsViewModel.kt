package com.swastricare.health.ui.screens.medications

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.models.*
import com.swastricare.health.data.repository.SupabaseMedicationRepository
import com.swastricare.health.data.repository.SupabaseProfileRepository
import com.swastricare.health.domain.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import javax.inject.Inject

// ─────────────────────────────────────
// MARK: - Models
// ─────────────────────────────────────

enum class MedAnalyticsPeriod(val label: String, val days: Int) {
    WEEK("This Week", 7),
    MONTH("This Month", 30),
    THREE_MONTHS("3 Months", 90)
}

data class DailyAdherencePoint(
    val date: LocalDate,
    val percentage: Float,
    val taken: Int,
    val total: Int
)

data class MedicationAnalyticsState(
    val isLoading: Boolean = true,
    val period: MedAnalyticsPeriod = MedAnalyticsPeriod.MONTH,
    val adherencePercent: Int = 0,
    val dosesTaken: Int = 0,
    val daysOnTrack: Int = 0,
    val remindersSkipped: Int = 0,
    val dailyAdherence: List<DailyAdherencePoint> = emptyList(),
    val donutTaken: Int = 0,
    val donutMissed: Int = 0,
    val donutUpcoming: Int = 0,
    val calendarMonth: LocalDate = LocalDate.now().withDayOfMonth(1),
    val calendarData: Map<LocalDate, Float?> = emptyMap(),
    val calendarSelectedDate: LocalDate = LocalDate.now(),
    val calendarDoses: List<MedicationDose> = emptyList(),
    val error: String? = null
)

// ─────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────

@HiltViewModel
class MedicationAnalyticsViewModel @Inject constructor(
    private val repository: SupabaseMedicationRepository,
    private val profileRepository: SupabaseProfileRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _state = MutableStateFlow(MedicationAnalyticsState())
    val state: StateFlow<MedicationAnalyticsState> = _state.asStateFlow()

    init {
        loadAll()
    }

    fun setPeriod(period: MedAnalyticsPeriod) {
        _state.value = _state.value.copy(period = period)
        loadAll()
    }

    fun navigateCalendarMonth(delta: Int) {
        val newMonth = _state.value.calendarMonth.plusMonths(delta.toLong())
        _state.value = _state.value.copy(calendarMonth = newMonth)
        loadCalendarMonth(newMonth)
    }

    fun selectCalendarDate(date: LocalDate) {
        viewModelScope.launch {
            val profileId = resolveProfileId() ?: return@launch
            val medications = repository.fetchMedications(profileId)
            val schedules = repository.fetchSchedules(profileId)
            val logs = repository.fetchTodayLogs(profileId, date)
            val activeMeds = medications.filter { it.status == "active" }
            val doses = activeMeds.flatMap { med ->
                schedules.filter { it.medicationId == med.id }
                    .flatMap { s -> s.buildDosesForDate(med, date, logs) }
            }.sortedBy { it.scheduledTime }
            _state.value = _state.value.copy(calendarSelectedDate = date, calendarDoses = doses)
        }
    }

    private fun loadCalendarMonth(monthStart: LocalDate) {
        viewModelScope.launch {
            val profileId = resolveProfileId() ?: return@launch
            val monthEnd = monthStart.plusMonths(1).minusDays(1)
            val logs = repository.fetchLogsForDateRange(profileId, monthStart, monthEnd)
            val calendarMap = buildCalendarMap(monthStart, monthEnd, logs)
            _state.value = _state.value.copy(calendarData = calendarMap)
        }
    }

    private fun loadAll() {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)
            try {
                val profileId = resolveProfileId() ?: run {
                    _state.value = _state.value.copy(isLoading = false, error = "Not logged in")
                    return@launch
                }
                val today = LocalDate.now()
                val period = _state.value.period
                val startDate = today.minusDays(period.days.toLong() - 1)

                val medications = repository.fetchMedications(profileId)
                val schedules = repository.fetchSchedules(profileId)
                val periodLogs = repository.fetchLogsForDateRange(profileId, startDate, today)
                val activeMeds = medications.filter { it.status == "active" }

                // Build daily adherence points
                val dailyPoints = mutableListOf<DailyAdherencePoint>()
                var totalTaken = 0
                var totalMissed = 0
                var totalSkipped = 0
                var daysOnTrack = 0
                val activeSchedules = schedules.filter { s -> activeMeds.any { it.id == s.medicationId } }

                for (dayOffset in 0 until period.days) {
                    val date = startDate.plusDays(dayOffset.toLong())
                    if (date.isAfter(today)) break
                    val dayStr = date.format(DateTimeFormatter.ISO_LOCAL_DATE)
                    val dayLogs = periodLogs.filter { it.scheduledTime?.startsWith(dayStr) == true }
                    val dayTaken = dayLogs.count { it.status == "taken" }
                    val dayMissed = dayLogs.count { it.status == "missed" }
                    val daySkipped = dayLogs.count { it.status == "skipped" }
                    totalTaken += dayTaken
                    totalMissed += dayMissed
                    totalSkipped += daySkipped
                    val expectedDoses = activeSchedules.size
                    val dayTotal = maxOf(expectedDoses, dayTaken + dayMissed)
                    val pct = if (dayTotal > 0) (dayTaken.toFloat() / dayTotal * 100f) else 0f
                    dailyPoints.add(DailyAdherencePoint(date, pct, dayTaken, dayTotal))
                    if (pct >= 80f) daysOnTrack++
                }

                val totalDoses = totalTaken + totalMissed
                val adherencePct = if (totalDoses > 0) (totalTaken * 100 / totalDoses) else 0

                // Today's doses for donut upcoming count
                val todayLogs = repository.fetchTodayLogs(profileId, today)
                val todayDoses = activeMeds.flatMap { med ->
                    schedules.filter { it.medicationId == med.id }
                        .flatMap { s -> s.buildDosesForDate(med, today, todayLogs) }
                }.sortedBy { it.scheduledTime }
                val upcoming = todayDoses.count { it.status == AdherenceStatus.PENDING }

                // Calendar for current month
                val monthStart = _state.value.calendarMonth
                val monthEnd = monthStart.plusMonths(1).minusDays(1)
                val monthLogs = repository.fetchLogsForDateRange(profileId, monthStart, monthEnd)
                val calendarMap = buildCalendarMap(monthStart, monthEnd, monthLogs)

                _state.value = _state.value.copy(
                    isLoading = false,
                    adherencePercent = adherencePct,
                    dosesTaken = totalTaken,
                    daysOnTrack = daysOnTrack,
                    remindersSkipped = totalSkipped,
                    dailyAdherence = dailyPoints,
                    donutTaken = totalTaken,
                    donutMissed = totalMissed,
                    donutUpcoming = upcoming,
                    calendarData = calendarMap,
                    calendarSelectedDate = today,
                    calendarDoses = todayDoses
                )
            } catch (e: Exception) {
                _state.value = _state.value.copy(isLoading = false, error = "Failed to load analytics")
            }
        }
    }

    private fun buildCalendarMap(
        start: LocalDate,
        end: LocalDate,
        logs: List<MedicationLogDto>
    ): Map<LocalDate, Float?> {
        val map = mutableMapOf<LocalDate, Float?>()
        var d = start
        while (!d.isAfter(end)) {
            val dayStr = d.format(DateTimeFormatter.ISO_LOCAL_DATE)
            val dayLogs = logs.filter { it.scheduledTime?.startsWith(dayStr) == true }
            if (dayLogs.isEmpty()) {
                map[d] = null
            } else {
                val taken = dayLogs.count { it.status == "taken" }
                map[d] = taken.toFloat() / dayLogs.size
            }
            d = d.plusDays(1)
        }
        return map
    }

    private suspend fun resolveProfileId(): String? = try {
        val userId = authRepository.getCurrentUser()?.id ?: return null
        profileRepository.getHealthProfile(userId)?.id
    } catch (e: Exception) { null }
}
