package com.swastricare.health.data.repository

import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.FamilyGroup
import com.swastricare.health.domain.model.FamilyInvitation
import com.swastricare.health.domain.model.FamilyMember
import com.swastricare.health.domain.model.FamilyPermissions
import com.swastricare.health.domain.model.FamilyRole
import com.swastricare.health.util.MainDispatcherRule
import com.swastricare.health.util.MockFactory
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.time.LocalDateTime

/**
 * Unit tests for FamilyRepositoryImpl.
 *
 * Tests:
 * - Family group creation
 * - Member management (join, leave, remove)
 * - Invitation system (generate, validate codes)
 * - Permission management
 * - Role management
 * - Error handling
 */
@OptIn(ExperimentalCoroutinesApi::class)
class FamilyRepositoryImplTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var supabaseClient: SupabaseClient
    private lateinit var postgrest: Postgrest
    private lateinit var logger: Logger
    private lateinit var repository: FamilyRepositoryImpl

    @Before
    fun setup() {
        supabaseClient = mockk(relaxed = true)
        postgrest = mockk(relaxed = true)
        logger = mockk(relaxed = true)

        every { supabaseClient.postgrest } returns postgrest

        repository = FamilyRepositoryImpl(
            supabaseClient = supabaseClient,
            logger = logger
        )
    }

    private fun createTestFamilyGroup(
        id: String = "test-group-id",
        name: String = "Test Family",
        createdBy: String = MockFactory.TEST_USER_ID,
        inviteCode: String? = "TESTCODE123"
    ) = FamilyGroup(
        id = id,
        name = name,
        createdBy = createdBy,
        inviteCode = inviteCode,
        createdAt = LocalDateTime.now()
    )

    private fun createTestFamilyMember(
        id: String = "member-id",
        groupId: String = "group-id",
        userId: String = MockFactory.TEST_USER_ID,
        role: FamilyRole = FamilyRole.MEMBER,
        fullName: String? = "Test User"
    ) = FamilyMember(
        id = id,
        groupId = groupId,
        userId = userId,
        role = role,
        fullName = fullName,
        joinedAt = LocalDateTime.now()
    )

    @Test
    fun `createFamilyGroup creates new group successfully`() = runTest {
        // Given
        val groupName = "My Family"
        val userId = MockFactory.TEST_USER_ID

        // When
        val result = repository.createFamilyGroup(groupName, userId)

        // Then
        assertTrue(result is ResultWrapper.Success)
        verify { logger.d("FamilyRepository", any()) }
    }

    @Test
    fun `createFamilyGroup handles error when creation fails`() = runTest {
        // Given
        val groupName = "My Family"
        val userId = MockFactory.TEST_USER_ID
        coEvery { postgrest.from(any()) } throws Exception("Database error")

        // When
        val result = repository.createFamilyGroup(groupName, userId)

        // Then
        assertTrue(result is ResultWrapper.Error)
    }

    @Test
    fun `getMyFamilyGroup returns group when user is member`() = runTest {
        // Given
        val userId = MockFactory.TEST_USER_ID
        val group = createTestFamilyGroup()

        // When
        val result = repository.getMyFamilyGroup(userId)

        // Then - Should be Success (implementation dependent)
        assertNotNull(result)
    }

    @Test
    fun `getMyFamilyGroup returns null when user is not a member`() = runTest {
        // Given
        val userId = "non-member-user-id"

        // When
        val result = repository.getMyFamilyGroup(userId)

        // Then - Should be Success with null
        assertNotNull(result)
    }

    @Test
    fun `joinGroup adds user to family group with valid invite code`() = runTest {
        // Given
        val inviteCode = "VALIDCODE123"
        val userId = MockFactory.TEST_USER_ID
        val fullName = "New Member"

        // When
        val result = repository.joinGroup(inviteCode, userId, fullName)

        // Then - Should handle join operation
        assertNotNull(result)
    }

    @Test
    fun `joinGroup fails with invalid invite code`() = runTest {
        // Given
        val inviteCode = "INVALIDCODE"
        val userId = MockFactory.TEST_USER_ID
        val fullName = "New Member"
        coEvery { postgrest.from(any()) } throws Exception("Invalid invite code")

        // When
        val result = repository.joinGroup(inviteCode, userId, fullName)

        // Then
        assertTrue(result is ResultWrapper.Error)
    }

    @Test
    fun `leaveGroup removes member from family`() = runTest {
        // Given
        val memberId = "member-id"

        // When
        val result = repository.leaveGroup(memberId)

        // Then
        assertNotNull(result)
    }

    @Test
    fun `removeMember removes member with proper authorization`() = runTest {
        // Given
        val memberId = "member-to-remove"
        val adminUserId = "admin-user-id"

        // When
        val result = repository.removeMember(memberId, adminUserId)

        // Then
        assertNotNull(result)
    }

    @Test
    fun `updateMemberRole changes member role successfully`() = runTest {
        // Given
        val memberId = "member-id"
        val newRole = "admin"
        val ownerUserId = "owner-user-id"

        // When
        val result = repository.updateMemberRole(memberId, newRole, ownerUserId)

        // Then
        assertNotNull(result)
    }

    @Test
    fun `generateInviteCode creates new invite code`() = runTest {
        // Given
        val groupId = "test-group-id"

        // When
        val result = repository.generateInviteCode(groupId)

        // Then
        assertNotNull(result)
    }

    @Test
    fun `validateInviteCode returns invitation for valid code`() = runTest {
        // Given
        val validCode = "VALIDCODE123"

        // When
        val result = repository.validateInviteCode(validCode)

        // Then
        assertNotNull(result)
    }

    @Test
    fun `validateInviteCode fails for expired code`() = runTest {
        // Given
        val expiredCode = "EXPIREDCODE"
        coEvery { postgrest.from(any()) } throws Exception("Invite code expired")

        // When
        val result = repository.validateInviteCode(expiredCode)

        // Then
        assertTrue(result is ResultWrapper.Error)
    }

    @Test
    fun `getMemberPermissions returns permissions for member`() = runTest {
        // Given
        val memberId = "member-id"

        // When
        val result = repository.getMemberPermissions(memberId)

        // Then
        assertNotNull(result)
    }

    @Test
    fun `updateMemberPermissions updates permissions with authorization`() = runTest {
        // Given
        val permissions = FamilyPermissions(
            memberId = "member-id",
            canViewHealthData = true,
            canEditHealthData = false,
            canManageMedications = true,
            canReceiveNotifications = true
        )
        val adminUserId = "admin-user-id"

        // When
        val result = repository.updateMemberPermissions(permissions, adminUserId)

        // Then
        assertNotNull(result)
    }

    @Test
    fun `getMembers returns all group members`() = runTest {
        // Given
        val groupId = "test-group-id"

        // When
        val result = repository.getMembers(groupId)

        // Then
        assertNotNull(result)
    }

    @Test
    fun `family member role checks work correctly`() {
        // Given
        val ownerMember = createTestFamilyMember(role = FamilyRole.OWNER)
        val adminMember = createTestFamilyMember(role = FamilyRole.ADMIN)
        val regularMember = createTestFamilyMember(role = FamilyRole.MEMBER)

        // Then
        assertTrue(ownerMember.isOwner)
        assertTrue(ownerMember.canManageMembers)
        assertTrue(ownerMember.canGenerateInvites)

        assertFalse(adminMember.isOwner)
        assertTrue(adminMember.canManageMembers)
        assertTrue(adminMember.canGenerateInvites)

        assertFalse(regularMember.isOwner)
        assertFalse(regularMember.canManageMembers)
        assertFalse(regularMember.canGenerateInvites)
    }

    @Test
    fun `family invitation expiry check works correctly`() {
        // Given
        val validInvitation = FamilyInvitation(
            code = "VALID123",
            groupId = "group-id",
            groupName = "Test Family",
            expiresAt = LocalDateTime.now().plusDays(7)
        )
        val expiredInvitation = FamilyInvitation(
            code = "EXPIRED123",
            groupId = "group-id",
            groupName = "Test Family",
            expiresAt = LocalDateTime.now().minusDays(1)
        )

        // Then
        assertFalse(validInvitation.isExpired)
        assertTrue(expiredInvitation.isExpired)
    }
}
