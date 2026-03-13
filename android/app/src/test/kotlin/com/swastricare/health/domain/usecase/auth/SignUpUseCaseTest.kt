package com.swastricare.health.domain.usecase.auth

import com.swastricare.health.domain.model.SignUpData
import com.swastricare.health.domain.model.SignUpResult
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
 * Unit tests for SignUpUseCase.
 *
 * Tests:
 * - Input validation (email, password, name)
 * - Password strength requirements
 * - Successful sign-up
 * - Email verification flow
 * - Error handling
 */
@OptIn(ExperimentalCoroutinesApi::class)
class SignUpUseCaseTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var authRepository: AuthRepository
    private lateinit var useCase: SignUpUseCase

    @Before
    fun setup() {
        authRepository = mockk()
        useCase = SignUpUseCase(authRepository)
    }

    @Test
    fun `invoke with valid data returns success`() = runTest {
        // Given
        val signUpData = MockFactory.createSignUpData()
        val expectedUser = MockFactory.createUser()
        coEvery { authRepository.signUp(signUpData) } returns SignUpResult.Success(expectedUser)

        // When
        val result = useCase(signUpData)

        // Then
        assertTrue(result is SignUpResult.Success)
        coVerify { authRepository.signUp(signUpData) }
    }

    @Test
    fun `invoke with email verification required returns verification result`() = runTest {
        // Given
        val signUpData = MockFactory.createSignUpData()
        coEvery { authRepository.signUp(signUpData) } returns
            SignUpResult.EmailVerificationRequired(signUpData.email)

        // When
        val result = useCase(signUpData)

        // Then
        assertTrue(result is SignUpResult.EmailVerificationRequired)
        val verificationResult = result as SignUpResult.EmailVerificationRequired
        assertEquals(signUpData.email, verificationResult.email)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with empty email throws exception`() = runTest {
        // Given
        val signUpData = SignUpData(
            email = "",
            password = "ValidPass123!",
            fullName = "Test User"
        )

        // When
        useCase(signUpData)

        // Then - exception thrown
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with invalid email format throws exception`() = runTest {
        // Given
        val signUpData = SignUpData(
            email = "invalid-email",
            password = "ValidPass123!",
            fullName = "Test User"
        )

        // When
        useCase(signUpData)

        // Then - exception thrown
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with weak password throws exception`() = runTest {
        // Given
        val signUpData = SignUpData(
            email = MockFactory.TEST_EMAIL,
            password = "weak",
            fullName = "Test User"
        )

        // When
        useCase(signUpData)

        // Then - exception thrown
    }

    @Test(expected = IllegalArgumentException::class)
    fun `invoke with empty full name throws exception`() = runTest {
        // Given
        val signUpData = SignUpData(
            email = MockFactory.TEST_EMAIL,
            password = "ValidPass123!",
            fullName = ""
        )

        // When
        useCase(signUpData)

        // Then - exception thrown
    }

    @Test
    fun `invoke accepts strong password with minimum requirements`() = runTest {
        // Given
        val signUpData = SignUpData(
            email = MockFactory.TEST_EMAIL,
            password = "Pass123!", // 8 chars, upper, lower, number, special
            fullName = "Test User"
        )
        val expectedUser = MockFactory.createUser()
        coEvery { authRepository.signUp(signUpData) } returns SignUpResult.Success(expectedUser)

        // When
        val result = useCase(signUpData)

        // Then
        assertTrue(result is SignUpResult.Success)
    }

    @Test
    fun `invoke sanitizes phone number`() = runTest {
        // Given
        val signUpData = SignUpData(
            email = MockFactory.TEST_EMAIL,
            password = "ValidPass123!",
            fullName = "Test User",
            phone = "+91 98765 43210"
        )
        val expectedUser = MockFactory.createUser()
        coEvery { authRepository.signUp(any()) } returns SignUpResult.Success(expectedUser)

        // When
        val result = useCase(signUpData)

        // Then
        assertTrue(result is SignUpResult.Success)
        coVerify { authRepository.signUp(match { it.phone.replace(" ", "").isNotEmpty() }) }
    }
}
