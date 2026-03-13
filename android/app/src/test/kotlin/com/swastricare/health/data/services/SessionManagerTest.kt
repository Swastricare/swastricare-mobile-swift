package com.swastricare.health.data.services

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.gotrue.SessionStatus
import io.github.jan.supabase.gotrue.auth
import io.mockk.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SessionManagerTest {

    private val testDispatcher = UnconfinedTestDispatcher()
    private lateinit var supabaseClient: SupabaseClient
    private lateinit var authPlugin: Auth
    private lateinit var sessionStatusFlow: MutableStateFlow<SessionStatus>

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        sessionStatusFlow = MutableStateFlow(SessionStatus.LoadingFromStorage)
        authPlugin = mockk {
            every { sessionStatus } returns sessionStatusFlow
        }
        supabaseClient = mockk()
        mockkStatic("io.github.jan.supabase.gotrue.AuthKt")
        every { supabaseClient.auth } returns authPlugin
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        unmockkStatic("io.github.jan.supabase.gotrue.AuthKt")
    }

    @Test
    fun `initial state is not expired`() = runTest {
        val sessionManager = SessionManager(supabaseClient)
        advanceUntilIdle()
        assertFalse(sessionManager.isSessionExpired.value)
        sessionManager.cleanup()
    }

    @Test
    fun `authenticated then token expiry marks session expired`() = runTest {
        val sessionManager = SessionManager(supabaseClient)
        advanceUntilIdle()

        // User authenticates
        sessionStatusFlow.value = SessionStatus.Authenticated(mockk())
        advanceUntilIdle()

        // Token expires (not a sign-out)
        sessionStatusFlow.value = SessionStatus.NotAuthenticated(isSignOut = false)
        advanceUntilIdle()

        assertTrue(sessionManager.isSessionExpired.value)
        sessionManager.cleanup()
    }

    @Test
    fun `explicit sign-out does not mark session expired`() = runTest {
        val sessionManager = SessionManager(supabaseClient)
        advanceUntilIdle()

        // User authenticates
        sessionStatusFlow.value = SessionStatus.Authenticated(mockk())
        advanceUntilIdle()

        // User signs out explicitly
        sessionStatusFlow.value = SessionStatus.NotAuthenticated(isSignOut = true)
        advanceUntilIdle()

        assertFalse(sessionManager.isSessionExpired.value)
        sessionManager.cleanup()
    }

    @Test
    fun `initial NotAuthenticated does not mark expired`() = runTest {
        val sessionManager = SessionManager(supabaseClient)
        advanceUntilIdle()

        // Cold launch — never authenticated, goes to NotAuthenticated
        sessionStatusFlow.value = SessionStatus.NotAuthenticated(isSignOut = false)
        advanceUntilIdle()

        assertFalse(sessionManager.isSessionExpired.value)
        sessionManager.cleanup()
    }

    @Test
    fun `clearExpiredFlag resets state`() = runTest {
        val sessionManager = SessionManager(supabaseClient)
        advanceUntilIdle()

        // Authenticate then expire
        sessionStatusFlow.value = SessionStatus.Authenticated(mockk())
        advanceUntilIdle()
        sessionStatusFlow.value = SessionStatus.NotAuthenticated(isSignOut = false)
        advanceUntilIdle()
        assertTrue(sessionManager.isSessionExpired.value)

        // Clear
        sessionManager.clearExpiredFlag()
        assertFalse(sessionManager.isSessionExpired.value)

        sessionManager.cleanup()
    }

    @Test
    fun `network error does not mark session expired`() = runTest {
        val sessionManager = SessionManager(supabaseClient)
        advanceUntilIdle()

        // Authenticate then network error
        sessionStatusFlow.value = SessionStatus.Authenticated(mockk())
        advanceUntilIdle()
        sessionStatusFlow.value = SessionStatus.NetworkError
        advanceUntilIdle()

        assertFalse(sessionManager.isSessionExpired.value)
        sessionManager.cleanup()
    }

    @Test
    fun `re-authentication clears expired flag`() = runTest {
        val sessionManager = SessionManager(supabaseClient)
        advanceUntilIdle()

        // Authenticate → expire → re-authenticate
        sessionStatusFlow.value = SessionStatus.Authenticated(mockk())
        advanceUntilIdle()
        sessionStatusFlow.value = SessionStatus.NotAuthenticated(isSignOut = false)
        advanceUntilIdle()
        assertTrue(sessionManager.isSessionExpired.value)

        sessionStatusFlow.value = SessionStatus.Authenticated(mockk())
        advanceUntilIdle()
        assertFalse(sessionManager.isSessionExpired.value)

        sessionManager.cleanup()
    }
}
