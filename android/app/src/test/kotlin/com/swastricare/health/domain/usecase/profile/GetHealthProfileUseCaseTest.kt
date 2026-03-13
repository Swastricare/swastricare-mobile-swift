package com.swastricare.health.domain.usecase.profile

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.profile.HealthProfile
import com.swastricare.health.domain.repository.ProfileRepository
import com.swastricare.health.util.MainDispatcherRule
import com.swastricare.health.util.MockFactory
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.time.LocalDate

/**
 * Unit tests for GetHealthProfileUseCase.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class GetHealthProfileUseCaseTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var profileRepository: ProfileRepository
    private lateinit var useCase: GetHealthProfileUseCase

    @Before
    fun setup() {
        profileRepository = mockk()
        useCase = GetHealthProfileUseCase(profileRepository)
    }

    private fun createTestHealthProfile() = HealthProfile(
        id = "profile-id",
        userId = MockFactory.TEST_USER_ID,
        dateOfBirth = LocalDate.of(1990, 1, 1),
        biologicalSex = "male",
        heightCm = 175.0,
        weightKg = 70.0,
        bloodType = "O+",
        allergies = listOf("Peanuts", "Dust"),
        chronicConditions = listOf("Asthma"),
        medications = emptyList()
    )

    @Test
    fun `invoke returns health profile when it exists`() = runTest {
        // Given
        val userId = MockFactory.TEST_USER_ID
        val expectedProfile = createTestHealthProfile()
        coEvery { profileRepository.getHealthProfile(userId) } returns
            ResultWrapper.Success(expectedProfile)

        // When
        val result = useCase(userId)

        // Then
        assertTrue(result is ResultWrapper.Success)
        val profile = (result as ResultWrapper.Success).data
        assertEquals(expectedProfile.id, profile?.id)
        assertEquals(expectedProfile.userId, profile?.userId)
        coVerify { profileRepository.getHealthProfile(userId) }
    }

    @Test
    fun `invoke returns null when profile does not exist`() = runTest {
        // Given
        val userId = MockFactory.TEST_USER_ID
        coEvery { profileRepository.getHealthProfile(userId) } returns
            ResultWrapper.Success(null)

        // When
        val result = useCase(userId)

        // Then
        assertTrue(result is ResultWrapper.Success)
        assertNull((result as ResultWrapper.Success).data)
    }

    @Test
    fun `invoke returns error on repository failure`() = runTest {
        // Given
        val userId = MockFactory.TEST_USER_ID
        coEvery { profileRepository.getHealthProfile(userId) } returns
            ResultWrapper.Error("Database error")

        // When
        val result = useCase(userId)

        // Then
        assertTrue(result is ResultWrapper.Error)
    }
}
