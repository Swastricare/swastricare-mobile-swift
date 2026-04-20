package com.swastricare.health.ui.screens.sleep

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.repository.SupabaseProfileRepository
import com.swastricare.health.domain.model.sleep.SleepSession
import com.swastricare.health.domain.model.sleep.SleepStats
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.repository.SleepRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalTime
import javax.inject.Inject
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

enum class SleepTimeRange(val label: String, val days: Int) {
    WEEK("Week", 7),
    MONTH("Month", 30)
}

data class SleepUiState(
    val isLoading: Boolean = true,
    val todaySession: SleepSession? = null,
    val sleepHistory: List<SleepSession> = emptyList(),
    val selectedRange: SleepTimeRange = SleepTimeRange.WEEK,
    val selectedDate: LocalDate = LocalDate.now(),
    val stats: SleepStats = SleepStats(),
    val error: String? = null
) {
    val filteredHistory: List<SleepSession>
        get() {
            val cutoff = LocalDate.now().minusDays(selectedRange.days.toLong())
            return sleepHistory.filter { it.date.isAfter(cutoff) || it.date == cutoff }
        }

    val selectedSession: SleepSession?
        get() = if (selectedDate == LocalDate.now()) {
            todaySession ?: sleepHistory.firstOrNull { it.date == selectedDate }
        } else {
            sleepHistory.firstOrNull { it.date == selectedDate }
        }
}

@HiltViewModel
class SleepViewModel @Inject constructor(
    private val sleepRepository: SleepRepository,
    private val authRepository: AuthRepository,
    private val profileRepository: SupabaseProfileRepository
) : ViewModel() {

    companion object {
        private const val TAG = "SleepViewModel"
    }

    private val _uiState = MutableStateFlow(SleepUiState())
    val uiState: StateFlow<SleepUiState> = _uiState.asStateFlow()

    init {
        loadSleepData()
    }

    fun selectTimeRange(range: SleepTimeRange) {
        _uiState.update { state ->
            state.copy(selectedRange = range)
        }
        recalculateStats()
    }

    fun selectDate(date: LocalDate) {
        _uiState.update { it.copy(selectedDate = date) }
    }

    /** Re-fetch sleep data — called when the screen becomes visible after a manual log. */
    fun refresh() {
        loadSleepData(showSpinner = false)
    }

    private fun loadSleepData(showSpinner: Boolean = true) {
        viewModelScope.launch {
            if (showSpinner) {
                _uiState.update { it.copy(isLoading = true, error = null) }
            } else {
                _uiState.update { it.copy(error = null) }
            }

            val profileId = resolveProfileId()

            // Load today's session from Health Connect
            var hcToday: SleepSession? = null
            when (val todayResult = sleepRepository.getTodaySleepSession()) {
                is ResultWrapper.Success -> hcToday = todayResult.data
                is ResultWrapper.Error ->
                    Log.w(TAG, "Failed to load today's sleep: ${todayResult.exception}")
                is ResultWrapper.Loading -> { /* no-op */ }
            }

            // Load 30-day history from Health Connect
            val endDate = LocalDate.now()
            val startDate = endDate.minusDays(30)
            var hcHistory: List<SleepSession> = emptyList()
            when (val historyResult = sleepRepository.getSleepSessions(startDate, endDate)) {
                is ResultWrapper.Success -> hcHistory = historyResult.data
                is ResultWrapper.Error -> {
                    Log.w(TAG, "Failed to load sleep history: ${historyResult.exception}")
                    _uiState.update { it.copy(error = "Unable to load sleep history") }
                }
                is ResultWrapper.Loading -> { /* no-op */ }
            }

            // Fetch cloud (Supabase) sessions for the same window
            val supabaseSessions = if (profileId != null) {
                fetchSupabaseSessions(profileId, startDate, endDate)
            } else emptyList()

            // Push every available Health Connect session to Supabase so the cloud
            // mirror stays current (including historical nights, not just today).
            if (profileId != null) {
                pushHealthConnectToCloud(profileId, hcToday, hcHistory)
            }

            // Display: HC wins per-date (has stage data), Supabase fills gaps.
            val mergedHistory = mergeSessions(hcHistory, supabaseSessions)
            val mergedToday = hcToday ?: supabaseSessions.firstOrNull { it.date == endDate }

            _uiState.update {
                it.copy(
                    todaySession = mergedToday,
                    sleepHistory = mergedHistory,
                    isLoading = false
                )
            }
            recalculateStats()
        }
    }

    private suspend fun resolveProfileId(): String? {
        return try {
            val userId = authRepository.getCurrentUser()?.id ?: return null
            profileRepository.getHealthProfile(userId)?.id
        } catch (e: Exception) {
            Log.w(TAG, "Profile lookup failed: ${e.message}")
            null
        }
    }

    private suspend fun fetchSupabaseSessions(
        profileId: String,
        startDate: LocalDate,
        endDate: LocalDate
    ): List<SleepSession> {
        return when (val r = sleepRepository.getSupabaseSleepSessions(profileId, startDate, endDate)) {
            is ResultWrapper.Success -> r.data
            is ResultWrapper.Error -> {
                Log.w(TAG, "Failed to load Supabase sleep: ${r.exception}")
                emptyList()
            }
            else -> emptyList()
        }
    }

    private fun pushHealthConnectToCloud(
        profileId: String,
        today: SleepSession?,
        history: List<SleepSession>
    ) {
        val sessions = (history + listOfNotNull(today))
            .distinctBy { it.date }
            .filter { it.totalMinutes > 0 }
        if (sessions.isEmpty()) return

        viewModelScope.launch {
            sessions.forEach { session ->
                when (val r = sleepRepository.syncToCloud(session, profileId)) {
                    is ResultWrapper.Error ->
                        Log.w(TAG, "HC → cloud sync failed for ${session.date}: ${r.exception}")
                    else -> { /* ok */ }
                }
            }
        }
    }

    private fun mergeSessions(
        hc: List<SleepSession>,
        supabase: List<SleepSession>
    ): List<SleepSession> {
        val byDate = hc.associateBy { it.date }.toMutableMap()
        supabase.forEach { s -> byDate.putIfAbsent(s.date, s) }
        return byDate.values.sortedBy { it.date }
    }

    private fun recalculateStats() {
        val sessions = _uiState.value.filteredHistory
        if (sessions.isEmpty()) {
            _uiState.update { it.copy(stats = SleepStats()) }
            return
        }

        val avgMinutes = sessions.map { it.totalMinutes }.average().roundToInt()
        val bestNight = sessions.maxOf { it.totalMinutes }

        // Consistency score: based on standard deviation of sleep duration
        val mean = sessions.map { it.totalMinutes.toDouble() }.average()
        val variance = sessions.map { (it.totalMinutes - mean) * (it.totalMinutes - mean) }.average()
        val stdDev = kotlin.math.sqrt(variance)
        // Lower std dev = higher consistency. 0 min std dev = 100%, 120+ min = 0%
        val consistency = ((1.0 - (stdDev / 120.0).coerceAtMost(1.0)) * 100).roundToInt()

        // Average bedtime using circular mean (handles midnight crossover)
        val avgBedtime = circularMeanTime(sessions.mapNotNull { it.bedtime })
        val avgWakeTime = circularMeanTime(sessions.mapNotNull { it.wakeTime })

        _uiState.update {
            it.copy(
                stats = SleepStats(
                    averageSleepMinutes = avgMinutes,
                    bestNightMinutes = bestNight,
                    consistencyScore = consistency,
                    avgBedtime = avgBedtime,
                    avgWakeTime = avgWakeTime
                )
            )
        }
    }

    /**
     * Computes circular mean of times to correctly handle midnight crossover.
     * e.g. 23:30 and 00:30 should average to midnight, not noon.
     */
    private fun circularMeanTime(times: List<LocalTime>): LocalTime? {
        if (times.isEmpty()) return null

        var sinSum = 0.0
        var cosSum = 0.0
        for (time in times) {
            val secondsOfDay = time.toSecondOfDay().toDouble()
            val angle = secondsOfDay / 86400.0 * 2.0 * Math.PI
            sinSum += sin(angle)
            cosSum += cos(angle)
        }
        sinSum /= times.size
        cosSum /= times.size

        var avgAngle = atan2(sinSum, cosSum)
        if (avgAngle < 0) avgAngle += 2.0 * Math.PI

        val avgSeconds = (avgAngle / (2.0 * Math.PI) * 86400.0).roundToInt() % 86400
        return LocalTime.ofSecondOfDay(avgSeconds.toLong())
    }

}
