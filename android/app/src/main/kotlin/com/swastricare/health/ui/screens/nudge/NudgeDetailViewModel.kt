package com.swastricare.health.ui.screens.nudge

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.repository.FamilyNudgeRepository
import com.swastricare.health.data.repository.NudgeDetail
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class NudgeDetailState(
    val isLoading: Boolean = true,
    val nudge: NudgeDetail? = null,
    val error: String? = null,
    val isActing: Boolean = false,
)

@HiltViewModel
class NudgeDetailViewModel @Inject constructor(
    private val repo: FamilyNudgeRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(NudgeDetailState())
    val state: StateFlow<NudgeDetailState> = _state.asStateFlow()

    fun load(id: String) {
        _state.value = _state.value.copy(isLoading = true, error = null)
        viewModelScope.launch {
            repo.fetchById(id)
                .onSuccess { detail ->
                    _state.value = if (detail == null) {
                        NudgeDetailState(isLoading = false, error = "Nudge not found")
                    } else {
                        NudgeDetailState(isLoading = false, nudge = detail)
                    }
                }
                .onFailure { e ->
                    _state.value = NudgeDetailState(isLoading = false, error = e.message ?: "Failed to load nudge")
                }
        }
    }

    fun markActedOn(onDone: () -> Unit) {
        val id = _state.value.nudge?.id ?: return
        _state.value = _state.value.copy(isActing = true)
        viewModelScope.launch {
            repo.markActedOn(id)
            _state.value = _state.value.copy(isActing = false)
            onDone()
        }
    }

    fun dismiss(onDone: () -> Unit) {
        val id = _state.value.nudge?.id ?: return
        _state.value = _state.value.copy(isActing = true)
        viewModelScope.launch {
            repo.dismiss(id)
            _state.value = _state.value.copy(isActing = false)
            onDone()
        }
    }
}
