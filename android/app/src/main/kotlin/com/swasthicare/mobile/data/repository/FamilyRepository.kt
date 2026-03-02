package com.swasthicare.mobile.data.repository

import com.swasthicare.mobile.data.models.FamilyGroup
import com.swasthicare.mobile.data.models.FamilyInvite
import com.swasthicare.mobile.data.models.FamilyMember
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

// -----------------------------------------------
// MARK: - Repository Interface
// -----------------------------------------------

interface FamilyRepository {
    /** Fetch the current user's family group (if any). */
    suspend fun getMyFamilyGroup(userId: String): FamilyGroup?

    /** Fetch members of a family group. */
    suspend fun getMembers(groupId: String): List<FamilyMember>

    /** Join a family group using an invite code. */
    suspend fun joinGroup(inviteCode: String, userId: String, fullName: String?): Result<FamilyGroup>

    /** Generate a new invite code for the family group (owner/admin only). */
    suspend fun generateInviteCode(groupId: String): Result<FamilyInvite>

    /** Leave the current family group. */
    suspend fun leaveGroup(memberId: String): Result<Unit>
}

// -----------------------------------------------
// MARK: - Supabase Implementation
// -----------------------------------------------

class SupabaseFamilyRepository(
    private val supabaseClient: SupabaseClient
) : FamilyRepository {

    override suspend fun getMyFamilyGroup(userId: String): FamilyGroup? =
        withContext(Dispatchers.IO) {
            try {
                // Find the member record for this user
                val members = supabaseClient.from("family_members").select {
                    filter { eq("user_id", userId) }
                }.decodeList<FamilyMember>()

                val member = members.firstOrNull() ?: return@withContext null

                // Fetch the group
                val groups = supabaseClient.from("family_groups").select {
                    filter { eq("id", member.groupId) }
                }.decodeList<FamilyGroup>()

                groups.firstOrNull()
            } catch (e: Exception) {
                null
            }
        }

    override suspend fun getMembers(groupId: String): List<FamilyMember> =
        withContext(Dispatchers.IO) {
            try {
                supabaseClient.from("family_members").select {
                    filter { eq("group_id", groupId) }
                }.decodeList<FamilyMember>()
            } catch (e: Exception) {
                emptyList()
            }
        }

    override suspend fun joinGroup(
        inviteCode: String,
        userId: String,
        fullName: String?
    ): Result<FamilyGroup> = withContext(Dispatchers.IO) {
        try {
            // Find group by invite code
            val groups = supabaseClient.from("family_groups").select {
                filter { eq("invite_code", inviteCode) }
            }.decodeList<FamilyGroup>()

            val group = groups.firstOrNull()
                ?: return@withContext Result.failure(Exception("Invalid invite code"))

            // Check if user is already a member of any family group
            val existingMember = supabaseClient.from("family_members")
                .select { filter { eq("user_id", userId) } }
                .decodeSingleOrNull<FamilyMember>()
            if (existingMember != null) {
                return@withContext Result.failure(Exception("You are already a member of a family group"))
            }

            // Add member
            val newMember = FamilyMember(
                id = java.util.UUID.randomUUID().toString(),
                groupId = group.id,
                userId = userId,
                role = "member",
                fullName = fullName
            )
            supabaseClient.from("family_members").insert(newMember)

            Result.success(group)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun generateInviteCode(groupId: String): Result<FamilyInvite> =
        withContext(Dispatchers.IO) {
            try {
                val code = generateRandomCode()
                supabaseClient.from("family_groups").update(
                    buildJsonObject { put("invite_code", code) }
                ) {
                    filter { eq("id", groupId) }
                }
                Result.success(FamilyInvite(code = code, groupId = groupId))
            } catch (e: Exception) {
                Result.failure(e)
            }
        }

    override suspend fun leaveGroup(memberId: String): Result<Unit> =
        withContext(Dispatchers.IO) {
            try {
                supabaseClient.from("family_members").delete {
                    filter { eq("id", memberId) }
                }
                Result.success(Unit)
            } catch (e: Exception) {
                Result.failure(e)
            }
        }

    private fun generateRandomCode(): String {
        val chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        val random = java.security.SecureRandom()
        return (1..8).map { chars[random.nextInt(chars.length)] }.joinToString("")
    }
}
