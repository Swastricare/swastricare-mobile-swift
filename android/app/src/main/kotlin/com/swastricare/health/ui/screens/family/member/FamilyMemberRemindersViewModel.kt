package com.swastricare.health.ui.screens.family.member

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.domain.model.MedicationWithSchedule
import com.swastricare.health.domain.repository.MedicationRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for the Family Member Reminders screen (Batch J).
 *
 * Loads every active medication schedule for a family member and exposes
 * mutations for the two v1-editable fields:
 *   1. `time_of_day` (daily schedules only)
 *   2. `reminder_enabled` (any schedule)
 *
 * All mutations re-load the list on success so the UI always reflects the
 * authoritative server state.
 */
@HiltViewModel
class FamilyMemberRemindersViewModel @Inject constructor(
    private val medicationRepository: MedicationRepository,
) : ViewModel() {

    data class State(
        val isLoading: Boolean = true,
        val schedules: List<MedicationWithSchedule> = emptyList(),
        val error: String? = null,
        val permissionDenied: Boolean = false,
        val savingScheduleId: String? = null,
        val message: String? = null,
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    fun load(profileId: String) {
        _state.value = _state.value.copy(isLoading = true, error = null)
        viewModelScope.launch {
            medicationRepository.listMedicationsForProfile(profileId)
                .onSuccess { list ->
                    _state.value = _state.value.copy(
                        isLoading = false,
                        schedules = list,
                        error = null,
                        permissionDenied = false,
                    )
                }
                .onFailure { e ->
                    val denied = isPermissionError(e)
                    _state.value = _state.value.copy(
                        isLoading = false,
                        error = e.message,
                        permissionDenied = denied,
                    )
                }
        }
    }

    fun updateTime(scheduleId: String, newTime: String, profileId: String) {
        _state.value = _state.value.copy(savingScheduleId = scheduleId)
        viewModelScope.launch {
            medicationRepository.updateScheduleTime(scheduleId, newTime)
                .onSuccess {
                    _state.value = _state.value.copy(
                        savingScheduleId = null,
                        message = "Time updated",
                    )
                    load(profileId)
                }
                .onFailure { e ->
                    val msg = if (isPermissionError(e)) {
                        "You don't have edit permission for this member"
                    } else {
                        "Update failed: ${e.message}"
                    }
                    _state.value = _state.value.copy(
                        savingScheduleId = null,
                        message = msg,
                    )
                }
        }
    }

    fun setReminderEnabled(scheduleId: String, enabled: Boolean, profileId: String) {
        _state.value = _state.value.copy(savingScheduleId = scheduleId)
        viewModelScope.launch {
            medicationRepository.setReminderEnabled(scheduleId, enabled)
                .onSuccess {
                    _state.value = _state.value.copy(savingScheduleId = null)
                    load(profileId)
                }
                .onFailure { e ->
                    val msg = if (isPermissionError(e)) {
                        "You don't have edit permission for this member"
                    } else {
                        "Toggle failed: ${e.message}"
                    }
                    _state.value = _state.value.copy(
                        savingScheduleId = null,
                        message = msg,
                    )
                }
        }
    }

    fun clearMessage() {
        _state.value = _state.value.copy(message = null)
    }

    private fun isPermissionError(e: Throwable): Boolean {
        val msg = e.message ?: return false
        return msg.contains("policy", ignoreCase = true)
            || msg.contains("permission", ignoreCase = true)
            || msg.contains("denied", ignoreCase = true)
            || msg.contains("42501") // postgres insufficient_privilege
    }
}
