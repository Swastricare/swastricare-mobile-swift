package com.swastricare.health.ui.screens.family

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.UserFriendlyError
import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.usecase.family.AcceptInvitationUseCase
import com.swastricare.health.domain.usecase.family.CreateFamilyGroupUseCase
import com.swastricare.health.domain.usecase.family.GetFamilyMembersUseCase
import com.swastricare.health.domain.usecase.family.InviteMemberUseCase
import com.swastricare.health.domain.usecase.family.LeaveFamilyGroupUseCase
import com.swastricare.health.domain.usecase.family.RemoveMemberUseCase
import com.swastricare.health.domain.usecase.family.UpdatePermissionsUseCase
import com.swastricare.health.domain.repository.FamilyRepository
import com.swastricare.health.presentation.feature.family.FamilyUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for Family screen.
 * Migrated to Clean Architecture with Hilt dependency injection.
 */
@HiltViewModel
class FamilyViewModel @Inject constructor(
    private val familyRepository: FamilyRepository,
    private val authRepository: AuthRepository,
    private val createFamilyGroupUseCase: CreateFamilyGroupUseCase,
    private val acceptInvitationUseCase: AcceptInvitationUseCase,
    private val getFamilyMembersUseCase: GetFamilyMembersUseCase,
    private val inviteMemberUseCase: InviteMemberUseCase,
    private val leaveFamilyGroupUseCase: LeaveFamilyGroupUseCase,
    private val removeMemberUseCase: RemoveMemberUseCase,
    private val updatePermissionsUseCase: UpdatePermissionsUseCase,
    private val logger: Logger,
    private val analyticsService: AppAnalyticsService
) : ViewModel() {

    private val tag = "FamilyViewModel"

    private val _uiState = MutableStateFlow(FamilyUiState(isLoading = true))
    val uiState: StateFlow<FamilyUiState> = _uiState.asStateFlow()

    init {
        loadFamilyGroup()
    }

    // ── Load Family Data ──

    fun loadFamilyGroup() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            val userId = authRepository.getCurrentUser()?.id
            if (userId == null) {
                logger.w(tag, "No user logged in")
                _uiState.update {
                    it.copy(isLoading = false, error = "Please log in first")
                }
                return@launch
            }

            when (val result = familyRepository.getMyFamilyGroup(userId)) {
                is ResultWrapper.Success -> {
                    val group = result.data
                    if (group != null) {
                        loadMembers(group.id, userId)
                    } else {
                        logger.d(tag, "User not in any family group")
                        _uiState.update {
                            it.copy(familyGroup = null, members = emptyList(), isLoading = false)
                        }
                    }
                }
                is ResultWrapper.Error -> {
                    logger.e(tag, "Error loading family group: ${result.exception.message}")
                    _uiState.update {
                        it.copy(
                            error = "Unable to load family group.",
                            isLoading = false
                        )
                    }
                }
                is ResultWrapper.Loading -> {
                    // Already in loading state
                }
            }
        }
    }

    private suspend fun loadMembers(groupId: String, userId: String) {
        when (val membersResult = getFamilyMembersUseCase(groupId, userId)) {
            is ResultWrapper.Success -> {
                val members = membersResult.data
                val currentMember = members.firstOrNull { it.userId == userId }

                // Get the group again to have latest data
                when (val groupResult = familyRepository.getMyFamilyGroup(userId)) {
                    is ResultWrapper.Success -> {
                        val group = groupResult.data
                        _uiState.update {
                            it.copy(
                                familyGroup = group,
                                members = members,
                                currentMember = currentMember,
                                inviteCode = group?.inviteCode ?: "",
                                isLoading = false
                            )
                        }
                        logger.i(tag, "Family data loaded: ${members.size} members")
                    }
                    is ResultWrapper.Error -> {
                        _uiState.update {
                            it.copy(
                                error = "Unable to load family group.",
                                isLoading = false
                            )
                        }
                    }
                    is ResultWrapper.Loading -> {}
                }
            }
            is ResultWrapper.Error -> {
                logger.e(tag, "Error loading members: ${membersResult.exception.message}")
                _uiState.update {
                    it.copy(
                        error = "Unable to load members.",
                        isLoading = false
                    )
                }
            }
            is ResultWrapper.Loading -> {}
        }
    }

    // ── Create Family Group ──

    fun createFamilyGroup(name: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            val userId = authRepository.getCurrentUser()?.id
            if (userId == null) {
                _uiState.update {
                    it.copy(isLoading = false, error = "Please log in first")
                }
                return@launch
            }

            when (val result = createFamilyGroupUseCase(name, userId)) {
                is ResultWrapper.Success -> {
                    logger.i(tag, "Family group created: ${result.data.id}")
                    analyticsService.trackFamilyCreated()
                    _uiState.update {
                        it.copy(
                            successMessage = "Family group '${result.data.name}' created successfully!",
                            isLoading = false
                        )
                    }
                    loadFamilyGroup()
                }
                is ResultWrapper.Error -> {
                    logger.e(tag, "Error creating family group: ${result.exception.message}")
                    _uiState.update {
                        it.copy(
                            error = "Unable to create family group.",
                            isLoading = false
                        )
                    }
                }
                is ResultWrapper.Loading -> {}
            }
        }
    }

    // ── Join Family Group ──

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

            val currentUser = authRepository.getCurrentUser()
            val userId = currentUser?.id
            if (userId == null) {
                _uiState.update {
                    it.copy(isJoining = false, error = "Please log in first")
                }
                return@launch
            }

            val fullName = currentUser.fullName

            when (val result = acceptInvitationUseCase(code, userId, fullName)) {
                is ResultWrapper.Success -> {
                    logger.i(tag, "Joined family group: ${result.data.id}")
                    analyticsService.trackFamilyJoined()
                    _uiState.update {
                        it.copy(
                            successMessage = "Joined ${result.data.name} successfully!",
                            isJoining = false,
                            joinCode = ""
                        )
                    }
                    loadFamilyGroup()
                }
                is ResultWrapper.Error -> {
                    logger.e(tag, "Error joining group: ${result.exception.message}")
                    _uiState.update {
                        it.copy(
                            error = "Unable to join family.",
                            isJoining = false
                        )
                    }
                }
                is ResultWrapper.Loading -> {}
            }
        }
    }

    fun joinWithCode(code: String) {
        _uiState.update { it.copy(joinCode = code) }
        joinWithCode()
    }

    // ── Generate Invite Code ──

    fun generateInviteCode() {
        val groupId = _uiState.value.familyGroup?.id
        if (groupId == null) {
            logger.w(tag, "No family group to generate invite for")
            return
        }

        viewModelScope.launch {
            val userId = authRepository.getCurrentUser()?.id
            if (userId == null) {
                _uiState.update { it.copy(error = "Please log in first") }
                return@launch
            }

            _uiState.update { it.copy(isGeneratingCode = true, error = null) }

            when (val result = inviteMemberUseCase(groupId, userId)) {
                is ResultWrapper.Success -> {
                    logger.i(tag, "Invite code generated: ${result.data.code}")
                    _uiState.update {
                        it.copy(
                            inviteCode = result.data.code,
                            successMessage = "New invite code generated",
                            isGeneratingCode = false
                        )
                    }
                }
                is ResultWrapper.Error -> {
                    logger.e(tag, "Error generating invite code: ${result.exception.message}")
                    _uiState.update {
                        it.copy(
                            error = "Unable to generate invite code.",
                            isGeneratingCode = false
                        )
                    }
                }
                is ResultWrapper.Loading -> {}
            }
        }
    }

    // ── Leave Family Group ──

    fun showLeaveConfirmation() {
        _uiState.update { it.copy(showLeaveConfirmation = true) }
    }

    fun dismissLeaveConfirmation() {
        _uiState.update { it.copy(showLeaveConfirmation = false) }
    }

    fun leaveGroup() {
        val member = _uiState.value.currentMember
        val groupId = _uiState.value.familyGroup?.id

        if (member == null || groupId == null) {
            logger.w(tag, "Cannot leave group: member or group not found")
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, showLeaveConfirmation = false, error = null) }

            when (val result = leaveFamilyGroupUseCase(member.id, groupId)) {
                is ResultWrapper.Success -> {
                    logger.i(tag, "Left family group successfully")
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
                }
                is ResultWrapper.Error -> {
                    logger.e(tag, "Error leaving group: ${result.exception.message}")
                    _uiState.update {
                        it.copy(
                            error = "Unable to leave family.",
                            isLoading = false
                        )
                    }
                }
                is ResultWrapper.Loading -> {}
            }
        }
    }

    // ── Remove Member ──

    fun showRemoveMemberDialog(member: com.swastricare.health.domain.model.FamilyMember) {
        _uiState.update { it.copy(showRemoveMemberDialog = true, memberToRemove = member) }
    }

    fun dismissRemoveMemberDialog() {
        _uiState.update { it.copy(showRemoveMemberDialog = false, memberToRemove = null) }
    }

    fun removeMember() {
        val memberToRemove = _uiState.value.memberToRemove

        viewModelScope.launch {
            val userId = authRepository.getCurrentUser()?.id

            if (memberToRemove == null || userId == null) {
                logger.w(tag, "Cannot remove member: member or user not found")
                return@launch
            }

            _uiState.update { it.copy(isLoading = true, showRemoveMemberDialog = false, error = null) }

            when (val result = removeMemberUseCase(memberToRemove.id, userId)) {
                is ResultWrapper.Success -> {
                    logger.i(tag, "Member removed successfully")
                    _uiState.update {
                        it.copy(
                            successMessage = "${memberToRemove.fullName ?: "Member"} removed from the group",
                            memberToRemove = null,
                            isLoading = false
                        )
                    }
                    loadFamilyGroup()
                }
                is ResultWrapper.Error -> {
                    logger.e(tag, "Error removing member: ${result.exception.message}")
                    _uiState.update {
                        it.copy(
                            error = "Unable to remove member.",
                            memberToRemove = null,
                            isLoading = false
                        )
                    }
                }
                is ResultWrapper.Loading -> {}
            }
        }
    }

    // ── Clear Messages ──

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    fun clearSuccess() {
        _uiState.update { it.copy(successMessage = null) }
    }

    fun trackFamilyMemberViewed() {
        analyticsService.trackFamilyMemberViewed()
    }

    fun trackFamilyInviteSent() {
        analyticsService.trackFamilyInviteSent()
    }
}
