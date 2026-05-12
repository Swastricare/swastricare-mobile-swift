package com.swastricare.health.data.repository

import android.util.Log
import com.swastricare.health.data.model.EmergencyContact
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

    // ── Emergency Contacts ────────────────────────────────────────────────────

    /** Fetch all emergency contacts for a given health profile. */
    suspend fun getEmergencyContacts(healthProfileId: String): List<EmergencyContact>

    /** Insert a new emergency contact row. */
    suspend fun addEmergencyContact(contact: EmergencyContact): Result<EmergencyContact>

    /** Update an existing emergency contact by its id. */
    suspend fun updateEmergencyContact(contact: EmergencyContact): Result<Unit>

    /** Delete an emergency contact by id. */
    suspend fun deleteEmergencyContact(contactId: String): Result<Unit>
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

    override suspend fun getEmergencyContacts(healthProfileId: String): List<EmergencyContact> = emptyList()
    override suspend fun addEmergencyContact(contact: EmergencyContact): Result<EmergencyContact> = Result.success(contact)
    override suspend fun updateEmergencyContact(contact: EmergencyContact): Result<Unit> = Result.success(Unit)
    override suspend fun deleteEmergencyContact(contactId: String): Result<Unit> = Result.success(Unit)
}

/**
 * Supabase-backed profile repository.
 * Reads/writes to `health_profiles` table and `avatars` storage bucket.
 */
@javax.inject.Singleton
class SupabaseProfileRepository @javax.inject.Inject constructor(
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
            // Prefer the primary profile (set by the is_primary backfill migration).
            // A user may have multiple health_profiles rows from prior onboarding
            // attempts; without this filter we'd pick an arbitrary one and lose
            // access to medications/data tied to the canonical profile.
            val primary = supabaseClient.postgrest["health_profiles"]
                .select {
                    filter {
                        eq("user_id", userId)
                        eq("is_primary", true)
                    }
                }
                .decodeList<HealthProfile>()
                .firstOrNull()
            if (primary != null) return primary

            // Defensive fallback: no row marked primary — pick the oldest row
            // (matches the backfill migration's tiebreak rule).
            supabaseClient.postgrest["health_profiles"]
                .select {
                    filter { eq("user_id", userId) }
                    order("created_at", io.github.jan.supabase.postgrest.query.Order.ASCENDING)
                    limit(1)
                }
                .decodeList<HealthProfile>()
                .firstOrNull()
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
            // Use @SerialName values for gender to match DB enum
            val genderValue = when (profile.gender) {
                Gender.Male -> "male"
                Gender.Female -> "female"
                Gender.Other -> "other"
                Gender.PreferNotToSay -> "prefer_not_to_say"
            }
            val updatePayload = buildJsonObject {
                put("full_name", profile.fullName)
                put("gender", genderValue)
                put("date_of_birth", profile.dateOfBirth)
                put("height_cm", profile.heightCm)
                put("weight_kg", profile.weightKg)
                if (profile.bloodType != null) put("blood_type", profile.bloodType)
            }
            Log.d(TAG, "updateHealthProfile: userId=${profile.userId}, payload=$updatePayload")
            supabaseClient.postgrest["health_profiles"]
                .update(updatePayload) {
                    filter {
                        eq("user_id", profile.userId)
                    }
                }
            Log.d(TAG, "updateHealthProfile: SUCCESS")
            Result.success(profile)
        } catch (e: Exception) {
            Log.e(TAG, "updateHealthProfile FAILED: ${e.javaClass.simpleName}: ${e.message}")
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

    // ── Emergency Contacts ────────────────────────────────────────────────────

    override suspend fun getEmergencyContacts(healthProfileId: String): List<EmergencyContact> {
        return try {
            supabaseClient.postgrest["emergency_contacts"]
                .select {
                    filter { eq("health_profile_id", healthProfileId) }
                    order("priority", io.github.jan.supabase.postgrest.query.Order.ASCENDING)
                }
                .decodeList<EmergencyContact>()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch emergency contacts: ${e.message}")
            emptyList()
        }
    }

    override suspend fun addEmergencyContact(contact: EmergencyContact): Result<EmergencyContact> {
        return try {
            val inserted = supabaseClient.postgrest["emergency_contacts"]
                .insert(contact) { select() }
                .decodeSingle<EmergencyContact>()
            Result.success(inserted)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to add emergency contact: ${e.message}")
            Result.failure(e)
        }
    }

    override suspend fun updateEmergencyContact(contact: EmergencyContact): Result<Unit> {
        val id = contact.id ?: return Result.failure(IllegalArgumentException("Contact id is null"))
        return try {
            supabaseClient.postgrest["emergency_contacts"]
                .update(contact) {
                    filter { eq("id", id) }
                }
            Result.success(Unit)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to update emergency contact: ${e.message}")
            Result.failure(e)
        }
    }

    override suspend fun deleteEmergencyContact(contactId: String): Result<Unit> {
        return try {
            supabaseClient.postgrest["emergency_contacts"]
                .delete {
                    filter { eq("id", contactId) }
                }
            Result.success(Unit)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to delete emergency contact: ${e.message}")
            Result.failure(e)
        }
    }

    companion object {
        private const val TAG = "ProfileRepository"
    }
}
