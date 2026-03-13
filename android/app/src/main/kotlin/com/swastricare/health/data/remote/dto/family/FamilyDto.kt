package com.swastricare.health.data.remote.dto.family

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTO for family_groups table in Supabase.
 * Maps directly to database schema.
 */
@Serializable
data class FamilyGroupDto(
    @SerialName("id")
    val id: String,

    @SerialName("name")
    val name: String,

    @SerialName("created_by")
    val createdBy: String,

    @SerialName("invite_code")
    val inviteCode: String? = null,

    @SerialName("created_at")
    val createdAt: String? = null
)

/**
 * DTO for creating a family group.
 */
@Serializable
data class CreateFamilyGroupDto(
    @SerialName("id")
    val id: String,

    @SerialName("name")
    val name: String,

    @SerialName("created_by")
    val createdBy: String
)

/**
 * DTO for family_members table in Supabase.
 * Maps directly to database schema.
 */
@Serializable
data class FamilyMemberDto(
    @SerialName("id")
    val id: String,

    @SerialName("group_id")
    val groupId: String,

    @SerialName("user_id")
    val userId: String,

    @SerialName("role")
    val role: String = "member",

    @SerialName("full_name")
    val fullName: String? = null,

    @SerialName("avatar_url")
    val avatarUrl: String? = null,

    @SerialName("joined_at")
    val joinedAt: String? = null
)

/**
 * DTO for creating a family member.
 */
@Serializable
data class CreateFamilyMemberDto(
    @SerialName("id")
    val id: String,

    @SerialName("group_id")
    val groupId: String,

    @SerialName("user_id")
    val userId: String,

    @SerialName("role")
    val role: String = "member",

    @SerialName("full_name")
    val fullName: String? = null
)

/**
 * DTO for family_invites (embedded in family_groups).
 */
@Serializable
data class FamilyInviteDto(
    @SerialName("code")
    val code: String,

    @SerialName("group_id")
    val groupId: String,

    @SerialName("group_name")
    val groupName: String? = null,

    @SerialName("expires_at")
    val expiresAt: String? = null
)

/**
 * DTO for family_permissions table in Supabase.
 */
@Serializable
data class FamilyPermissionsDto(
    @SerialName("member_id")
    val memberId: String,

    @SerialName("can_view_health_data")
    val canViewHealthData: Boolean = false,

    @SerialName("can_edit_health_data")
    val canEditHealthData: Boolean = false,

    @SerialName("can_manage_medications")
    val canManageMedications: Boolean = false,

    @SerialName("can_receive_notifications")
    val canReceiveNotifications: Boolean = false
)
