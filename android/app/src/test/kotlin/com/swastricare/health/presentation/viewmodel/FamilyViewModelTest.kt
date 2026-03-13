package com.swastricare.health.presentation.viewmodel

import app.cash.turbine.test
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.FamilyGroup
import com.swastricare.health.domain.model.FamilyMember
import com.swastricare.health.domain.model.FamilyRole
import com.swastricare.health.domain.usecase.family.*
import com.swastricare.health.util.MainDispatcherRule
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.time.LocalDateTime

/**
 * Unit tests for FamilyViewModel.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class FamilyViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var createFamilyGroupUseCase: CreateFamilyGroupUseCase
    private lateinit var getFamilyGroupUseCase: GetFamilyGroupUseCase
    private lateinit var joinFamilyGroupUseCase: JoinFamilyGroupUseCase
    private lateinit var getFamilyMembersUseCase: GetFamilyMembersUseCase
    private lateinit var generateInviteCodeUseCase: GenerateInviteCodeUseCase
    private lateinit var viewModel: FamilyViewModel

    @Before
    fun setup() {
        createFamilyGroupUseCase = mockk()
        getFamilyGroupUseCase = mockk()
        joinFamilyGroupUseCase = mockk()
        getFamilyMembersUseCase = mockk()
        generateInviteCodeUseCase = mockk()

        viewModel = FamilyViewModel(
            createFamilyGroupUseCase = createFamilyGroupUseCase,
            getFamilyGroupUseCase = getFamilyGroupUseCase,
            joinFamilyGroupUseCase = joinFamilyGroupUseCase,
            getFamilyMembersUseCase = getFamilyMembersUseCase,
            generateInviteCodeUseCase = generateInviteCodeUseCase
        )
    }

    private fun createTestFamilyGroup() = FamilyGroup(
        id = "group-id",
        name = "Test Family",
        createdBy = "user-id",
        inviteCode = "TEST123",
        createdAt = LocalDateTime.now()
    )

    private fun createTestFamilyMember(role: FamilyRole = FamilyRole.MEMBER) = FamilyMember(
        id = "member-id",
        groupId = "group-id",
        userId = "user-id",
        role = role,
        fullName = "Test User",
        joinedAt = LocalDateTime.now()
    )

    @Test
    fun `createFamilyGroup creates group successfully`() = runTest {
        // Given
        val groupName = "My Family"
        val userId = "user-id"
        val expectedGroup = createTestFamilyGroup()
        coEvery { createFamilyGroupUseCase(groupName, userId) } returns
            ResultWrapper.Success(expectedGroup)

        // When
        viewModel.uiState.test {
            viewModel.createFamilyGroup(groupName, userId)

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val successState = awaitItem()
            assertFalse(successState.isLoading)
            assertEquals(expectedGroup, successState.currentGroup)
            assertNull(successState.error)
        }
    }

    @Test
    fun `loadFamilyGroup loads group and members`() = runTest {
        // Given
        val userId = "user-id"
        val expectedGroup = createTestFamilyGroup()
        val expectedMembers = listOf(
            createTestFamilyMember(FamilyRole.OWNER),
            createTestFamilyMember(FamilyRole.MEMBER)
        )
        coEvery { getFamilyGroupUseCase(userId) } returns ResultWrapper.Success(expectedGroup)
        coEvery { getFamilyMembersUseCase(expectedGroup.id) } returns
            ResultWrapper.Success(expectedMembers)

        // When
        viewModel.uiState.test {
            viewModel.loadFamilyGroup(userId)

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val successState = awaitItem()
            assertFalse(successState.isLoading)
            assertEquals(expectedGroup, successState.currentGroup)
            assertEquals(2, successState.members.size)
        }
    }

    @Test
    fun `joinGroup joins family with invite code`() = runTest {
        // Given
        val inviteCode = "TEST123"
        val userId = "user-id"
        val fullName = "New Member"
        val expectedGroup = createTestFamilyGroup()
        coEvery { joinFamilyGroupUseCase(inviteCode, userId, fullName) } returns
            ResultWrapper.Success(expectedGroup)

        // When
        viewModel.uiState.test {
            viewModel.joinGroup(inviteCode, userId, fullName)

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val successState = awaitItem()
            assertFalse(successState.isLoading)
            assertEquals(expectedGroup, successState.currentGroup)
        }
    }

    @Test
    fun `generateInviteCode creates new code`() = runTest {
        // Given
        val groupId = "group-id"
        val newInviteCode = "NEWINVITE123"
        coEvery { generateInviteCodeUseCase(groupId) } returns
            ResultWrapper.Success(newInviteCode)

        // When
        viewModel.uiState.test {
            viewModel.generateInviteCode(groupId)

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val successState = awaitItem()
            assertFalse(successState.isLoading)
            assertEquals(newInviteCode, successState.inviteCode)
        }
    }

    @Test
    fun `error state is set when operation fails`() = runTest {
        // Given
        val userId = "user-id"
        val errorMessage = "Failed to load family group"
        coEvery { getFamilyGroupUseCase(userId) } returns ResultWrapper.Error(errorMessage)

        // When
        viewModel.uiState.test {
            viewModel.loadFamilyGroup(userId)

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val errorState = awaitItem()
            assertFalse(errorState.isLoading)
            assertNotNull(errorState.error)
            assertTrue(errorState.error!!.contains(errorMessage))
        }
    }
}
