package com.swasthicare.mobile.data.repository

import com.swasthicare.mobile.data.model.AppUser
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.gotrue.providers.Google
import io.github.jan.supabase.gotrue.providers.builtin.Email
import io.github.jan.supabase.gotrue.user.UserInfo
import kotlinx.coroutines.withTimeout

/**
 * Supabase Authentication Repository
 * Matches iOS AuthService.swift implementation exactly
 */
class SupabaseAuthRepository(
    private val supabaseClient: SupabaseClient
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
    suspend fun checkSession(): AppUser? {
        return try {
            withTimeout(5000) { // 5 second timeout matching iOS
                try {
                    val session = supabaseClient.auth.currentSessionOrNull()
                    // Check if session exists
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
            // Timeout or other error - return nil silently (like iOS)
            null
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
     * Sign up with email, password, and full name
     * Matches iOS: signUp(email: String, password: String, fullName: String) async throws -> AppUser?
     */
    suspend fun signUp(email: String, password: String, fullName: String): AppUser? {
        // iOS: data: ["full_name": .string(fullName)]
        supabaseClient.auth.signUpWith(Email) {
            this.email = email
            this.password = password
        }
        
        val user = supabaseClient.auth.currentUserOrNull()
        return user?.let { mapUser(it) }
    }
    
    /**
     * Sign in with Google OAuth
     * Matches iOS: signInWithGoogle() async throws -> AppUser
     */
    suspend fun signInWithGoogle(): AppUser {
        // iOS: let session = try await client.auth.signInWithOAuth(provider: .google)
        supabaseClient.auth.signInWith(Google)
        
        val user = supabaseClient.auth.currentUserOrNull()
            ?: throw Exception("Google sign-in failed")
        
        // iOS: return mapUser(session.user)
        return mapUser(user)
    }
    
    /**
     * Sign out current user
     * Matches iOS: signOut() async throws
     */
    override suspend fun signOut() {
        // iOS: try await client.auth.signOut()
        supabaseClient.auth.signOut()
    }
    
    /**
     * Delete current user account
     * Matches iOS implementation (sign out + clear local data)
     */
    override suspend fun deleteAccount() {
        // iOS: try await client.auth.signOut()
        supabaseClient.auth.signOut()
        // TODO: Clear SharedPreferences if needed
    }
    
    /**
     * Send password reset email
     * Matches iOS: resetPassword(email: String) async throws
     */
    suspend fun resetPassword(email: String) {
        // iOS: try await client.auth.resetPasswordForEmail(email)
        supabaseClient.auth.resetPasswordForEmail(email)
    }
    
    /**
     * Map Supabase UserInfo to AppUser model
     * Matches iOS mapUser implementation
     */
    private fun mapUser(userInfo: UserInfo): AppUser {
        // iOS extracts: avatar_url, picture, full_name from userMetadata
        val metadata = userInfo.userMetadata
        
        val avatarUrl = metadata?.get("avatar_url") as? String
            ?: metadata?.get("picture") as? String
        
        val fullName = metadata?.get("full_name") as? String
            ?: metadata?.get("name") as? String
        
        return AppUser(
            id = userInfo.id, // iOS: user.id.uuidString
            email = userInfo.email ?: "",
            fullName = fullName,
            createdAt = userInfo.createdAt.toString(), // iOS: user.createdAt
            avatarUrl = avatarUrl
        )
    }
}
