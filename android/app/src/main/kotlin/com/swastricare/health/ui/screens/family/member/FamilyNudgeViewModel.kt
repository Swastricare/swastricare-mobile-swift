package com.swastricare.health.ui.screens.family.member

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.repository.FamilyNudgeRepository
import com.swastricare.health.data.repository.NudgePreset
import com.swastricare.health.data.repository.NudgeResponse
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.repository.FamilyRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * One-shot UI events emitted after a nudge send completes.
 * Surfaced via the screen's snackbar, then cleared via [FamilyNudgeViewModel.clearEvent]
 * so re-triggering works without stale recomposition.
 */
sealed class NudgeUiEvent {
    /**
     * Send succeeded. [deliveredViaPush] mirrors the edge function's `delivered`
     * field (true → FCM accepted, false → recipient offline / no token / opted out).
     * [reason] is the edge function's diagnostic ("no_token", "quiet_hours", …) when
     * `delivered=false`.
     */
    data class Success(val deliveredViaPush: Boolean, val reason: String?) : NudgeUiEvent()

    /** Send failed locally (network, missing recipient, validation, …). */
    data class Failure(val message: String) : NudgeUiEvent()
}

/**
 * UI state for the family nudge bottom sheet.
 *
 * [recipientUserId] is null until [FamilyNudgeViewModel.init] resolves the target
 * member from the caller's family group; the screen disables send actions while null.
 */
data class FamilyNudgeState(
    val memberName: String = "",
    val recipientUserId: String? = null,
    val targetHealthProfileId: String = "",
    val customMessage: String = "",
    val isSending: Boolean = false,
    val event: NudgeUiEvent? = null,
)

/**
 * Hosts the nudge bottom sheet's state + send actions.
 *
 * Resolves the target [com.swastricare.health.domain.model.FamilyMember] from the
 * caller's own family group (via [FamilyRepository.getMyFamilyGroup] +
 * [FamilyRepository.getMembers]) so we know the recipient's `auth.users.id` for
 * the FCM fan-out — `healthProfileId` alone is insufficient since edge fn needs userId.
 */
@HiltViewModel
class FamilyNudgeViewModel @Inject constructor(
    private val familyRepository: FamilyRepository,
    private val authRepository: AuthRepository,
    private val nudgeRepository: FamilyNudgeRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(FamilyNudgeState())
    val state: StateFlow<FamilyNudgeState> = _state.asStateFlow()

    fun init(targetHealthProfileId: String) {
        _state.value = _state.value.copy(targetHealthProfileId = targetHealthProfileId)
        viewModelScope.launch {
            runCatching {
                val callerUserId = authRepository.getCurrentUser()?.id ?: return@launch
                val group = familyRepository.getMyFamilyGroup(callerUserId).getOrNull()
                    ?: return@launch
                val members = familyRepository.getMembers(group.id).getOrNull().orEmpty()
                val target = members.firstOrNull { it.healthProfileId == targetHealthProfileId }
                _state.value = _state.value.copy(
                    memberName = target?.fullName.orEmpty(),
                    recipientUserId = target?.userId,
                )
            }
        }
    }

    fun setCustomMessage(text: String) {
        _state.value = _state.value.copy(customMessage = text.take(200))
    }

    fun sendPreset(preset: NudgePreset) {
        val recipient = _state.value.recipientUserId ?: run {
            emit(NudgeUiEvent.Failure("Member not loaded"))
            return
        }
        send {
            nudgeRepository.sendPreset(recipient, _state.value.targetHealthProfileId, preset)
        }
    }

    fun sendCustom() {
        val recipient = _state.value.recipientUserId ?: run {
            emit(NudgeUiEvent.Failure("Member not loaded"))
            return
        }
        val msg = _state.value.customMessage.trim()
        if (msg.isEmpty()) {
            emit(NudgeUiEvent.Failure("Message cannot be empty"))
            return
        }
        send {
            nudgeRepository.sendCustom(recipient, _state.value.targetHealthProfileId, msg)
        }
    }

    private fun send(block: suspend () -> Result<NudgeResponse>) {
        _state.value = _state.value.copy(isSending = true, event = null)
        viewModelScope.launch {
            val r = block()
            _state.value = _state.value.copy(isSending = false)
            r.fold(
                onSuccess = { resp ->
                    emit(NudgeUiEvent.Success(deliveredViaPush = resp.delivered, reason = resp.reason))
                    _state.value = _state.value.copy(customMessage = "")
                },
                onFailure = { e -> emit(NudgeUiEvent.Failure(e.message ?: "Send failed")) },
            )
        }
    }

    fun clearEvent() {
        _state.value = _state.value.copy(event = null)
    }

    private fun emit(event: NudgeUiEvent) {
        _state.value = _state.value.copy(event = event)
    }
}
