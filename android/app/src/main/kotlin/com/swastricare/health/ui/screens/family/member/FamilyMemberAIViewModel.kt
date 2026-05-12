package com.swastricare.health.ui.screens.family.member

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.models.ChatMessage
import com.swastricare.health.data.repository.FamilyMemberContextBuilder
import com.swastricare.health.data.services.AIService
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.repository.FamilyRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class FamilyMemberAIState(
    val healthProfileId: String = "",
    val memberName: String? = null,
    val messages: List<ChatMessage> = emptyList(),
    val inputText: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
)

/**
 * ViewModel for the family-member-scoped AI chat screen. Keeps its own message
 * list (does not persist) so the personal-AI conversation history stays isolated.
 *
 * The actual prompt enrichment happens in `AIService.sendChatMessageForMember`,
 * which calls `FamilyMemberContextBuilder` under the caller's RLS session.
 */
@HiltViewModel
class FamilyMemberAIViewModel @Inject constructor(
    private val aiService: AIService,
    private val familyRepository: FamilyRepository,
    private val authRepository: AuthRepository,
    private val contextBuilder: FamilyMemberContextBuilder,
) : ViewModel() {

    private val _state = MutableStateFlow(FamilyMemberAIState())
    val state: StateFlow<FamilyMemberAIState> = _state.asStateFlow()

    fun init(healthProfileId: String) {
        if (_state.value.healthProfileId == healthProfileId && _state.value.memberName != null) return
        _state.value = _state.value.copy(healthProfileId = healthProfileId)
        loadMemberName(healthProfileId)
    }

    private fun loadMemberName(healthProfileId: String) {
        viewModelScope.launch {
            try {
                val callerId = authRepository.getCurrentUser()?.id ?: return@launch
                val group = familyRepository.getMyFamilyGroup(callerId).getOrNull() ?: return@launch
                val members = familyRepository.getMembers(group.id).getOrNull().orEmpty()
                val match = members.firstOrNull { it.healthProfileId == healthProfileId }
                _state.value = _state.value.copy(memberName = match?.fullName)
            } catch (e: Exception) {
                Log.w("FamilyMemberAIVM", "loadMemberName failed: ${e.message}")
            }
        }
    }

    fun onInputChanged(text: String) {
        _state.value = _state.value.copy(inputText = text)
    }

    fun sendMessage() {
        val text = _state.value.inputText.trim()
        if (text.isEmpty() || _state.value.isLoading) return
        val targetProfileId = _state.value.healthProfileId.takeIf { it.isNotBlank() } ?: return

        val priorMessages = _state.value.messages.filter { !it.isLoading }
        val newMessages = _state.value.messages.toMutableList().apply {
            add(ChatMessage.userMessage(text))
            add(ChatMessage.loadingMessage())
        }
        _state.value = _state.value.copy(
            messages = newMessages,
            inputText = "",
            isLoading = true,
            error = null,
        )

        viewModelScope.launch {
            try {
                // Build today's snapshot for the target member. Runs under the caller's
                // session, so RLS bounds what we can read. Empty string on no access.
                val healthContext = contextBuilder.build(targetProfileId).takeIf { it.isNotBlank() }
                val response = aiService.sendChatMessage(
                    message = text,
                    context = priorMessages,
                    healthContext = healthContext,
                )
                val withoutLoading = _state.value.messages.filter { !it.isLoading }.toMutableList()
                withoutLoading.add(ChatMessage.assistantMessage(response))
                _state.value = _state.value.copy(
                    messages = withoutLoading,
                    isLoading = false,
                )
            } catch (e: Exception) {
                Log.w("FamilyMemberAIVM", "sendMessage failed", e)
                val withoutLoading = _state.value.messages.filter { !it.isLoading }.toMutableList()
                withoutLoading.add(
                    ChatMessage.assistantMessage(
                        "I'm having trouble connecting right now. Please try again in a moment."
                    )
                )
                _state.value = _state.value.copy(
                    messages = withoutLoading,
                    isLoading = false,
                    error = e.message,
                )
            }
        }
    }
}
