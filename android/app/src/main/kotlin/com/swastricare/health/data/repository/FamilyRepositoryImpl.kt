package com.swastricare.health.data.repository

import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.mapper.FamilyMapper
import com.swastricare.health.data.remote.dto.family.CreateFamilyGroupDto
import com.swastricare.health.data.remote.dto.family.CreateFamilyMemberDto
import com.swastricare.health.data.remote.dto.family.FamilyGroupDto
import com.swastricare.health.data.remote.dto.family.FamilyMemberDto
import com.swastricare.health.data.remote.dto.family.FamilyPermissionsDto
import com.swastricare.health.domain.model.FamilyGroup
import com.swastricare.health.domain.model.FamilyInvitation
import com.swastricare.health.domain.model.FamilyMember
import com.swastricare.health.domain.model.FamilyPermissions
import com.swastricare.health.domain.repository.FamilyRepository
import com.swastricare.health.domain.repository.ProfileRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.security.SecureRandom
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase-backed implementation of [FamilyRepository] that matches the actual schema:
 *   - family_groups(id, owner_user_id, name, invite_code, ...)
 *   - family_members(id, family_group_id, health_profile_id, role, status,
 *                    can_*, added_by_user_id, joined_at, ...)
 *
 * Members reference a health_profile, not the auth user directly. We resolve the current
 * user's `health_profile_id` via [ProfileRepository] before any member query.
 */
@Singleton
class FamilyRepositoryImpl @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val profileRepository: ProfileRepository,
    private val logger: Logger
) : FamilyRepository {

    private val tag = "FamilyRepository"

    // PostgREST embed: select members + their joined health_profile fields
    private val memberSelectColumns = Columns.raw(
        "*, health_profiles(user_id, full_name, avatar_url)"
    )

    // ── Family Group Operations ──

    override suspend fun createFamilyGroup(name: String, userId: String): ResultWrapper<FamilyGroup> {
        return try {
            logger.d(tag, "Creating family group: $name for user: $userId")

            val healthProfileId = resolveHealthProfileId(userId)
                ?: return ResultWrapper.Error(
                    AppException.ValidationException.Custom(
                        "Health profile not found. Please complete onboarding."
                    )
                )

            val groupId = UUID.randomUUID().toString()
            val inviteCode = generateRandomCode()

            supabaseClient.from("family_groups")
                .insert(
                    CreateFamilyGroupDto(
                        id = groupId,
                        name = name,
                        ownerUserId = userId,
                        inviteCode = inviteCode
                    )
                )

            // Add creator as the owner family_member
            supabaseClient.from("family_members")
                .insert(
                    CreateFamilyMemberDto(
                        id = UUID.randomUUID().toString(),
                        familyGroupId = groupId,
                        healthProfileId = healthProfileId,
                        addedByUserId = userId,
                        role = "owner",
                        status = "active",
                        canView = true,
                        canEdit = true,
                        canAddMedications = true,
                        canAddAppointments = true,
                        canViewMedicalDocuments = true,
                        canManageMembers = true
                    )
                )

            val groupDto = supabaseClient.from("family_groups")
                .select { filter { eq("id", groupId) } }
                .decodeList<FamilyGroupDto>()
                .firstOrNull()
                ?: return ResultWrapper.Error(
                    AppException.ApiException.ServerError("Failed to create family group")
                )

            logger.i(tag, "Family group created successfully: ${groupDto.id}")
            ResultWrapper.Success(FamilyMapper.toDomain(groupDto))
        } catch (e: Exception) {
            logger.e(tag, "Error creating family group", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun getMyFamilyGroup(userId: String): ResultWrapper<FamilyGroup?> {
        return try {
            logger.d(tag, "Fetching family group for user: $userId")

            // 1. Owner check
            val owned = supabaseClient.from("family_groups")
                .select { filter { eq("owner_user_id", userId) } }
                .decodeList<FamilyGroupDto>()
            owned.firstOrNull()?.let {
                return ResultWrapper.Success(FamilyMapper.toDomain(it))
            }

            // 2. Member check via health_profile
            val healthProfileId = resolveHealthProfileId(userId)
                ?: return ResultWrapper.Success(null)

            val memberRows = supabaseClient.from("family_members")
                .select(Columns.raw("family_group_id")) {
                    filter {
                        eq("health_profile_id", healthProfileId)
                        eq("status", "active")
                    }
                }
                .decodeList<MemberGroupRef>()

            val groupId = memberRows.firstOrNull()?.familyGroupId
                ?: return ResultWrapper.Success(null)

            val groupDto = supabaseClient.from("family_groups")
                .select { filter { eq("id", groupId) } }
                .decodeList<FamilyGroupDto>()
                .firstOrNull()

            ResultWrapper.Success(groupDto?.let { FamilyMapper.toDomain(it) })
        } catch (e: Exception) {
            logger.e(tag, "Error fetching family group", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun updateFamilyGroup(groupId: String, name: String): ResultWrapper<Unit> {
        return try {
            supabaseClient.from("family_groups")
                .update(buildJsonObject { put("name", name) }) {
                    filter { eq("id", groupId) }
                }
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(tag, "Error updating family group", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    // ── Member Operations ──

    override suspend fun getMembers(groupId: String): ResultWrapper<List<FamilyMember>> {
        return try {
            val memberDtos = supabaseClient.from("family_members")
                .select(memberSelectColumns) {
                    filter {
                        eq("family_group_id", groupId)
                        eq("status", "active")
                    }
                }
                .decodeList<FamilyMemberDto>()

            ResultWrapper.Success(FamilyMapper.membersToDomainList(memberDtos))
        } catch (e: Exception) {
            logger.e(tag, "Error fetching members", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun joinGroup(
        inviteCode: String,
        userId: String,
        fullName: String?
    ): ResultWrapper<FamilyGroup> {
        return try {
            logger.d(tag, "Joining group with code: $inviteCode")

            val groupDto = supabaseClient.from("family_groups")
                .select { filter { eq("invite_code", inviteCode.uppercase()) } }
                .decodeList<FamilyGroupDto>()
                .firstOrNull()
                ?: return ResultWrapper.Error(
                    AppException.ValidationException.Custom("Invalid invite code")
                )

            val healthProfileId = resolveHealthProfileId(userId)
                ?: return ResultWrapper.Error(
                    AppException.ValidationException.Custom(
                        "Health profile not found. Please complete onboarding."
                    )
                )

            // Already a member?
            val existing = supabaseClient.from("family_members")
                .select(Columns.raw("id")) {
                    filter {
                        eq("family_group_id", groupDto.id)
                        eq("health_profile_id", healthProfileId)
                    }
                }
                .decodeList<MemberIdOnly>()

            if (existing.isNotEmpty()) {
                return ResultWrapper.Error(
                    AppException.ValidationException.Custom(
                        "You are already a member of this family group"
                    )
                )
            }

            supabaseClient.from("family_members")
                .insert(
                    CreateFamilyMemberDto(
                        id = UUID.randomUUID().toString(),
                        familyGroupId = groupDto.id,
                        healthProfileId = healthProfileId,
                        addedByUserId = userId,
                        role = "viewer",
                        status = "active",
                        canView = true,
                        canEdit = false,
                        canAddMedications = false,
                        canAddAppointments = false,
                        canViewMedicalDocuments = true,
                        canManageMembers = false
                    )
                )

            ResultWrapper.Success(FamilyMapper.toDomain(groupDto))
        } catch (e: Exception) {
            logger.e(tag, "Error joining group", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun leaveGroup(memberId: String): ResultWrapper<Unit> {
        return try {
            supabaseClient.from("family_members")
                .delete { filter { eq("id", memberId) } }
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(tag, "Error leaving group", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun removeMember(memberId: String, requestingUserId: String): ResultWrapper<Unit> {
        return try {
            // Permission check happens server-side via RLS; we just attempt the delete.
            supabaseClient.from("family_members")
                .delete { filter { eq("id", memberId) } }
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(tag, "Error removing member", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun updateMemberRole(
        memberId: String,
        newRole: String,
        requestingUserId: String
    ): ResultWrapper<Unit> {
        return try {
            supabaseClient.from("family_members")
                .update(buildJsonObject { put("role", newRole) }) {
                    filter { eq("id", memberId) }
                }
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(tag, "Error updating member role", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    // ── Invitation Operations ──

    override suspend fun generateInviteCode(groupId: String): ResultWrapper<FamilyInvitation> {
        return try {
            val code = generateRandomCode()

            supabaseClient.from("family_groups")
                .update(buildJsonObject { put("invite_code", code) }) {
                    filter { eq("id", groupId) }
                }

            val groupDto = supabaseClient.from("family_groups")
                .select { filter { eq("id", groupId) } }
                .decodeList<FamilyGroupDto>()
                .firstOrNull()

            ResultWrapper.Success(
                FamilyInvitation(
                    code = code,
                    groupId = groupId,
                    groupName = groupDto?.name
                )
            )
        } catch (e: Exception) {
            logger.e(tag, "Error generating invite code", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun validateInviteCode(inviteCode: String): ResultWrapper<FamilyInvitation> {
        return try {
            val groupDto = supabaseClient.from("family_groups")
                .select { filter { eq("invite_code", inviteCode.uppercase()) } }
                .decodeList<FamilyGroupDto>()
                .firstOrNull()
                ?: return ResultWrapper.Error(
                    AppException.ValidationException.Custom("Invalid invite code")
                )

            ResultWrapper.Success(
                FamilyInvitation(
                    code = inviteCode,
                    groupId = groupDto.id,
                    groupName = groupDto.name
                )
            )
        } catch (e: Exception) {
            logger.e(tag, "Error validating invite code", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    // ── Permissions Operations ──

    override suspend fun getMemberPermissions(memberId: String): ResultWrapper<FamilyPermissions> {
        return try {
            val perms = supabaseClient.from("family_members")
                .select { filter { eq("id", memberId) } }
                .decodeList<FamilyPermissionsDto>()
                .firstOrNull()
                ?: return ResultWrapper.Success(FamilyPermissions(memberId = memberId))

            ResultWrapper.Success(FamilyMapper.permissionsToDomain(perms))
        } catch (e: Exception) {
            logger.e(tag, "Error fetching permissions", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun updateMemberPermissions(
        permissions: FamilyPermissions,
        requestingUserId: String
    ): ResultWrapper<Unit> {
        return try {
            supabaseClient.from("family_members")
                .update(
                    buildJsonObject {
                        put("can_view", permissions.canViewHealthData)
                        put("can_edit", permissions.canEditHealthData)
                        put("can_add_medications", permissions.canManageMedications)
                        put("can_view_medical_documents", permissions.canReceiveNotifications)
                    }
                ) {
                    filter { eq("id", permissions.memberId) }
                }
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(tag, "Error updating permissions", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    // ── Helpers ──

    private suspend fun resolveHealthProfileId(userId: String): String? {
        return when (val res = profileRepository.getHealthProfile(userId)) {
            is ResultWrapper.Success -> res.data?.id
            else -> null
        }
    }

    private fun generateRandomCode(): String {
        val chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789" // omit confusing chars
        val random = SecureRandom()
        return (1..6).map { chars[random.nextInt(chars.length)] }.joinToString("")
    }
}

@kotlinx.serialization.Serializable
private data class MemberGroupRef(
    @kotlinx.serialization.SerialName("family_group_id") val familyGroupId: String
)

@kotlinx.serialization.Serializable
private data class MemberIdOnly(
    @kotlinx.serialization.SerialName("id") val id: String
)
