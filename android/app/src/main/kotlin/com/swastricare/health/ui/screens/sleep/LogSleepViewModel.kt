package com.swastricare.health.ui.screens.sleep

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.repository.SupabaseProfileRepository
import com.swastricare.health.domain.model.sleep.SleepSession
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.repository.SleepRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import javax.inject.Inject

data class LogSleepUiState(
    val selectedDate: LocalDate = LocalDate.now(),
    val durationMinutes: Int = 450,         // default 7h 30m
    val bedtimeMillis: Long = 0L,
    val wakeTimeMillis: Long = 0L,
    val notes: String = "",
    val disabledDates: Set<LocalDate> = emptySet(),
    val isSaving: Boolean = false,
    val saveSuccess: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class LogSleepViewModel @Inject constructor(
    private val sleepRepository: SleepRepository,
    private val authRepository: AuthRepository,
    private val profileRepository: SupabaseProfileRepository
) : ViewModel() {

    companion object {
        private const val TAG = "LogSleepViewModel"
    }

    private val _uiState = MutableStateFlow(LogSleepUiState())
    val uiState: StateFlow<LogSleepUiState> = _uiState.asStateFlow()

    init {
        initDefaultTimes()
        loadDisabledDates()
    }

    private fun initDefaultTimes() {
        // Wake = now rounded to nearest 30 min; bedtime = wake - duration
        val now = LocalTime.now()
        val roundedMinute = (now.minute / 30) * 30
        val wakeTime = now.withMinute(roundedMinute).withSecond(0).withNano(0)
        val bedTime = wakeTime.minusMinutes(_uiState.value.durationMinutes.toLong())

        val today = LocalDate.now()
        val zone = ZoneId.systemDefault()

        val wakeMillis = today.atTime(wakeTime).atZone(zone).toInstant().toEpochMilli()
        val bedMillis = today.atTime(bedTime).atZone(zone).toInstant().toEpochMilli()

        _uiState.update { it.copy(wakeTimeMillis = wakeMillis, bedtimeMillis = bedMillis) }
    }

    private fun loadDisabledDates() {
        viewModelScope.launch {
            try {
                val endDate = LocalDate.now()
                val startDate = endDate.minusDays(6)
                val result = sleepRepository.getSleepSessions(startDate, endDate)
                if (result is ResultWrapper.Success) {
                    val hcDates = result.data.map { it.date }.toSet()
                    _uiState.update { it.copy(disabledDates = hcDates) }
                    // If today is disabled, find first non-disabled date
                    if (hcDates.contains(endDate)) {
                        val firstAvailable = (0..6)
                            .map { endDate.minusDays(it.toLong()) }
                            .firstOrNull { !hcDates.contains(it) }
                        firstAvailable?.let { selectDate(it) }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not load HC dates: ${e.message}")
            }
        }
    }

    fun selectDate(date: LocalDate) {
        if (_uiState.value.disabledDates.contains(date)) return
        _uiState.update { state ->
            // Re-derive millis for the new date keeping same times-of-day
            val zone = ZoneId.systemDefault()
            val bedLocal = Instant.ofEpochMilli(state.bedtimeMillis)
                .atZone(zone).toLocalTime()
            val wakeLocal = Instant.ofEpochMilli(state.wakeTimeMillis)
                .atZone(zone).toLocalTime()
            val newBed = date.atTime(bedLocal).atZone(zone).toInstant().toEpochMilli()
            val newWake = date.atTime(wakeLocal).atZone(zone).toInstant().toEpochMilli()
            state.copy(selectedDate = date, bedtimeMillis = newBed, wakeTimeMillis = newWake)
        }
    }

    fun setDuration(minutes: Int) {
        _uiState.update { state ->
            // Anchor wake time, recalculate bedtime
            val newBedMillis = state.wakeTimeMillis - (minutes * 60_000L)
            state.copy(durationMinutes = minutes, bedtimeMillis = newBedMillis)
        }
    }

    fun setBedtime(millis: Long) {
        _uiState.update { state ->
            val durationMs = state.wakeTimeMillis - millis
            val newDuration = (durationMs / 60_000L).coerceIn(0L, 720L).toInt()
            state.copy(bedtimeMillis = millis, durationMinutes = newDuration)
        }
    }

    fun setWakeTime(millis: Long) {
        _uiState.update { state ->
            val durationMs = millis - state.bedtimeMillis
            val newDuration = (durationMs / 60_000L).coerceIn(0L, 720L).toInt()
            state.copy(wakeTimeMillis = millis, durationMinutes = newDuration)
        }
    }

    fun setNotes(text: String) {
        _uiState.update { it.copy(notes = text) }
    }

    fun save() {
        val state = _uiState.value
        if (state.durationMinutes <= 0 || state.isSaving) return

        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true, error = null) }
            try {
                val userId = authRepository.getCurrentUser()?.id ?: run {
                    _uiState.update { it.copy(isSaving = false, error = "Not logged in") }
                    return@launch
                }
                val healthProfile = profileRepository.getHealthProfile(userId) ?: run {
                    _uiState.update { it.copy(isSaving = false, error = "Profile not found") }
                    return@launch
                }
                val profileId = healthProfile.id ?: run {
                    _uiState.update { it.copy(isSaving = false, error = "Profile ID missing") }
                    return@launch
                }

                val session = SleepSession(
                    date = state.selectedDate,
                    startTimeEpochMillis = state.bedtimeMillis,
                    endTimeEpochMillis = state.wakeTimeMillis,
                    totalMinutes = state.durationMinutes
                )

                when (val result = sleepRepository.saveManualSession(session, profileId)) {
                    is ResultWrapper.Success -> {
                        _uiState.update { it.copy(isSaving = false, saveSuccess = true) }
                    }
                    is ResultWrapper.Error -> {
                        _uiState.update {
                            it.copy(isSaving = false, error = "Failed to save. Try again.")
                        }
                    }
                    else -> _uiState.update { it.copy(isSaving = false) }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Save failed", e)
                _uiState.update { it.copy(isSaving = false, error = "Unexpected error") }
            }
        }
    }
}
