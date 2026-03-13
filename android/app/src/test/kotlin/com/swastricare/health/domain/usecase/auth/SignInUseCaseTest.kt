package com.swastricare.health.domain.usecase.auth

import com.swastricare.health.domain.model.AuthCredentials
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.util.MainDispatcherRule
import com.swastricare.health.util.MockFactory
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test

/**
 * Unit tests for SignInUseCase.
 *
 * Tests:
 * - Email validation
 * - Password validation
 * - Successful sign-in
 * - Error handling
 */
@OptIn(ExperimentalCoroutinesApi::class)
class SignInUseCaseTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var authRepository: AuthRepository
    private lateinit var useCase: SignInUseCase

    @Before
    fun setup() {
        authRepository = mockk()
        useCase = SignInUseCase(authRepository)
    }

    @Test
    fun `invoke with valid credentials returns user`() = runTest {
        // Given
        val credentials = MockFactory.createAuthCredentials()
        val expectedUser = MockFactory.createUser()
        coEvery { authRepository.signIn(credentials) } returns expectedUser

        // When
        val result = useCase(credentials)

        // Then
        assertEquals(expectedUser, result)
        coVerify { authRepository.signIn(credentials) }
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with empty email throws exception`() = runTest {
        // Given
        val credentials = AuthCredentials(email = "", password = "password123")

        // When
        useCase(credentials)

        // Then - exception thrown
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with invalid email format throws exception`() = runTest {
        // Given
        val credentials = AuthCredentials(email = "invalid-email", password = "password123")

        // When
        useCase(credentials)

        // Then - exception thrown
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with empty password throws exception`() = runTest {
        // Given
        val credentials = AuthCredentials(email = MockFactory.TEST_EMAIL, password = "")

        // When
        useCase(credentials)

        // Then - exception thrown
    }

    @Test(expected = Exception::class)
    fun `invoke with invalid credentials throws exception from repository`() = runTest {
        // Given
        val credentials = MockFactory.createAuthCredentials()
        coEvery { authRepository.signIn(credentials) } throws Exception("Invalid credentials")

        // When
        useCase(credentials)

        // Then - exception thrown
    }

    @Test
    fun `invoke trims email whitespace`() = runTest {
        // Given
        val credentials = AuthCredentials(
            email = "  ${MockFactory.TEST_EMAIL}  ",
            password = "password123"
        )
        val expectedUser = MockFactory.createUser()
        coEvery { authRepository.signIn(any()) } returns expectedUser

        // When
        val result = useCase(credentials)

        // Then
        assertNotNull(result)
        coVerify { authRepository.signIn(match { it.email == MockFactory.TEST_EMAIL }) }
    }
}
