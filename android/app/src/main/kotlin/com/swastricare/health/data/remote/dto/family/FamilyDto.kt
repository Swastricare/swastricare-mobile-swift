package com.swastricare.health.data.remote.dto.family

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTO for family_groups table in Supabase.
 * Mirrors the actual schema (owner_user_id is the group creator).
 */
@Serializable
data class FamilyGroupDto(
    @SerialName("id")
    val id: String,

    @SerialName("name")
    val name: String,

    @SerialName("owner_user_id")
    val ownerUserId: String,

    @SerialName("invite_code")
    val inviteCode: String? = null,

    @SerialName("created_at")
    val createdAt: String? = null
)

/**
 * DTO for inserting a row into family_groups.
 */
@Serializable
data class CreateFamilyGroupDto(
    @SerialName("id")
    val id: String,

    @SerialName("name")
    val name: String,

    @SerialName("owner_user_id")
    val ownerUserId: String,

    @SerialName("invite_code")
    val inviteCode: String? = null
)

/**
 * Joined health_profiles fields (selected via PostgREST embed).
 */
@Serializable
data class HealthProfileEmbedDto(
    @SerialName("user_id")
    val userId: String? = null,

    @SerialName("full_name")
    val fullName: String? = null,

    @SerialName("avatar_url")
    val avatarUrl: String? = null
)

/**
 * DTO for family_members table in Supabase.
 * Members reference a `health_profile_id`, not directly a user_id.
 */
@Serializable
data class FamilyMemberDto(
    @SerialName("id")
    val id: String,

    @SerialName("family_group_id")
    val familyGroupId: String,

    @SerialName("health_profile_id")
    val healthProfileId: String,

    @SerialName("role")
    val role: String = "viewer",

    @SerialName("status")
    val status: String = "active",

    @SerialName("added_by_user_id")
    val addedByUserId: String? = null,

    @SerialName("joined_at")
    val joinedAt: String? = null,

    @SerialName("health_profiles")
    val healthProfile: HealthProfileEmbedDto? = null
)

/**
 * DTO for inserting a row into family_members.
 */
@Serializable
data class CreateFamilyMemberDto(
    @SerialName("id")
    val id: String,

    @SerialName("family_group_id")
    val familyGroupId: String,

    @SerialName("health_profile_id")
    val healthProfileId: String,

    @SerialName("added_by_user_id")
    val addedByUserId: String,

    @SerialName("role")
    val role: String = "viewer",

    @SerialName("status")
    val status: String = "active",

    @SerialName("can_view")
    val canView: Boolean = true,

    @SerialName("can_edit")
    val canEdit: Boolean = false,

    @SerialName("can_add_medications")
    val canAddMedications: Boolean = false,

    @SerialName("can_add_appointments")
    val canAddAppointments: Boolean = false,

    @SerialName("can_view_medical_documents")
    val canViewMedicalDocuments: Boolean = true,

    @SerialName("can_manage_members")
    val canManageMembers: Boolean = false
)

/**
 * Lightweight DTO for invite-code metadata (synthesized; no dedicated table).
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
 * DTO for the per-member permissions stored as columns on family_members.
 * (Kept here for the legacy permissions API; reads/writes target family_members.)
 */
@Serializable
data class FamilyPermissionsDto(
    @SerialName("id")
    val memberId: String,

    @SerialName("can_view")
    val canViewHealthData: Boolean = true,

    @SerialName("can_edit")
    val canEditHealthData: Boolean = false,

    @SerialName("can_add_medications")
    val canManageMedications: Boolean = false,

    @SerialName("can_view_medical_documents")
    val canReceiveNotifications: Boolean = true
)
