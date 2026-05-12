package com.swastricare.health.data.services

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging
import com.swastricare.health.data.repository.DeviceTokenRepository
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
import kotlinx.coroutines.tasks.await

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
    private val supabaseClient: SupabaseClient,
    private val deviceTokenRepository: DeviceTokenRepository,
    private val applicationContext: Context
) {
    companion object {
        private const val TAG = "SessionManager"
    }

    private val job = SupervisorJob()
    private val scope = CoroutineScope(job + Dispatchers.Main.immediate)

    private val _isSessionExpired = MutableStateFlow(false)

    /** True when the session transitioned from Authenticated to NotAuthenticated. */
    val isSessionExpired: StateFlow<Boolean> = _isSessionExpired.asStateFlow()

    /** Tracks whether the user was previously authenticated in this app session. */
    private var wasAuthenticated = false

    /**
     * Tracks the user id we've already registered an FCM token for this process,
     * so we don't hammer Supabase on every transient session emission.
     */
    private var lastRegisteredFcmUserId: String? = null

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
                        // Register / refresh the FCM token for this user (once per process).
                        registerFcmTokenIfNeeded(status.session.user?.id)
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
                        // Allow re-registration on the next successful auth.
                        lastRegisteredFcmUserId = null
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

    /** Cancel the observation scope to prevent leaks. */
    fun cleanup() {
        job.cancel()
    }

    /**
     * Fetch the current FCM token and upsert it to Supabase for the given user.
     * No-op when [userId] is null or when we've already registered this user
     * in the current process lifetime.
     *
     * Failures are swallowed (logged only) — push registration must never block
     * the auth UI flow.
     */
    private fun registerFcmTokenIfNeeded(userId: String?) {
        if (userId.isNullOrBlank()) return
        if (userId == lastRegisteredFcmUserId) return
        lastRegisteredFcmUserId = userId

        scope.launch {
            try {
                val token = FirebaseMessaging.getInstance().token.await()
                val versionName = try {
                    applicationContext.packageManager
                        .getPackageInfo(applicationContext.packageName, 0)
                        .versionName
                } catch (e: PackageManager.NameNotFoundException) {
                    null
                }
                deviceTokenRepository.upsertToken(
                    userId = userId,
                    token = token,
                    appVersion = versionName,
                    deviceModel = Build.MODEL
                )
            } catch (e: Exception) {
                Log.w(TAG, "FCM token registration failed: ${e.message}")
                // Allow a retry on the next session emission (e.g. token refresh).
                lastRegisteredFcmUserId = null
            }
        }
    }
}
