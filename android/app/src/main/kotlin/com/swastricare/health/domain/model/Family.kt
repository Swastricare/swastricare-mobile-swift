package com.swastricare.health.domain.model

import java.time.LocalDateTime

/**
 * Domain model for a Family Group.
 */
data class FamilyGroup(
    val id: String,
    val name: String,
    val ownerUserId: String,
    val inviteCode: String? = null,
    val createdAt: LocalDateTime? = null
) {
    // Back-compat alias for callers still using the older name.
    val createdBy: String get() = ownerUserId
}

/**
 * Domain model for a Family Member.
 *
 * - [healthProfileId] is the FK to `health_profiles` and what `family_members` actually stores.
 * - [userId] is the auth user id derived from the joined `health_profiles.user_id` row.
 *   It may be null if the join was not requested.
 */
data class FamilyMember(
    val id: String,
    val groupId: String,
    val healthProfileId: String,
    val userId: String? = null,
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
 * Family role enum.
 *
 * Database values follow the schema:
 *   role IN ('owner', 'caregiver', 'viewer', 'limited')
 *
 * In-app names are kept as OWNER/ADMIN/MEMBER for back-compat with existing UI code.
 *   ADMIN  ↔ "caregiver"
 *   MEMBER ↔ "viewer" (also accepts "limited")
 */
enum class FamilyRole(val dbValue: String, val displayName: String) {
    OWNER("owner", "Owner"),
    ADMIN("caregiver", "Caregiver"),
    MEMBER("viewer", "Member");

    companion object {
        fun fromDb(value: String): FamilyRole = when (value.lowercase()) {
            "owner" -> OWNER
            "caregiver", "admin" -> ADMIN
            "viewer", "member", "limited" -> MEMBER
            else -> MEMBER
        }
    }
}

/**
 * Invitation snapshot returned to UI for sharing.
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
 * Per-member permissions (column subset on family_members).
 */
data class FamilyPermissions(
    val memberId: String,
    val canViewHealthData: Boolean = true,
    val canEditHealthData: Boolean = false,
    val canManageMedications: Boolean = false,
    val canReceiveNotifications: Boolean = true
)
