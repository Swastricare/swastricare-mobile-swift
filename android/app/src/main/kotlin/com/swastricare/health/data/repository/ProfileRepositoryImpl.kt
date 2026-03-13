package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.mapper.ProfileMapper
import com.swastricare.health.data.remote.dto.profile.HealthProfileDto
import com.swastricare.health.data.remote.dto.profile.UserProfileDto
import com.swastricare.health.data.remote.dto.profile.UserSettingsDto
import com.swastricare.health.domain.model.profile.HealthProfile
import com.swastricare.health.domain.model.profile.UserProfile
import com.swastricare.health.domain.model.profile.UserSettings
import com.swastricare.health.domain.repository.ProfileRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.storage.storage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject

/**
 * Implementation of ProfileRepository.
 * Handles data persistence to SharedPreferences and Supabase.
 */
class ProfileRepositoryImpl @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val sharedPreferences: SharedPreferences,
    private val json: Json,
    private val logger: Logger
) : ProfileRepository {

    // ── User Profile ──

    override suspend fun getUserProfile(userId: String): ResultWrapper<UserProfile?> =
        withContext(Dispatchers.IO) {
            try {
                logger.d(TAG, "Fetching user profile for user: $userId")

                val dto = supabaseClient.from("profiles")
                    .select {
                        filter { eq("id", userId) }
                    }
                    .decodeSingleOrNull<UserProfileDto>()

                val profile = dto?.let { ProfileMapper.userProfileToDomain(it) }
                logger.d(TAG, "User profile fetched: ${profile != null}")

                ResultWrapper.Success(profile)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to fetch user profile", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    override suspend fun updateUserProfile(
        userId: String,
        fullName: String?,
        phone: String?,
        bio: String?,
        avatarUrl: String?
    ): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            logger.d(TAG, "Updating user profile for user: $userId")

            // Build the JSON object manually so that null fields are truly omitted
            val updatePayload = buildJsonObject {
                if (fullName != null) put("full_name", fullName)
                if (phone != null) put("phone", phone)
                if (bio != null) put("bio", bio)
                if (avatarUrl != null) put("avatar_url", avatarUrl)
            }

            supabaseClient.from("profiles")
                .update(updatePayload) {
                    filter { eq("id", userId) }
                }

            logger.d(TAG, "User profile updated successfully")
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to update user profile", e)
            ResultWrapper.Error(mapException(e))
        }
    }

    // ── Health Profile ──

    override suspend fun getHealthProfile(userId: String): ResultWrapper<HealthProfile?> =
        withContext(Dispatchers.IO) {
            try {
                logger.d(TAG, "Fetching health profile for user: $userId")

                val dto = supabaseClient.from("health_profiles")
                    .select {
                        filter { eq("user_id", userId) }
                    }
                    .decodeSingleOrNull<HealthProfileDto>()

                val profile = dto?.let { ProfileMapper.healthProfileToDomain(it) }
                logger.d(TAG, "Health profile fetched: ${profile != null}")

                ResultWrapper.Success(profile)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to fetch health profile", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    override suspend fun createHealthProfile(profile: HealthProfile): ResultWrapper<HealthProfile> =
        withContext(Dispatchers.IO) {
            try {
                logger.d(TAG, "Creating health profile for user: ${profile.userId}")

                val dto = ProfileMapper.healthProfileToDto(profile)
                supabaseClient.from("health_profiles").insert(dto)

                logger.d(TAG, "Health profile created successfully")
                ResultWrapper.Success(profile)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to create health profile", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    override suspend fun updateHealthProfile(profile: HealthProfile): ResultWrapper<HealthProfile> =
        withContext(Dispatchers.IO) {
            try {
                logger.d(TAG, "Updating health profile for user: ${profile.userId}")

                val dto = ProfileMapper.healthProfileToDto(profile)
                supabaseClient.from("health_profiles")
                    .update(dto) {
                        filter { eq("user_id", profile.userId) }
                    }

                logger.d(TAG, "Health profile updated successfully")
                ResultWrapper.Success(profile)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to update health profile", e)
                ResultWrapper.Error(mapException(e))
            }
        }

    // ── Avatar ──

    override suspend fun uploadAvatar(
        userId: String,
        imageData: ByteArray,
        fileName: String
    ): ResultWrapper<String> = withContext(Dispatchers.IO) {
        try {
            logger.d(TAG, "Uploading avatar for user: $userId")

            val bucket = supabaseClient.storage["avatars"]
            val path = "$userId/$fileName"

            // Delete existing file first, then upload fresh
            try {
                bucket.delete(path)
            } catch (_: Exception) {
                // Ignore delete errors
            }

            bucket.upload(path, imageData)
            val publicUrl = bucket.publicUrl(path)

            logger.d(TAG, "Avatar uploaded successfully: $publicUrl")
            ResultWrapper.Success(publicUrl)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to upload avatar", e)
            ResultWrapper.Error(mapException(e))
        }
    }

    // ── Settings ──

    override suspend fun getUserSettings(): ResultWrapper<UserSettings> =
        withContext(Dispatchers.IO) {
            try {
                val raw = sharedPreferences.getString(KEY_SETTINGS, null)
                    ?: return@withContext ResultWrapper.Success(UserSettings.Default)

                val dto = json.decodeFromString<UserSettingsDto>(raw)
                val settings = ProfileMapper.userSettingsToDomain(dto)

                ResultWrapper.Success(settings)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to load user settings", e)
                ResultWrapper.Success(UserSettings.Default)
            }
        }

    override suspend fun saveUserSettings(settings: UserSettings): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val dto = ProfileMapper.userSettingsToDto(settings)
                val encoded = json.encodeToString(dto)
                sharedPreferences.edit().putString(KEY_SETTINGS, encoded).apply()

                logger.d(TAG, "User settings saved successfully")
                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to save user settings", e)
                ResultWrapper.Error(AppException.UnknownException(e.message, e))
            }
        }

    // ── Helpers ──

    private fun mapException(e: Exception): AppException {
        return when {
            e.message?.contains("network", ignoreCase = true) == true ->
                AppException.NetworkException.Unknown(e)
            e.message?.contains("unauthorized", ignoreCase = true) == true ->
                AppException.ApiException.Unauthorized()
            e.message?.contains("not found", ignoreCase = true) == true ->
                AppException.ApiException.NotFound(e.message)
            else -> AppException.UnknownException(cause = e)
        }
    }

    companion object {
        private const val TAG = "ProfileRepository"
        private const val KEY_SETTINGS = "user_settings"
    }
}
