package com.swastricare.health.presentation.feature.family

import com.swastricare.health.domain.model.FamilyGroup
import com.swastricare.health.domain.model.FamilyMember

/**
 * UI state for Family screen.
 * Following Clean Architecture presentation layer patterns.
 */
data class FamilyUiState(
    val familyGroup: FamilyGroup? = null,
    val members: List<FamilyMember> = emptyList(),
    val currentMember: FamilyMember? = null,
    val isLoading: Boolean = false,
    val isJoining: Boolean = false,
    val isGeneratingCode: Boolean = false,
    val error: String? = null,
    val successMessage: String? = null,
    val inviteCode: String = "",
    val joinCode: String = "",
    val showLeaveConfirmation: Boolean = false,
    val showRemoveMemberDialog: Boolean = false,
    val memberToRemove: FamilyMember? = null
) {
    val hasFamily: Boolean
        get() = familyGroup != null

    val canManageMembers: Boolean
        get() = currentMember?.canManageMembers == true

    val canGenerateInvites: Boolean
        get() = currentMember?.canGenerateInvites == true

    val isOwner: Boolean
        get() = currentMember?.isOwner == true
}
