package com.swasthicare.mobile.data.repository

import com.swasthicare.mobile.data.model.AppUser
// import io.github.jan.supabase.auth.user.UserSession - Removed for UI-only mode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf

interface AuthRepository {
    // val session: Flow<UserSession?> 
    val currentUser: AppUser?
    
    suspend fun signOut()
    suspend fun deleteAccount()
}

class MockAuthRepository : AuthRepository {
    override val currentUser: AppUser?
        get() = AppUser(
            id = "mock-user-1",
            email = "demo@swasthicare.com",
            fullName = "Alex Johnson",
            createdAt = "2024-01-01T10:00:00Z",
            avatarUrl = null
        )

    override suspend fun signOut() {
        // No-op
    }

    override suspend fun deleteAccount() {
        // No-op
    }
}
