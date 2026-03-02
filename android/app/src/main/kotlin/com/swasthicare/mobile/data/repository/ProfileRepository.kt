package com.swasthicare.mobile.data.repository

import android.util.Log
import com.swasthicare.mobile.data.model.HealthProfile
import com.swasthicare.mobile.data.model.Gender
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.storage.storage
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

interface ProfileRepository {
    suspend fun getHealthProfile(userId: String): HealthProfile?
    suspend fun createHealthProfile(profile: HealthProfile): HealthProfile
    suspend fun updateHealthProfile(profile: HealthProfile): HealthProfile

    /** Update user-level profile info (name, phone, bio, avatar) */
    suspend fun updateUserProfile(
        userId: String,
        fullName: String?,
        phone: String?,
        bio: String?,
        avatarUrl: String?
    )

    /** Upload avatar image to Supabase Storage and return the public URL */
    suspend fun uploadAvatar(userId: String, imageData: ByteArray, fileName: String): String
}

class MockProfileRepository : ProfileRepository {
    override suspend fun getHealthProfile(userId: String): HealthProfile? {
        return HealthProfile(
            userId = userId,
            fullName = "Alex Johnson",
            gender = Gender.Male,
            dateOfBirth = "1995-05-15",
            heightCm = 175.0,
            weightKg = 70.0,
            bloodType = "O+"
        )
    }

    override suspend fun createHealthProfile(profile: HealthProfile): HealthProfile = profile

    override suspend fun updateHealthProfile(profile: HealthProfile): HealthProfile = profile

    override suspend fun updateUserProfile(
        userId: String,
        fullName: String?,
        phone: String?,
        bio: String?,
        avatarUrl: String?
    ) {
        // No-op for mock
    }

    override suspend fun uploadAvatar(userId: String, imageData: ByteArray, fileName: String): String {
        return "https://placeholder.com/avatar.jpg"
    }
}

/**
 * Supabase-backed profile repository.
 * Reads/writes to `health_profiles` table and `avatars` storage bucket.
 */
class SupabaseProfileRepository(
    private val supabaseClient: SupabaseClient
) : ProfileRepository {

    override suspend fun getHealthProfile(userId: String): HealthProfile? {
        return try {
            supabaseClient.postgrest["health_profiles"]
                .select {
                    filter {
                        eq("user_id", userId)
                    }
                }
                .decodeSingleOrNull<HealthProfile>()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch health profile: ${e.message}")
            null
        }
    }

    override suspend fun createHealthProfile(profile: HealthProfile): HealthProfile {
        supabaseClient.postgrest["health_profiles"]
            .insert(profile)
        return profile
    }

    override suspend fun updateHealthProfile(profile: HealthProfile): HealthProfile {
        supabaseClient.postgrest["health_profiles"]
            .update(profile) {
                filter {
                    eq("user_id", profile.userId)
                }
            }
        return profile
    }

    override suspend fun updateUserProfile(
        userId: String,
        fullName: String?,
        phone: String?,
        bio: String?,
        avatarUrl: String?
    ) {
        // Build the JSON object manually so that null fields are truly omitted
        // from the payload, preventing them from overwriting existing data in Supabase.
        val updatePayload = buildJsonObject {
            if (fullName != null) put("full_name", fullName)
            if (phone != null) put("phone", phone)
            if (bio != null) put("bio", bio)
            if (avatarUrl != null) put("avatar_url", avatarUrl)
        }

        try {
            supabaseClient.postgrest["profiles"]
                .update(updatePayload) {
                    filter {
                        eq("id", userId)
                    }
                }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to update user profile: ${e.message}")
            throw e
        }
    }

    override suspend fun uploadAvatar(userId: String, imageData: ByteArray, fileName: String): String {
        val bucket = supabaseClient.storage["avatars"]
        val path = "$userId/$fileName"

        try {
            bucket.upload(path, imageData, upsert = true)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to upload avatar: ${e.message}")
            throw e
        }

        return bucket.publicUrl(path)
    }

    companion object {
        private const val TAG = "ProfileRepository"
    }
}
