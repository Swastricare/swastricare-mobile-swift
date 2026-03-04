package com.swasthicare.mobile.data.services

import android.util.Log
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.SessionStatus
import io.github.jan.supabase.gotrue.auth
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Observes the Supabase auth session status and detects session expiry.
 *
 * When a user is authenticated and their session later becomes NotAuthenticated
 * (e.g. the refresh token expires), [isSessionExpired] emits `true` so the UI
 * can navigate back to the login screen.
 *
 * The initial NotAuthenticated state (before the user has ever logged in) is
 * intentionally ignored to avoid a false-positive redirect on cold launch.
 */
class SessionManager(
    private val supabaseClient: SupabaseClient
) {
    companion object {
        private const val TAG = "SessionManager"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private val _isSessionExpired = MutableStateFlow(false)

    /** True when the session transitioned from Authenticated to NotAuthenticated. */
    val isSessionExpired: StateFlow<Boolean> = _isSessionExpired.asStateFlow()

    /** Tracks whether the user was previously authenticated in this app session. */
    private var wasAuthenticated = false

    init {
        observeSessionStatus()
    }

    private fun observeSessionStatus() {
        scope.launch {
            supabaseClient.auth.sessionStatus.collect { status ->
                when (status) {
                    is SessionStatus.Authenticated -> {
                        Log.d(TAG, "Session status: Authenticated")
                        wasAuthenticated = true
                        // Reset expired flag when a valid session is established
                        _isSessionExpired.value = false
                    }

                    is SessionStatus.NotAuthenticated -> {
                        if (wasAuthenticated && !status.isSignOut) {
                            // Token refresh failed — session genuinely expired
                            Log.w(TAG, "Session expired — was previously authenticated, not a sign-out")
                            _isSessionExpired.value = true
                        } else if (wasAuthenticated && status.isSignOut) {
                            // Explicit sign-out — handled by the sign-out flow, no redirect needed
                            Log.d(TAG, "Session status: NotAuthenticated (explicit sign-out)")
                        } else {
                            Log.d(TAG, "Session status: NotAuthenticated (initial — no redirect)")
                        }
                    }

                    is SessionStatus.LoadingFromStorage -> {
                        Log.d(TAG, "Session status: LoadingFromStorage")
                    }

                    is SessionStatus.NetworkError -> {
                        Log.w(TAG, "Session status: NetworkError — keeping current state")
                        // Do NOT mark as expired on network errors; the token may still
                        // be valid once connectivity is restored.
                    }
                }
            }
        }
    }

    /**
     * Call after the sign-out flow completes so the next launch does not
     * immediately show a "session expired" redirect.
     */
    fun clearExpiredFlag() {
        _isSessionExpired.value = false
        wasAuthenticated = false
    }
}
