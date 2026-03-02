package com.swasthicare.mobile.ui.screens.family

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.models.FamilyGroup
import com.swasthicare.mobile.data.models.FamilyMember
import com.swasthicare.mobile.data.repository.FamilyRepository
import com.swasthicare.mobile.data.repository.AuthRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// -----------------------------------------------
// MARK: - UI State
// -----------------------------------------------

data class FamilyUiState(
    val familyGroup: FamilyGroup? = null,
    val members: List<FamilyMember> = emptyList(),
    val currentMember: FamilyMember? = null,
    val isLoading: Boolean = false,
    val isJoining: Boolean = false,
    val error: String? = null,
    val successMessage: String? = null,
    val inviteCode: String = "",
    val joinCode: String = "",
    val showLeaveConfirmation: Boolean = false
)

// -----------------------------------------------
// MARK: - ViewModel
// -----------------------------------------------

class FamilyViewModel(
    private val familyRepository: FamilyRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(FamilyUiState(isLoading = true))
    val uiState: StateFlow<FamilyUiState> = _uiState.asStateFlow()

    init {
        loadFamilyGroup()
    }

    fun loadFamilyGroup() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            try {
                val userId = authRepository.currentUser?.id ?: "demo-user-id"
                val group = familyRepository.getMyFamilyGroup(userId)

                if (group != null) {
                    val members = familyRepository.getMembers(group.id)
                    val currentMember = members.firstOrNull { it.userId == userId }
                    _uiState.update {
                        it.copy(
                            familyGroup = group,
                            members = members,
                            currentMember = currentMember,
                            inviteCode = group.inviteCode ?: "",
                            isLoading = false
                        )
                    }
                } else {
                    _uiState.update { it.copy(familyGroup = null, isLoading = false) }
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(error = e.message ?: "Failed to load family group", isLoading = false)
                }
            }
        }
    }

    fun updateJoinCode(code: String) {
        _uiState.update { it.copy(joinCode = code) }
    }

    fun joinWithCode() {
        val code = _uiState.value.joinCode.trim()
        if (code.isBlank()) {
            _uiState.update { it.copy(error = "Please enter an invite code") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isJoining = true, error = null) }
            try {
                val userId = authRepository.currentUser?.id ?: "demo-user-id"
                val fullName = authRepository.currentUser?.fullName
                val result = familyRepository.joinGroup(code, userId, fullName)
                result.fold(
                    onSuccess = { group ->
                        _uiState.update {
                            it.copy(
                                successMessage = "Joined ${group.name} successfully!",
                                isJoining = false,
                                joinCode = ""
                            )
                        }
                        loadFamilyGroup()
                    },
                    onFailure = { e ->
                        _uiState.update {
                            it.copy(
                                error = e.message ?: "Failed to join group",
                                isJoining = false
                            )
                        }
                    }
                )
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(error = e.message ?: "Failed to join group", isJoining = false)
                }
            }
        }
    }

    fun joinWithCode(code: String) {
        _uiState.update { it.copy(joinCode = code) }
        joinWithCode()
    }

    fun generateInviteCode() {
        val groupId = _uiState.value.familyGroup?.id ?: return
        viewModelScope.launch {
            try {
                val result = familyRepository.generateInviteCode(groupId)
                result.fold(
                    onSuccess = { invite ->
                        _uiState.update {
                            it.copy(
                                inviteCode = invite.code,
                                successMessage = "New invite code generated"
                            )
                        }
                    },
                    onFailure = { e ->
                        _uiState.update {
                            it.copy(error = e.message ?: "Failed to generate invite code")
                        }
                    }
                )
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message) }
            }
        }
    }

    fun showLeaveConfirmation() {
        _uiState.update { it.copy(showLeaveConfirmation = true) }
    }

    fun dismissLeaveConfirmation() {
        _uiState.update { it.copy(showLeaveConfirmation = false) }
    }

    fun leaveGroup() {
        val memberId = _uiState.value.currentMember?.id ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, showLeaveConfirmation = false) }
            try {
                val result = familyRepository.leaveGroup(memberId)
                result.fold(
                    onSuccess = {
                        _uiState.update {
                            it.copy(
                                familyGroup = null,
                                members = emptyList(),
                                currentMember = null,
                                inviteCode = "",
                                isLoading = false,
                                successMessage = "You have left the group"
                            )
                        }
                    },
                    onFailure = { e ->
                        _uiState.update {
                            it.copy(error = e.message ?: "Failed to leave group", isLoading = false)
                        }
                    }
                )
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message, isLoading = false) }
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    fun clearSuccess() {
        _uiState.update { it.copy(successMessage = null) }
    }
}
