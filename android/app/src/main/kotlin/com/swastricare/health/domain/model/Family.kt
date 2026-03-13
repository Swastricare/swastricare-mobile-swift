package com.swastricare.health.domain.model

import java.time.LocalDateTime

/**
 * Domain model for a Family Group.
 * Clean architecture: independent of data layer implementation.
 */
data class FamilyGroup(
    val id: String,
    val name: String,
    val createdBy: String,
    val inviteCode: String? = null,
    val createdAt: LocalDateTime? = null
)

/**
 * Domain model for a Family Member.
 */
data class FamilyMember(
    val id: String,
    val groupId: String,
    val userId: String,
    val role: FamilyRole,
    val fullName: String? = null,
    val avatarUrl: String? = null,
    val joinedAt: LocalDateTime? = null
) {
    val canManageMembers: Boolean
        get() = role == FamilyRole.OWNER || role == FamilyRole.ADMIN

    val canGenerateInvites: Boolean
        get() = role == FamilyRole.OWNER || role == FamilyRole.ADMIN

    val isOwner: Boolean
        get() = role == FamilyRole.OWNER
}

/**
 * Domain model for Family Role enumeration.
 */
enum class FamilyRole(val dbValue: String, val displayName: String) {
    OWNER("owner", "Owner"),
    ADMIN("admin", "Admin"),
    MEMBER("member", "Member");

    companion object {
        fun fromDb(value: String): FamilyRole =
            entries.firstOrNull { it.dbValue == value } ?: MEMBER
    }
}

/**
 * Domain model for a Family Invitation.
 */
data class FamilyInvitation(
    val code: String,
    val groupId: String,
    val groupName: String? = null,
    val expiresAt: LocalDateTime? = null
) {
    val isExpired: Boolean
        get() = expiresAt?.isBefore(LocalDateTime.now()) == true
}

/**
 * Domain model for Family Permissions.
 */
data class FamilyPermissions(
    val memberId: String,
    val canViewHealthData: Boolean = false,
    val canEditHealthData: Boolean = false,
    val canManageMedications: Boolean = false,
    val canReceiveNotifications: Boolean = false
)
