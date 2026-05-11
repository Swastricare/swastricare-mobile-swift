package com.swastricare.health.domain.repository

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.profile.HealthProfile
import com.swastricare.health.domain.model.profile.UserProfile
import com.swastricare.health.domain.model.profile.UserSettings

/**
 * Repository contract for Profile data.
 * Implemented in data layer.
 */
interface ProfileRepository {

    // ── User Profile ──

    /**
     * Get user profile by user ID.
     */
    suspend fun getUserProfile(userId: String): ResultWrapper<UserProfile?>

    /**
     * Update user profile information.
     */
    suspend fun updateUserProfile(
        userId: String,
        fullName: String?,
        phone: String?,
        bio: String?,
        avatarUrl: String?
    ): ResultWrapper<Unit>

    // ── Health Profile ──

    /**
     * Get health profile by user ID.
     */
    suspend fun getHealthProfile(userId: String): ResultWrapper<HealthProfile?>

    /**
     * Create a new health profile.
     */
    suspend fun createHealthProfile(profile: HealthProfile): ResultWrapper<HealthProfile>

    /**
     * Update existing health profile.
     */
    suspend fun updateHealthProfile(profile: HealthProfile): ResultWrapper<HealthProfile>

    // ── Avatar ──

    /**
     * Upload avatar image to storage and return the public URL.
     */
    suspend fun uploadAvatar(
        userId: String,
        imageData: ByteArray,
        fileName: String
    ): ResultWrapper<String>

    // ── Onboarding ──

    /**
     * Mark onboarding as complete in the users table.
     * Also syncs [fullName] if non-blank.
     * Failures are non-fatal — callers should proceed even on Error.
     */
    suspend fun markUserOnboardingComplete(
        userId: String,
        fullName: String?
    ): ResultWrapper<Unit>

    // ── Settings ──

    /**
     * Load user settings from local storage.
     */
    suspend fun getUserSettings(): ResultWrapper<UserSettings>

    /**
     * Save user settings to local storage.
     */
    suspend fun saveUserSettings(settings: UserSettings): ResultWrapper<Unit>
}
