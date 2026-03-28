package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.data.mapper.AuthMapper
import com.swastricare.health.data.remote.dto.auth.PhoneUpdateDto
import com.swastricare.health.domain.model.AuthCredentials
import com.swastricare.health.domain.model.EmailVerification
import com.swastricare.health.domain.model.SignUpData
import com.swastricare.health.domain.model.SignUpResult
import com.swastricare.health.domain.model.User
import com.swastricare.health.domain.repository.AuthRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.OtpType
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.gotrue.providers.Google
import io.github.jan.supabase.gotrue.providers.builtin.Email
import io.github.jan.supabase.gotrue.providers.builtin.IDToken
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Implementation of AuthRepository using Supabase.
 * Handles all authentication operations and session management.
 *
 * This implementation:
 * - Uses Supabase Auth for authentication
 * - Maps Supabase models to domain models
 * - Manages local data cleanup on sign out/delete
 * - Matches iOS AuthService.swift implementation
 */
@Singleton
class AuthRepositoryImpl @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val sharedPreferences: SharedPreferences
) : AuthRepository {

    override suspend fun getCurrentUser(): User? {
        val userInfo = supabaseClient.auth.currentUserOrNull()
        return userInfo?.let { AuthMapper.mapToDomain(it) }
    }

    override suspend fun checkSession(): User? {
        return try {
            withTimeout(5000) { // 5 second timeout matching iOS
                try {
                    val session = supabaseClient.auth.currentSessionOrNull()
                    if (session != null) {
                        session.user?.let { AuthMapper.mapToDomain(it) }
                    } else {
                        null
                    }
                } catch (e: Exception) {
                    null
                }
            }
        } catch (e: Exception) {
            // Timeout or other error - return null silently (like iOS)
            null
        }
    }

    override suspend fun signIn(credentials: AuthCredentials): User {
        supabaseClient.auth.signInWith(Email) {
            this.email = credentials.email
            this.password = credentials.password
        }

        val userInfo = supabaseClient.auth.currentUserOrNull()
            ?: throw Exception("Authentication failed")

        return AuthMapper.mapToDomain(userInfo)
    }

    override suspend fun signUp(signUpData: SignUpData): SignUpResult {
        supabaseClient.auth.signUpWith(Email) {
            this.email = signUpData.email
            this.password = signUpData.password
            this.data = buildJsonObject {
                put("full_name", signUpData.fullName)
                if (signUpData.phone.isNotBlank()) {
                    put("phone", signUpData.phone)
                }
            }
        }

        // If session is null after signup, user needs to verify email first
        val session = supabaseClient.auth.currentSessionOrNull()
        if (session == null) {
            return SignUpResult.EmailVerificationRequired(signUpData.email)
        }

        val userInfo = supabaseClient.auth.currentUserOrNull()
            ?: return SignUpResult.EmailVerificationRequired(signUpData.email)

        // Store phone in public.users table (matches iOS updatePublicUserPhone)
        if (signUpData.phone.isNotBlank()) {
            updatePublicUserPhone(userInfo.id, signUpData.phone)
        }

        return SignUpResult.Success(AuthMapper.mapToDomain(userInfo))
    }

    override suspend fun signInWithGoogle(idToken: String): User {
        supabaseClient.auth.signInWith(IDToken) {
            this.idToken = idToken
            provider = Google
        }

        val userInfo = supabaseClient.auth.currentUserOrNull()
            ?: throw Exception("Google sign-in failed")

        return AuthMapper.mapToDomain(userInfo)
    }

    override suspend fun verifyEmailOtp(verification: EmailVerification): User {
        supabaseClient.auth.verifyEmailOtp(
            type = OtpType.Email.SIGNUP,
            email = verification.email,
            token = verification.token
        )

        val userInfo = supabaseClient.auth.currentUserOrNull()
            ?: throw Exception("OTP verification succeeded but no user session found")

        return AuthMapper.mapToDomain(userInfo)
    }

    override suspend fun resendVerificationEmail(email: String) {
        supabaseClient.auth.resendEmail(OtpType.Email.SIGNUP, email = email)
    }

    override suspend fun resetPassword(email: String) {
        supabaseClient.auth.resetPasswordForEmail(email)
    }

    override suspend fun signOut() {
        supabaseClient.auth.signOut()
        clearLocalData()
    }

    override suspend fun deleteAccount() {
        // Call the delete-account edge function which uses the service_role key
        // to delete the user from auth.users (CASCADE handles all related data)
        val response = supabaseClient.functions.invoke("delete-account")
        val status = response.headers["status"]?.toIntOrNull()
            ?: response.status.value
        if (status !in 200..299) {
            throw Exception("Account deletion failed (status $status)")
        }

        // Server-side deletion succeeded — clean up locally
        try { supabaseClient.auth.signOut() } catch (_: Exception) {}
        clearLocalData()
    }

    /**
     * Update phone number in the public.users table.
     * Matches iOS: updatePublicUserPhone(userId:phone:)
     */
    private suspend fun updatePublicUserPhone(userId: String, phone: String) {
        try {
            supabaseClient.from("users")
                .update(PhoneUpdateDto(phone = phone)) {
                    filter { eq("id", userId) }
                }
        } catch (e: Exception) {
            // Non-fatal: phone update failure shouldn't block signup
            android.util.Log.w("AuthRepositoryImpl", "Failed to update phone in users table", e)
        }
    }

    /**
     * Clear all locally cached data on sign out / account deletion.
     * Removes health data, widget data, workout state, and notification prefs.
     */
    private fun clearLocalData() {
        sharedPreferences.edit().clear().apply()
    }
}
