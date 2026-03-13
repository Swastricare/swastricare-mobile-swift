package com.swastricare.health.data.repository

import com.swastricare.health.core.logger.Logger
import com.swastricare.health.data.mapper.AuthMapper
import com.swastricare.health.data.remote.dto.auth.UserDto
import com.swastricare.health.domain.model.SignUpResult
import com.swastricare.health.util.MainDispatcherRule
import com.swastricare.health.util.MockFactory
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.gotrue.SessionStatus
import io.github.jan.supabase.gotrue.user.UserInfo
import io.github.jan.supabase.gotrue.user.UserSession
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test

/**
 * Unit tests for AuthRepositoryImpl.
 *
 * Tests:
 * - User session management
 * - Email/password sign-in
 * - Email/password sign-up
 * - Google OAuth sign-in
 * - Email verification (OTP)
 * - Password reset
 * - Sign-out
 * - Account deletion
 * - Error handling
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AuthRepositoryImplTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var supabaseClient: SupabaseClient
    private lateinit var auth: Auth
    private lateinit var logger: Logger
    private lateinit var repository: AuthRepositoryImpl
    private lateinit var sessionFlow: MutableStateFlow<SessionStatus>

    @Before
    fun setup() {
        supabaseClient = mockk(relaxed = true)
        auth = mockk(relaxed = true)
        logger = mockk(relaxed = true)

        every { supabaseClient.auth } returns auth

        // Mock session flow
        sessionFlow = MutableStateFlow<SessionStatus>(SessionStatus.NotAuthenticated)
        every { auth.sessionStatus } returns sessionFlow

        repository = AuthRepositoryImpl(
            supabaseClient = supabaseClient,
            logger = logger
        )
    }

    @Test
    fun `getCurrentUser returns user when session exists`() = runTest {
        // Given
        val mockUserInfo = mockk<UserInfo> {
            every { id } returns MockFactory.TEST_USER_ID
            every { email } returns MockFactory.TEST_EMAIL
        }
        val mockSession = mockk<UserSession> {
            every { user } returns mockUserInfo
        }
        sessionFlow.value = SessionStatus.Authenticated(mockSession)
        every { auth.currentUserOrNull() } returns mockUserInfo

        // When
        val result = repository.getCurrentUser()

        // Then
        assertNotNull(result)
        assertEquals(MockFactory.TEST_USER_ID, result?.id)
        assertEquals(MockFactory.TEST_EMAIL, result?.email)
    }

    @Test
    fun `getCurrentUser returns null when no session`() = runTest {
        // Given
        sessionFlow.value = SessionStatus.NotAuthenticated
        every { auth.currentUserOrNull() } returns null

        // When
        val result = repository.getCurrentUser()

        // Then
        assertNull(result)
    }

    @Test
    fun `signIn with valid credentials returns user`() = runTest {
        // Given
        val credentials = MockFactory.createAuthCredentials()
        val mockUserInfo = mockk<UserInfo> {
            every { id } returns MockFactory.TEST_USER_ID
            every { email } returns MockFactory.TEST_EMAIL
        }
        coEvery {
            auth.signInWith(any())
        } returns mockk {
            every { user } returns mockUserInfo
        }

        // When
        val result = repository.signIn(credentials)

        // Then
        assertNotNull(result)
        assertEquals(MockFactory.TEST_USER_ID, result.id)
        assertEquals(MockFactory.TEST_EMAIL, result.email)
        coVerify { auth.signInWith(any()) }
    }

    @Test(expected = Exception::class)
    fun `signIn with invalid credentials throws exception`() = runTest {
        // Given
        val credentials = MockFactory.createAuthCredentials(
            email = "invalid@example.com",
            password = "wrongpassword"
        )
        coEvery { auth.signInWith(any()) } throws Exception("Invalid credentials")

        // When
        repository.signIn(credentials)

        // Then - exception thrown
    }

    @Test
    fun `signUp with auto-confirm returns success with user`() = runTest {
        // Given
        val signUpData = MockFactory.createSignUpData()
        val mockUserInfo = mockk<UserInfo> {
            every { id } returns MockFactory.TEST_USER_ID
            every { email } returns MockFactory.TEST_EMAIL
        }
        coEvery {
            auth.signUpWith(any())
        } returns mockk {
            every { user } returns mockUserInfo
        }

        // When
        val result = repository.signUp(signUpData)

        // Then
        assertTrue(result is SignUpResult.Success)
        val successResult = result as SignUpResult.Success
        assertEquals(MockFactory.TEST_USER_ID, successResult.user.id)
        assertEquals(MockFactory.TEST_EMAIL, successResult.user.email)
    }

    @Test
    fun `signUp without auto-confirm returns email verification required`() = runTest {
        // Given
        val signUpData = MockFactory.createSignUpData()
        coEvery {
            auth.signUpWith(any())
        } returns mockk {
            every { user } returns null
        }

        // When
        val result = repository.signUp(signUpData)

        // Then
        assertTrue(result is SignUpResult.EmailVerificationRequired)
        val verificationResult = result as SignUpResult.EmailVerificationRequired
        assertEquals(signUpData.email, verificationResult.email)
    }

    @Test
    fun `signInWithGoogle with valid token returns user`() = runTest {
        // Given
        val idToken = "valid-google-id-token"
        val mockUserInfo = mockk<UserInfo> {
            every { id } returns MockFactory.TEST_USER_ID
            every { email } returns "googleuser@example.com"
        }
        coEvery {
            auth.signInWith(any())
        } returns mockk {
            every { user } returns mockUserInfo
        }

        // When
        val result = repository.signInWithGoogle(idToken)

        // Then
        assertNotNull(result)
        assertEquals(MockFactory.TEST_USER_ID, result.id)
        assertEquals("googleuser@example.com", result.email)
    }

    @Test
    fun `verifyEmailOtp with valid token returns user`() = runTest {
        // Given
        val verification = MockFactory.createEmailVerification()
        val mockUserInfo = mockk<UserInfo> {
            every { id } returns MockFactory.TEST_USER_ID
            every { email } returns MockFactory.TEST_EMAIL
        }
        coEvery {
            auth.verifyEmailOtp(any())
        } returns mockk {
            every { user } returns mockUserInfo
        }

        // When
        val result = repository.verifyEmailOtp(verification)

        // Then
        assertNotNull(result)
        assertEquals(MockFactory.TEST_USER_ID, result.id)
        assertEquals(MockFactory.TEST_EMAIL, result.email)
        coVerify { auth.verifyEmailOtp(any()) }
    }

    @Test(expected = Exception::class)
    fun `verifyEmailOtp with invalid token throws exception`() = runTest {
        // Given
        val verification = MockFactory.createEmailVerification(token = "000000")
        coEvery { auth.verifyEmailOtp(any()) } throws Exception("Invalid OTP")

        // When
        repository.verifyEmailOtp(verification)

        // Then - exception thrown
    }

    @Test
    fun `resendVerificationEmail sends email successfully`() = runTest {
        // Given
        val email = MockFactory.TEST_EMAIL
        coEvery { auth.resendEmail(any(), any()) } just Runs

        // When
        repository.resendVerificationEmail(email)

        // Then
        coVerify { auth.resendEmail(any(), any()) }
    }

    @Test
    fun `resetPassword sends reset email successfully`() = runTest {
        // Given
        val email = MockFactory.TEST_EMAIL
        coEvery { auth.resetPasswordForEmail(any()) } just Runs

        // When
        repository.resetPassword(email)

        // Then
        coVerify { auth.resetPasswordForEmail(email) }
    }

    @Test
    fun `signOut clears session successfully`() = runTest {
        // Given
        coEvery { auth.signOut() } just Runs

        // When
        repository.signOut()

        // Then
        coVerify { auth.signOut() }
    }

    @Test
    fun `deleteAccount removes user data and signs out`() = runTest {
        // Given
        val mockUserInfo = mockk<UserInfo> {
            every { id } returns MockFactory.TEST_USER_ID
        }
        every { auth.currentUserOrNull() } returns mockUserInfo
        coEvery { auth.signOut() } just Runs

        // When
        repository.deleteAccount()

        // Then
        coVerify { auth.signOut() }
    }

    @Test
    fun `checkSession validates active session`() = runTest {
        // Given
        val mockUserInfo = mockk<UserInfo> {
            every { id } returns MockFactory.TEST_USER_ID
            every { email } returns MockFactory.TEST_EMAIL
        }
        val mockSession = mockk<UserSession> {
            every { user } returns mockUserInfo
            every { expiresAt } returns System.currentTimeMillis() / 1000 + 3600 // Valid for 1 hour
        }
        sessionFlow.value = SessionStatus.Authenticated(mockSession)
        every { auth.currentSessionOrNull() } returns mockSession

        // When
        val result = repository.checkSession()

        // Then
        assertNotNull(result)
        assertEquals(MockFactory.TEST_USER_ID, result?.id)
    }

    @Test
    fun `checkSession returns null for expired session`() = runTest {
        // Given
        sessionFlow.value = SessionStatus.NotAuthenticated
        every { auth.currentSessionOrNull() } returns null

        // When
        val result = repository.checkSession()

        // Then
        assertNull(result)
    }
}
