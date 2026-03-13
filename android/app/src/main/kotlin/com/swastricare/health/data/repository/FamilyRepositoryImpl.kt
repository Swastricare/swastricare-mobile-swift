package com.swastricare.health.data.repository

import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.mapper.FamilyMapper
import com.swastricare.health.data.remote.dto.family.CreateFamilyGroupDto
import com.swastricare.health.data.remote.dto.family.CreateFamilyMemberDto
import com.swastricare.health.data.remote.dto.family.FamilyGroupDto
import com.swastricare.health.data.remote.dto.family.FamilyInviteDto
import com.swastricare.health.data.remote.dto.family.FamilyMemberDto
import com.swastricare.health.data.remote.dto.family.FamilyPermissionsDto
import com.swastricare.health.domain.model.FamilyGroup
import com.swastricare.health.domain.model.FamilyInvitation
import com.swastricare.health.domain.model.FamilyMember
import com.swastricare.health.domain.model.FamilyPermissions
import com.swastricare.health.domain.repository.FamilyRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.security.SecureRandom
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Implementation of FamilyRepository using Supabase.
 * Handles all family-related data operations.
 */
@Singleton
class FamilyRepositoryImpl @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val logger: Logger
) : FamilyRepository {

    private val tag = "FamilyRepository"

    // ── Family Group Operations ──

    override suspend fun createFamilyGroup(name: String, userId: String): ResultWrapper<FamilyGroup> {
        return try {
            logger.d(tag, "Creating family group: $name for user: $userId")

            val groupId = UUID.randomUUID().toString()
            val createDto = CreateFamilyGroupDto(
                id = groupId,
                name = name,
                createdBy = userId
            )

            // Create the family group
            supabaseClient.from("family_groups")
                .insert(createDto)

            // Add creator as owner
            val memberDto = CreateFamilyMemberDto(
                id = UUID.randomUUID().toString(),
                groupId = groupId,
                userId = userId,
                role = "owner"
            )
            supabaseClient.from("family_members")
                .insert(memberDto)

            // Fetch the created group
            val groups = supabaseClient.from("family_groups")
                .select {
                    filter { eq("id", groupId) }
                }
                .decodeList<FamilyGroupDto>()

            val groupDto = groups.firstOrNull()
                ?: return ResultWrapper.Error(AppException.ApiException.ServerError("Failed to create family group"))

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

            // Find the member record for this user
            val members = supabaseClient.from("family_members")
                .select {
                    filter { eq("user_id", userId) }
                }
                .decodeList<FamilyMemberDto>()

            val member = members.firstOrNull()
            if (member == null) {
                logger.d(tag, "User not a member of any family group")
                return ResultWrapper.Success(null)
            }

            // Fetch the group
            val groups = supabaseClient.from("family_groups")
                .select {
                    filter { eq("id", member.groupId) }
                }
                .decodeList<FamilyGroupDto>()

            val groupDto = groups.firstOrNull()
            if (groupDto == null) {
                logger.w(tag, "Member record exists but group not found")
                return ResultWrapper.Success(null)
            }

            logger.i(tag, "Family group fetched: ${groupDto.id}")
            ResultWrapper.Success(FamilyMapper.toDomain(groupDto))
        } catch (e: Exception) {
            logger.e(tag, "Error fetching family group", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun updateFamilyGroup(groupId: String, name: String): ResultWrapper<Unit> {
        return try {
            logger.d(tag, "Updating family group: $groupId")

            supabaseClient.from("family_groups")
                .update(
                    buildJsonObject { put("name", name) }
                ) {
                    filter { eq("id", groupId) }
                }

            logger.i(tag, "Family group updated successfully")
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(tag, "Error updating family group", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    // ── Member Operations ──

    override suspend fun getMembers(groupId: String): ResultWrapper<List<FamilyMember>> {
        return try {
            logger.d(tag, "Fetching members for group: $groupId")

            val memberDtos = supabaseClient.from("family_members")
                .select {
                    filter { eq("group_id", groupId) }
                }
                .decodeList<FamilyMemberDto>()

            logger.i(tag, "Fetched ${memberDtos.size} members")
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

            // Find group by invite code
            val groups = supabaseClient.from("family_groups")
                .select {
                    filter { eq("invite_code", inviteCode) }
                }
                .decodeList<FamilyGroupDto>()

            val groupDto = groups.firstOrNull()
                ?: return ResultWrapper.Error(
                    AppException.ValidationException.Custom("Invalid invite code")
                )

            // Check if user is already a member
            val existingMembers = supabaseClient.from("family_members")
                .select {
                    filter { eq("user_id", userId) }
                }
                .decodeList<FamilyMemberDto>()

            if (existingMembers.isNotEmpty()) {
                return ResultWrapper.Error(
                    AppException.ValidationException.Custom("You are already a member of a family group")
                )
            }

            // Add member
            val memberDto = CreateFamilyMemberDto(
                id = UUID.randomUUID().toString(),
                groupId = groupDto.id,
                userId = userId,
                role = "member",
                fullName = fullName
            )
            supabaseClient.from("family_members")
                .insert(memberDto)

            logger.i(tag, "User joined group successfully: ${groupDto.id}")
            ResultWrapper.Success(FamilyMapper.toDomain(groupDto))
        } catch (e: Exception) {
            logger.e(tag, "Error joining group", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun leaveGroup(memberId: String): ResultWrapper<Unit> {
        return try {
            logger.d(tag, "Leaving group for member: $memberId")

            supabaseClient.from("family_members")
                .delete {
                    filter { eq("id", memberId) }
                }

            logger.i(tag, "Member left group successfully")
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(tag, "Error leaving group", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun removeMember(memberId: String, requestingUserId: String): ResultWrapper<Unit> {
        return try {
            logger.d(tag, "Removing member: $memberId by user: $requestingUserId")

            // Get the member to find the group
            val members = supabaseClient.from("family_members")
                .select {
                    filter { eq("id", memberId) }
                }
                .decodeList<FamilyMemberDto>()

            val memberToRemove = members.firstOrNull()
                ?: return ResultWrapper.Error(
                    AppException.ValidationException.Custom("Member not found")
                )

            // Verify requesting user has permission
            val allMembers = supabaseClient.from("family_members")
                .select {
                    filter { eq("group_id", memberToRemove.groupId) }
                }
                .decodeList<FamilyMemberDto>()

            val requestingMember = allMembers.firstOrNull { it.userId == requestingUserId }
                ?: return ResultWrapper.Error(
                    AppException.ValidationException.Custom("You are not a member of this family group")
                )

            val canRemove = requestingMember.role == "owner" || requestingMember.role == "admin"
            if (!canRemove) {
                return ResultWrapper.Error(
                    AppException.ValidationException.Custom("Only owners and admins can remove members")
                )
            }

            // Remove the member
            supabaseClient.from("family_members")
                .delete {
                    filter { eq("id", memberId) }
                }

            logger.i(tag, "Member removed successfully")
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
            logger.d(tag, "Updating member role: $memberId to $newRole")

            // Verify requesting user is owner
            val members = supabaseClient.from("family_members")
                .select {
                    filter { eq("id", memberId) }
                }
                .decodeList<FamilyMemberDto>()

            val memberToUpdate = members.firstOrNull()
                ?: return ResultWrapper.Error(
                    AppException.ValidationException.Custom("Member not found")
                )

            val allMembers = supabaseClient.from("family_members")
                .select {
                    filter { eq("group_id", memberToUpdate.groupId) }
                }
                .decodeList<FamilyMemberDto>()

            val requestingMember = allMembers.firstOrNull { it.userId == requestingUserId }
                ?: return ResultWrapper.Error(
                    AppException.ValidationException.Custom("You are not a member of this family group")
                )

            if (requestingMember.role != "owner") {
                return ResultWrapper.Error(
                    AppException.ValidationException.Custom("Only the owner can change member roles")
                )
            }

            // Update the role
            supabaseClient.from("family_members")
                .update(
                    buildJsonObject { put("role", newRole) }
                ) {
                    filter { eq("id", memberId) }
                }

            logger.i(tag, "Member role updated successfully")
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(tag, "Error updating member role", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    // ── Invitation Operations ──

    override suspend fun generateInviteCode(groupId: String): ResultWrapper<FamilyInvitation> {
        return try {
            logger.d(tag, "Generating invite code for group: $groupId")

            val code = generateRandomCode()

            supabaseClient.from("family_groups")
                .update(
                    buildJsonObject { put("invite_code", code) }
                ) {
                    filter { eq("id", groupId) }
                }

            // Fetch the group to get the name
            val groups = supabaseClient.from("family_groups")
                .select {
                    filter { eq("id", groupId) }
                }
                .decodeList<FamilyGroupDto>()

            val groupDto = groups.firstOrNull()

            logger.i(tag, "Invite code generated: $code")
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
            logger.d(tag, "Validating invite code: $inviteCode")

            val groups = supabaseClient.from("family_groups")
                .select {
                    filter { eq("invite_code", inviteCode) }
                }
                .decodeList<FamilyGroupDto>()

            val groupDto = groups.firstOrNull()
                ?: return ResultWrapper.Error(
                    AppException.ValidationException.Custom("Invalid invite code")
                )

            logger.i(tag, "Invite code validated successfully")
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
            logger.d(tag, "Fetching permissions for member: $memberId")

            val permissions = supabaseClient.from("family_permissions")
                .select {
                    filter { eq("member_id", memberId) }
                }
                .decodeSingleOrNull<FamilyPermissionsDto>()

            if (permissions == null) {
                // Return default permissions if none exist
                logger.d(tag, "No permissions found, returning defaults")
                return ResultWrapper.Success(
                    FamilyPermissions(memberId = memberId)
                )
            }

            logger.i(tag, "Permissions fetched successfully")
            ResultWrapper.Success(FamilyMapper.permissionsToDomain(permissions))
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
            logger.d(tag, "Updating permissions for member: ${permissions.memberId}")

            // Verify requesting user has permission (owner/admin)
            val members = supabaseClient.from("family_members")
                .select {
                    filter { eq("id", permissions.memberId) }
                }
                .decodeList<FamilyMemberDto>()

            val memberToUpdate = members.firstOrNull()
                ?: return ResultWrapper.Error(
                    AppException.ValidationException.Custom("Member not found")
                )

            val allMembers = supabaseClient.from("family_members")
                .select {
                    filter { eq("group_id", memberToUpdate.groupId) }
                }
                .decodeList<FamilyMemberDto>()

            val requestingMember = allMembers.firstOrNull { it.userId == requestingUserId }
                ?: return ResultWrapper.Error(
                    AppException.ValidationException.Custom("You are not a member of this family group")
                )

            val canUpdate = requestingMember.role == "owner" || requestingMember.role == "admin"
            if (!canUpdate) {
                return ResultWrapper.Error(
                    AppException.ValidationException.Custom("Only owners and admins can update permissions")
                )
            }

            // Upsert permissions
            val dto = FamilyMapper.permissionsToDto(permissions)
            supabaseClient.from("family_permissions")
                .upsert(dto)

            logger.i(tag, "Permissions updated successfully")
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(tag, "Error updating permissions", e)
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    // ── Helper Methods ──

    private fun generateRandomCode(): String {
        val chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        val random = SecureRandom()
        return (1..8).map { chars[random.nextInt(chars.length)] }.joinToString("")
    }
}
