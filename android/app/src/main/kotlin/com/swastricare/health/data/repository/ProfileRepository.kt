package com.swastricare.health.data.repository

import android.util.Log
import com.swastricare.health.data.model.HealthProfile
import com.swastricare.health.data.model.Gender
import com.swastricare.health.data.model.UserProfileRow
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.storage.storage
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

interface ProfileRepository {
    /** Fetch basic profile row (name, avatar) from the `profiles` table. */
    suspend fun getUserProfileRow(userId: String): UserProfileRow?
    suspend fun getHealthProfile(userId: String): HealthProfile?
    suspend fun createHealthProfile(profile: HealthProfile): Result<HealthProfile>
    suspend fun updateHealthProfile(profile: HealthProfile): Result<HealthProfile>

    /** Update user-level profile info (name, phone, bio, avatar) */
    suspend fun updateUserProfile(
        userId: String,
        fullName: String?,
        phone: String?,
        bio: String?,
        avatarUrl: String?
    ): Result<Unit>

    /** Upload avatar image to Supabase Storage and return the public URL */
    suspend fun uploadAvatar(userId: String, imageData: ByteArray, fileName: String): Result<String>
}

class MockProfileRepository : ProfileRepository {
    override suspend fun getUserProfileRow(userId: String): UserProfileRow? {
        return UserProfileRow(id = userId, fullName = "Alex Johnson")
    }

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

    override suspend fun createHealthProfile(profile: HealthProfile): Result<HealthProfile> =
        Result.success(profile)

    override suspend fun updateHealthProfile(profile: HealthProfile): Result<HealthProfile> =
        Result.success(profile)

    override suspend fun updateUserProfile(
        userId: String,
        fullName: String?,
        phone: String?,
        bio: String?,
        avatarUrl: String?
    ): Result<Unit> {
        return Result.success(Unit)
    }

    override suspend fun uploadAvatar(userId: String, imageData: ByteArray, fileName: String): Result<String> {
        return Result.success("https://placeholder.com/avatar.jpg")
    }
}

/**
 * Supabase-backed profile repository.
 * Reads/writes to `health_profiles` table and `avatars` storage bucket.
 */
class SupabaseProfileRepository(
    private val supabaseClient: SupabaseClient
) : ProfileRepository {

    override suspend fun getUserProfileRow(userId: String): UserProfileRow? {
        return try {
            supabaseClient.postgrest["profiles"]
                .select {
                    filter {
                        eq("id", userId)
                    }
                }
                .decodeSingleOrNull<UserProfileRow>()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch user profile row: ${e.message}")
            null
        }
    }

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

    override suspend fun createHealthProfile(profile: HealthProfile): Result<HealthProfile> {
        return try {
            supabaseClient.postgrest["health_profiles"]
                .insert(profile)
            Result.success(profile)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to create health profile: ${e.message}")
            Result.failure(e)
        }
    }

    override suspend fun updateHealthProfile(profile: HealthProfile): Result<HealthProfile> {
        return try {
            supabaseClient.postgrest["health_profiles"]
                .update(profile) {
                    filter {
                        eq("user_id", profile.userId)
                    }
                }
            Result.success(profile)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to update health profile: ${e.message}")
            Result.failure(e)
        }
    }

    override suspend fun updateUserProfile(
        userId: String,
        fullName: String?,
        phone: String?,
        bio: String?,
        avatarUrl: String?
    ): Result<Unit> {
        // Build the JSON object manually so that null fields are truly omitted
        // from the payload, preventing them from overwriting existing data in Supabase.
        val updatePayload = buildJsonObject {
            if (fullName != null) put("full_name", fullName)
            if (phone != null) put("phone", phone)
            if (bio != null) put("bio", bio)
            if (avatarUrl != null) put("avatar_url", avatarUrl)
        }

        return try {
            supabaseClient.postgrest["profiles"]
                .update(updatePayload) {
                    filter {
                        eq("id", userId)
                    }
                }
            Result.success(Unit)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to update user profile: ${e.message}")
            Result.failure(e)
        }
    }

    override suspend fun uploadAvatar(userId: String, imageData: ByteArray, fileName: String): Result<String> {
        // Validate file extension
        val allowedExtensions = listOf("jpg", "jpeg", "png", "webp")
        val extension = fileName.substringAfterLast('.', "").lowercase()
        if (extension !in allowedExtensions) {
            return Result.failure(IllegalArgumentException("Only image files (jpg, png, webp) are allowed for avatars"))
        }

        val bucket = supabaseClient.storage["avatars"]
        val path = "$userId/$fileName"

        return try {
            // Delete existing file first, then upload fresh
            try { bucket.delete(path) } catch (_: Exception) {}
            bucket.upload(path, imageData)
            Result.success(bucket.publicUrl(path))
        } catch (e: Exception) {
            Log.w(TAG, "Failed to upload avatar: ${e.message}")
            Result.failure(e)
        }
    }

    companion object {
        private const val TAG = "ProfileRepository"
    }
}
