package com.swastricare.health.domain.repository

import com.swastricare.health.domain.model.AuthCredentials
import com.swastricare.health.domain.model.EmailVerification
import com.swastricare.health.domain.model.SignUpData
import com.swastricare.health.domain.model.SignUpResult
import com.swastricare.health.domain.model.User

/**
 * Domain repository interface for authentication operations.
 * Defines the contract for auth-related operations without implementation details.
 *
 * This interface follows the Dependency Inversion Principle:
 * - Domain layer defines what it needs
 * - Data layer implements how to provide it
 */
interface AuthRepository {

    /**
     * Get the currently authenticated user, if any.
     * Returns null if no user is signed in.
     */
    suspend fun getCurrentUser(): User?

    /**
     * Check if there's an active session.
     * Validates the session with a timeout (5 seconds).
     * Returns null if session is expired or invalid.
     */
    suspend fun checkSession(): User?

    /**
     * Sign in with email and password.
     * @throws Exception if authentication fails
     */
    suspend fun signIn(credentials: AuthCredentials): User

    /**
     * Sign up with email, password, full name, and optional phone.
     * Returns SignUpResult which can be:
     * - Success with User (auto-confirmed)
     * - EmailVerificationRequired (manual confirmation needed)
     * @throws Exception if sign-up fails
     */
    suspend fun signUp(signUpData: SignUpData): SignUpResult

    /**
     * Sign in with Google OAuth using ID token.
     * @param idToken Google ID token from OAuth flow
     * @throws Exception if Google sign-in fails
     */
    suspend fun signInWithGoogle(idToken: String): User

    /**
     * Verify email with OTP token.
     * Called after user receives the 6-digit code via email.
     * @throws Exception if verification fails
     */
    suspend fun verifyEmailOtp(verification: EmailVerification): User

    /**
     * Resend verification email to the given address.
     * Use when the original OTP email was not received or has expired.
     * @throws Exception if resend fails
     */
    suspend fun resendVerificationEmail(email: String)

    /**
     * Send password reset email.
     * @throws Exception if reset request fails
     */
    suspend fun resetPassword(email: String)

    /**
     * Sign out current user.
     * Clears session and local data.
     * @throws Exception if sign-out fails
     */
    suspend fun signOut()

    /**
     * Delete current user account.
     * Removes all user data and signs out.
     * @throws Exception if deletion fails
     */
    suspend fun deleteAccount()
}
