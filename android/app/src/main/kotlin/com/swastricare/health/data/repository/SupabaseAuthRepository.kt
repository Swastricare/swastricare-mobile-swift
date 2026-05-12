package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.data.model.AppUser
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.OtpType
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.gotrue.providers.Google
import io.github.jan.supabase.gotrue.providers.builtin.Email
import io.github.jan.supabase.gotrue.providers.builtin.IDToken
import io.github.jan.supabase.gotrue.user.UserInfo
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from
import io.ktor.client.call.body
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase Authentication Repository
 * Matches iOS AuthService.swift implementation exactly
 */
@Singleton
class SupabaseAuthRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val sharedPreferences: SharedPreferences,
    private val cacheService: com.swastricare.health.data.services.CacheService
) : AuthRepository {
    
    override val currentUser: AppUser?
        get() {
            val user = supabaseClient.auth.currentUserOrNull()
            return user?.let { mapUser(it) }
        }
    
    /**
     * Check current session with timeout
     * Matches iOS: checkSession() async throws -> AppUser?
     */
    suspend fun checkSession(isOnline: Boolean = true): AppUser? {
        // When offline, trust the locally cached session
        if (!isOnline) {
            val user = supabaseClient.auth.currentUserOrNull()
            return user?.let { mapUser(it) }
        }

        // Online: check session with timeout
        return try {
            withTimeout(5000) {
                try {
                    val session = supabaseClient.auth.currentSessionOrNull()
                    if (session != null) {
                        session.user?.let { mapUser(it) }
                    } else {
                        null
                    }
                } catch (e: Exception) {
                    null
                }
            }
        } catch (e: Exception) {
            // Timeout — fall back to local session
            val user = supabaseClient.auth.currentUserOrNull()
            user?.let { mapUser(it) }
        }
    }
    
    /**
     * Sign in with email and password
     * Matches iOS: signIn(email: String, password: String) async throws -> AppUser
     */
    suspend fun signIn(email: String, password: String): AppUser {
        // iOS: let session = try await client.auth.signIn(email: email, password: password)
        supabaseClient.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
        
        val user = supabaseClient.auth.currentUserOrNull()
            ?: throw Exception("Authentication failed")
        
        // iOS: return mapUser(session.user)
        return mapUser(user)
    }
    
    /**
     * Sign up with email, password, full name, and optional phone
     * Matches iOS: signUp(email: String, password: String, fullName: String, phone: String) async throws -> AppUser?
     * Returns null if email verification is required (no session created).
     */
    suspend fun signUp(email: String, password: String, fullName: String, phone: String = ""): AppUser? {
        supabaseClient.auth.signUpWith(
            provider = Email,
            redirectUrl = "swastricareapp://auth-callback"
        ) {
            this.email = email
            this.password = password
            this.data = buildJsonObject {
                put("full_name", fullName)
                if (phone.isNotBlank()) put("phone", phone)
            }
        }

        // If session is null after signup, user needs to verify email first
        val session = supabaseClient.auth.currentSessionOrNull()
        if (session == null) return null

        val user = supabaseClient.auth.currentUserOrNull() ?: return null

        // Store phone in public.users table (matches iOS updatePublicUserPhone)
        if (phone.isNotBlank()) {
            updatePublicUserPhone(user.id, phone)
        }

        return mapUser(user)
    }

    /**
     * Update phone number in the public.users table.
     * Matches iOS: updatePublicUserPhone(userId:phone:)
     */
    private suspend fun updatePublicUserPhone(userId: String, phone: String) {
        try {
            supabaseClient.from("users")
                .update(PhoneUpdate(phone = phone)) {
                    filter { eq("id", userId) }
                }
        } catch (e: Exception) {
            // Non-fatal: phone update failure shouldn't block signup
            android.util.Log.w("AuthRepo", "Failed to update phone in users table", e)
        }
    }

    @Serializable
    private data class PhoneUpdate(val phone: String)
    
    /**
     * Sign in with Google OAuth using ID Token
     * Matches iOS: signInWithGoogle() async throws -> AppUser
     */
    suspend fun signInWithGoogle(idToken: String): AppUser {
        // Sign in with Supabase using Google ID token
        supabaseClient.auth.signInWith(IDToken) {
            this.idToken = idToken
            provider = Google
        }
        
        val user = supabaseClient.auth.currentUserOrNull()
            ?: throw Exception("Google sign-in failed")
        
        // Return mapped user
        return mapUser(user)
    }
    
    /**
     * Sign out current user
     * Matches iOS: signOut() async throws
     */
    override suspend fun signOut() {
        val userId = supabaseClient.auth.currentUserOrNull()?.id
        supabaseClient.auth.signOut()
        if (userId != null) {
            cacheService.clearAll(userId)
        }
        clearLocalData()
    }

    /**
     * Delete current user account via the delete-account edge function.
     * The edge function uses the service_role key to delete the user from
     * auth.users, and CASCADE constraints clean up all related data.
     */
    override suspend fun deleteAccount() {
        val userId = supabaseClient.auth.currentUserOrNull()?.id
        android.util.Log.d("SupabaseAuthRepo", "deleteAccount: invoking edge function for user=$userId")

        // Call the edge function that performs the actual deletion
        val response = try {
            supabaseClient.functions.invoke("delete-account")
        } catch (e: Exception) {
            android.util.Log.e("SupabaseAuthRepo", "functions.invoke threw: ${e.javaClass.simpleName}: ${e.message}", e)
            throw e
        }
        val status = response.status.value
        val bodyText = try { response.body<String>() } catch (_: Exception) { "<no body>" }
        android.util.Log.d("SupabaseAuthRepo", "delete-account response: status=$status body=$bodyText")
        if (status !in 200..299) {
            throw Exception("Account deletion failed (status $status): $bodyText")
        }

        // Server-side deletion succeeded — clean up locally
        if (userId != null) {
            cacheService.clearAll(userId)
        }
        try { supabaseClient.auth.signOut() } catch (_: Exception) {}
        clearLocalData()
    }

    /**
     * Clear all locally cached data on sign out / account deletion.
     * Removes health data, widget data, workout state, and notification prefs.
     */
    private fun clearLocalData() {
        sharedPreferences?.edit()?.clear()?.apply()
    }
    
    /**
     * Send password reset email
     * Matches iOS: resetPassword(email: String) async throws
     */
    suspend fun resetPassword(email: String) {
        // iOS: try await client.auth.resetPasswordForEmail(email)
        supabaseClient.auth.resetPasswordForEmail(
            email = email,
            redirectUrl = "swastricareapp://auth-callback"
        )
    }

    /**
     * Update the current user's password.
     * Called after the user opens a password recovery deep link and enters a new password.
     */
    suspend fun updatePassword(newPassword: String) {
        supabaseClient.auth.updateUser {
            password = newPassword
        }
    }

    /**
     * Update user metadata (name, phone, bio) stored in auth.users.user_metadata.
     */
    suspend fun updateUserMetadata(
        fullName: String? = null,
        phone: String? = null,
        bio: String? = null,
        city: String? = null
    ) {
        supabaseClient.auth.updateUser {
            data = buildJsonObject {
                if (fullName != null) put("full_name", fullName)
                if (phone != null) put("phone", phone)
                if (bio != null) put("bio", bio)
                if (city != null) put("city", city)
            }
        }
    }

    /**
     * Verify OTP token for email signup confirmation.
     * Called after the user enters the 6-digit code sent to their email.
     * Returns the AppUser once the session is established.
     */
    suspend fun verifyEmailOtp(email: String, token: String): AppUser {
        supabaseClient.auth.verifyEmailOtp(
            type = OtpType.Email.SIGNUP,
            email = email,
            token = token
        )
        val user = supabaseClient.auth.currentUserOrNull()
            ?: throw Exception("OTP verification succeeded but no user session found")
        return mapUser(user)
    }

    /**
     * Resend the signup verification email to the given address.
     * Use when the original OTP email was not received or has expired.
     */
    suspend fun resendVerificationEmail(email: String) {
        supabaseClient.auth.resendEmail(OtpType.Email.SIGNUP, email = email)
    }

    /**
     * Map Supabase UserInfo to AppUser model
     * Matches iOS mapUser implementation
     */
    private fun mapUser(userInfo: UserInfo): AppUser {
        // iOS extracts: avatar_url, picture, full_name, phone from userMetadata
        val metadata = userInfo.userMetadata

        val avatarUrl = metadata?.get("avatar_url")?.jsonPrimitive?.contentOrNull
            ?: metadata?.get("picture")?.jsonPrimitive?.contentOrNull

        val fullName = metadata?.get("full_name")?.jsonPrimitive?.contentOrNull
            ?: metadata?.get("name")?.jsonPrimitive?.contentOrNull

        val phone = userInfo.phone?.takeIf { it.isNotBlank() }
            ?: metadata?.get("phone")?.jsonPrimitive?.contentOrNull?.takeIf { it.isNotBlank() }

        val bio = metadata?.get("bio")?.jsonPrimitive?.contentOrNull
        val city = metadata?.get("city")?.jsonPrimitive?.contentOrNull

        return AppUser(
            id = userInfo.id,
            email = userInfo.email ?: "",
            fullName = fullName,
            phone = phone,
            bio = bio,
            city = city,
            createdAt = userInfo.createdAt.toString(),
            avatarUrl = avatarUrl
        )
    }
}
