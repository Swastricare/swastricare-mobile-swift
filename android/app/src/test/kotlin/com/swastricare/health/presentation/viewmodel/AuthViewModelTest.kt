package com.swastricare.health.presentation.viewmodel

import app.cash.turbine.test
import com.swastricare.health.domain.model.AuthCredentials
import com.swastricare.health.domain.model.SignUpData
import com.swastricare.health.domain.model.SignUpResult
import com.swastricare.health.domain.usecase.auth.*
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
 * Unit tests for AuthViewModel.
 *
 * Tests:
 * - Sign-in flow
 * - Sign-up flow
 * - Email verification
 * - Password reset
 * - Session management
 * - Error states
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AuthViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var signInUseCase: SignInUseCase
    private lateinit var signUpUseCase: SignUpUseCase
    private lateinit var signOutUseCase: SignOutUseCase
    private lateinit var getCurrentUserUseCase: GetCurrentUserUseCase
    private lateinit var verifyEmailOtpUseCase: VerifyEmailOtpUseCase
    private lateinit var resetPasswordUseCase: ResetPasswordUseCase
    private lateinit var viewModel: AuthViewModel

    @Before
    fun setup() {
        signInUseCase = mockk()
        signUpUseCase = mockk()
        signOutUseCase = mockk()
        getCurrentUserUseCase = mockk()
        verifyEmailOtpUseCase = mockk()
        resetPasswordUseCase = mockk()

        viewModel = AuthViewModel(
            signInUseCase = signInUseCase,
            signUpUseCase = signUpUseCase,
            signOutUseCase = signOutUseCase,
            getCurrentUserUseCase = getCurrentUserUseCase,
            verifyEmailOtpUseCase = verifyEmailOtpUseCase,
            resetPasswordUseCase = resetPasswordUseCase
        )
    }

    @Test
    fun `signIn with valid credentials updates state to success`() = runTest {
        // Given
        val credentials = MockFactory.createAuthCredentials()
        val expectedUser = MockFactory.createUser()
        coEvery { signInUseCase(credentials) } returns expectedUser

        // When
        viewModel.uiState.test {
            viewModel.signIn(credentials.email, credentials.password)

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val successState = awaitItem()
            assertFalse(successState.isLoading)
            assertEquals(expectedUser, successState.currentUser)
            assertNull(successState.error)
        }
    }

    @Test
    fun `signIn with invalid credentials updates state to error`() = runTest {
        // Given
        val credentials = MockFactory.createAuthCredentials()
        val errorMessage = "Invalid credentials"
        coEvery { signInUseCase(credentials) } throws Exception(errorMessage)

        // When
        viewModel.uiState.test {
            viewModel.signIn(credentials.email, credentials.password)

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val errorState = awaitItem()
            assertFalse(errorState.isLoading)
            assertNotNull(errorState.error)
            assertTrue(errorState.error!!.contains(errorMessage))
        }
    }

    @Test
    fun `signUp with auto-confirm updates state to success`() = runTest {
        // Given
        val signUpData = MockFactory.createSignUpData()
        val expectedUser = MockFactory.createUser()
        coEvery { signUpUseCase(signUpData) } returns SignUpResult.Success(expectedUser)

        // When
        viewModel.uiState.test {
            viewModel.signUp(
                signUpData.email,
                signUpData.password,
                signUpData.fullName,
                signUpData.phone
            )

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val successState = awaitItem()
            assertFalse(successState.isLoading)
            assertEquals(expectedUser, successState.currentUser)
        }
    }

    @Test
    fun `signUp requiring email verification updates state accordingly`() = runTest {
        // Given
        val signUpData = MockFactory.createSignUpData()
        coEvery { signUpUseCase(signUpData) } returns
            SignUpResult.EmailVerificationRequired(signUpData.email)

        // When
        viewModel.uiState.test {
            viewModel.signUp(
                signUpData.email,
                signUpData.password,
                signUpData.fullName,
                signUpData.phone
            )

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val verificationState = awaitItem()
            assertFalse(verificationState.isLoading)
            assertTrue(verificationState.isEmailVerificationRequired)
            assertEquals(signUpData.email, verificationState.pendingVerificationEmail)
        }
    }

    @Test
    fun `signOut clears current user`() = runTest {
        // Given
        coEvery { signOutUseCase() } just Runs

        // When
        viewModel.uiState.test {
            viewModel.signOut()

            // Then
            val state = awaitItem()
            assertNull(state.currentUser)
            assertFalse(state.isLoading)
        }
    }

    @Test
    fun `resetPassword sends reset email successfully`() = runTest {
        // Given
        val email = MockFactory.TEST_EMAIL
        coEvery { resetPasswordUseCase(email) } just Runs

        // When
        viewModel.uiState.test {
            viewModel.resetPassword(email)

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val successState = awaitItem()
            assertFalse(successState.isLoading)
            assertNull(successState.error)
        }
    }

    @Test
    fun `verifyEmailOtp with valid token updates state to success`() = runTest {
        // Given
        val email = MockFactory.TEST_EMAIL
        val token = "123456"
        val expectedUser = MockFactory.createUser()
        coEvery { verifyEmailOtpUseCase(email, token) } returns expectedUser

        // When
        viewModel.uiState.test {
            viewModel.verifyEmailOtp(email, token)

            // Then
            val loadingState = awaitItem()
            assertTrue(loadingState.isLoading)

            val successState = awaitItem()
            assertFalse(successState.isLoading)
            assertEquals(expectedUser, successState.currentUser)
            assertFalse(successState.isEmailVerificationRequired)
        }
    }

    @Test
    fun `clearError resets error state`() = runTest {
        // When
        viewModel.uiState.test {
            viewModel.clearError()

            // Then
            val state = awaitItem()
            assertNull(state.error)
        }
    }
}
