package com.swastricare.health.ui.screens.family.member

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.repository.FamilyAlertPreferences
import com.swastricare.health.data.repository.FamilyAlertPreferencesRepository
import com.swastricare.health.domain.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class FamilyAlertPrefsState(
    val isLoading: Boolean = true,
    val isSaving: Boolean = false,
    val prefs: FamilyAlertPreferences? = null,
    val error: String? = null,
    val saveMessage: String? = null,
)

@HiltViewModel
class FamilyAlertPreferencesViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val repo: FamilyAlertPreferencesRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(FamilyAlertPrefsState())
    val state: StateFlow<FamilyAlertPrefsState> = _state.asStateFlow()

    private var caregiverUserId: String? = null
    private var targetProfileId: String? = null

    fun load(targetHealthProfileId: String) {
        targetProfileId = targetHealthProfileId
        _state.value = _state.value.copy(isLoading = true, error = null)
        viewModelScope.launch {
            val callerId = authRepository.getCurrentUser()?.id
            if (callerId == null) {
                _state.value = _state.value.copy(isLoading = false, error = "Not authenticated")
                return@launch
            }
            caregiverUserId = callerId

            repo.get(callerId, targetHealthProfileId)
                .onSuccess { existing ->
                    _state.value = _state.value.copy(
                        isLoading = false,
                        prefs = existing ?: FamilyAlertPreferences(
                            caregiverUserId = callerId,
                            targetHealthProfileId = targetHealthProfileId,
                        ),
                    )
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(isLoading = false, error = e.message ?: "Failed to load")
                }
        }
    }

    fun update(transform: (FamilyAlertPreferences) -> FamilyAlertPreferences) {
        val current = _state.value.prefs ?: return
        _state.value = _state.value.copy(prefs = transform(current))
    }

    fun save() {
        val prefs = _state.value.prefs ?: return
        _state.value = _state.value.copy(isSaving = true, saveMessage = null)
        viewModelScope.launch {
            repo.upsert(prefs)
                .onSuccess { _state.value = _state.value.copy(isSaving = false, saveMessage = "Saved") }
                .onFailure { e -> _state.value = _state.value.copy(isSaving = false, saveMessage = "Save failed: ${e.message}") }
        }
    }

    fun clearSaveMessage() { _state.value = _state.value.copy(saveMessage = null) }
}
