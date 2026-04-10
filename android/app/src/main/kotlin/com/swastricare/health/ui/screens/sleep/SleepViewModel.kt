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
    val stats: SleepStats = SleepStats(),
    val error: String? = null
) {
    val filteredHistory: List<SleepSession>
        get() {
            val cutoff = LocalDate.now().minusDays(selectedRange.days.toLong())
            return sleepHistory.filter { it.date.isAfter(cutoff) || it.date == cutoff }
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

    private fun loadSleepData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            // Load today's session
            when (val todayResult = sleepRepository.getTodaySleepSession()) {
                is ResultWrapper.Success -> {
                    _uiState.update { it.copy(todaySession = todayResult.data) }

                    // Background cloud sync
                    todayResult.data?.let { session ->
                        syncToCloud(session)
                    }
                }
                is ResultWrapper.Error -> {
                    Log.w(TAG, "Failed to load today's sleep: ${todayResult.exception}")
                }
                is ResultWrapper.Loading -> { /* no-op */ }
            }

            // Load 30-day history
            val endDate = LocalDate.now()
            val startDate = endDate.minusDays(30)
            when (val historyResult = sleepRepository.getSleepSessions(startDate, endDate)) {
                is ResultWrapper.Success -> {
                    _uiState.update { it.copy(sleepHistory = historyResult.data) }
                }
                is ResultWrapper.Error -> {
                    Log.w(TAG, "Failed to load sleep history: ${historyResult.exception}")
                    _uiState.update { it.copy(error = "Unable to load sleep history") }
                }
                is ResultWrapper.Loading -> { /* no-op */ }
            }

            _uiState.update { it.copy(isLoading = false) }
            recalculateStats()
        }
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

    private fun syncToCloud(session: SleepSession) {
        viewModelScope.launch {
            try {
                val userId = authRepository.getCurrentUser()?.id ?: return@launch
                val healthProfile = profileRepository.getHealthProfile(userId) ?: return@launch
                val profileId = healthProfile.id ?: return@launch
                sleepRepository.syncToCloud(session, profileId)
            } catch (e: Exception) {
                Log.w(TAG, "Cloud sync failed: ${e.message}")
            }
        }
    }
}
