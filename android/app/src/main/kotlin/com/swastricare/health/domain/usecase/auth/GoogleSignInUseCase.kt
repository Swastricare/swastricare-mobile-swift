package com.swastricare.health.domain.usecase.auth

import android.content.Context
import com.swastricare.health.data.helpers.GoogleAuthHelper
import com.swastricare.health.domain.model.User
import com.swastricare.health.domain.repository.AuthRepository
import javax.inject.Inject

/**
 * Use case for Google Sign-In.
 * Orchestrates the Google OAuth flow and Supabase authentication.
 *
 * Single Responsibility: Handle Google Sign-In flow
 */
class GoogleSignInUseCase @Inject constructor(
    private val authRepository: AuthRepository,
    private val googleAuthHelper: GoogleAuthHelper
) {
    /**
     * Execute Google Sign-In operation.
     * @param activityContext Activity context required for Credential Manager UI
     * @return Authenticated User
     * @throws Exception if Google sign-in fails
     */
    suspend operator fun invoke(activityContext: Context): User {
        // Step 1: Get Google ID token using Credential Manager
        val idToken = googleAuthHelper.signIn(activityContext)

        // Step 2: Sign in with Supabase using the ID token
        return authRepository.signInWithGoogle(idToken)
    }

    /**
     * Check if Google Sign-In is configured.
     */
    val isConfigured: Boolean
        get() = googleAuthHelper.isConfigured
}
