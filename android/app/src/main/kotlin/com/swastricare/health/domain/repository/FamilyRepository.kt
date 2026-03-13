package com.swastricare.health.domain.repository

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.FamilyGroup
import com.swastricare.health.domain.model.FamilyInvitation
import com.swastricare.health.domain.model.FamilyMember
import com.swastricare.health.domain.model.FamilyPermissions

/**
 * Repository contract for Family data.
 * Implemented in data layer.
 */
interface FamilyRepository {

    // ── Family Group Operations ──

    /**
     * Create a new family group.
     *
     * @param name Group name
     * @param userId Creator user ID
     * @return Result with created FamilyGroup
     */
    suspend fun createFamilyGroup(name: String, userId: String): ResultWrapper<FamilyGroup>

    /**
     * Get the current user's family group.
     *
     * @param userId User ID
     * @return Result with FamilyGroup or null if not a member
     */
    suspend fun getMyFamilyGroup(userId: String): ResultWrapper<FamilyGroup?>

    /**
     * Update family group details.
     *
     * @param groupId Group ID
     * @param name New group name
     * @return Result
     */
    suspend fun updateFamilyGroup(groupId: String, name: String): ResultWrapper<Unit>

    // ── Member Operations ──

    /**
     * Get all members of a family group.
     *
     * @param groupId Group ID
     * @return Result with list of FamilyMembers
     */
    suspend fun getMembers(groupId: String): ResultWrapper<List<FamilyMember>>

    /**
     * Join a family group using an invite code.
     *
     * @param inviteCode Invitation code
     * @param userId User ID
     * @param fullName User's full name
     * @return Result with joined FamilyGroup
     */
    suspend fun joinGroup(
        inviteCode: String,
        userId: String,
        fullName: String?
    ): ResultWrapper<FamilyGroup>

    /**
     * Leave the current family group.
     *
     * @param memberId Member ID to remove
     * @return Result
     */
    suspend fun leaveGroup(memberId: String): ResultWrapper<Unit>

    /**
     * Remove a member from the family group (admin/owner only).
     *
     * @param memberId Member ID to remove
     * @param requestingUserId User ID making the request
     * @return Result
     */
    suspend fun removeMember(memberId: String, requestingUserId: String): ResultWrapper<Unit>

    /**
     * Update a member's role (owner only).
     *
     * @param memberId Member ID
     * @param newRole New role to assign
     * @param requestingUserId User ID making the request
     * @return Result
     */
    suspend fun updateMemberRole(
        memberId: String,
        newRole: String,
        requestingUserId: String
    ): ResultWrapper<Unit>

    // ── Invitation Operations ──

    /**
     * Generate a new invite code for the family group (owner/admin only).
     *
     * @param groupId Group ID
     * @return Result with FamilyInvitation
     */
    suspend fun generateInviteCode(groupId: String): ResultWrapper<FamilyInvitation>

    /**
     * Validate an invite code.
     *
     * @param inviteCode Code to validate
     * @return Result with FamilyInvitation if valid
     */
    suspend fun validateInviteCode(inviteCode: String): ResultWrapper<FamilyInvitation>

    // ── Permissions Operations ──

    /**
     * Get permissions for a family member.
     *
     * @param memberId Member ID
     * @return Result with FamilyPermissions
     */
    suspend fun getMemberPermissions(memberId: String): ResultWrapper<FamilyPermissions>

    /**
     * Update permissions for a family member.
     *
     * @param permissions Updated permissions
     * @param requestingUserId User ID making the request
     * @return Result
     */
    suspend fun updateMemberPermissions(
        permissions: FamilyPermissions,
        requestingUserId: String
    ): ResultWrapper<Unit>
}
