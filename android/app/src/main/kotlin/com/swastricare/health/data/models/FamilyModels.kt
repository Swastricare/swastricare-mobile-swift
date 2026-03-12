package com.swastricare.health.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// -----------------------------------------------
// MARK: - Family Group
// -----------------------------------------------

@Serializable
data class FamilyGroup(
    val id: String = "",
    val name: String = "",
    @SerialName("created_by") val createdBy: String = "",
    @SerialName("invite_code") val inviteCode: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)

// -----------------------------------------------
// MARK: - Family Member
// -----------------------------------------------

@Serializable
data class FamilyMember(
    val id: String = "",
    @SerialName("group_id") val groupId: String = "",
    @SerialName("user_id") val userId: String = "",
    val role: String = "member", // "owner", "admin", "member"
    @SerialName("full_name") val fullName: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("joined_at") val joinedAt: String? = null
) {
    val roleEnum: FamilyRole get() = FamilyRole.fromDb(role)
}

// -----------------------------------------------
// MARK: - Family Role
// -----------------------------------------------

enum class FamilyRole(val dbValue: String, val displayName: String) {
    OWNER("owner", "Owner"),
    ADMIN("admin", "Admin"),
    MEMBER("member", "Member");

    companion object {
        fun fromDb(value: String): FamilyRole =
            entries.firstOrNull { it.dbValue == value } ?: MEMBER
    }
}

// -----------------------------------------------
// MARK: - Family Invite
// -----------------------------------------------

@Serializable
data class FamilyInvite(
    val code: String = "",
    @SerialName("group_id") val groupId: String = "",
    @SerialName("expires_at") val expiresAt: String? = null
)
