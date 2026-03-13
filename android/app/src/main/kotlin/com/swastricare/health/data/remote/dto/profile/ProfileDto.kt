package com.swastricare.health.data.remote.dto.profile

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTO for health_profiles table in Supabase.
 * Maps directly to database schema.
 */
@Serializable
data class HealthProfileDto(
    @SerialName("id")
    val id: String? = null,

    @SerialName("user_id")
    val userId: String,

    @SerialName("full_name")
    val fullName: String,

    @SerialName("gender")
    val gender: String,

    @SerialName("date_of_birth")
    val dateOfBirth: String, // yyyy-MM-dd

    @SerialName("height_cm")
    val heightCm: Double,

    @SerialName("weight_kg")
    val weightKg: Double,

    @SerialName("blood_type")
    val bloodType: String? = null,

    @SerialName("created_at")
    val createdAt: String? = null,

    @SerialName("updated_at")
    val updatedAt: String? = null
)

/**
 * DTO for profiles table in Supabase.
 * Represents basic user account information.
 */
@Serializable
data class UserProfileDto(
    @SerialName("id")
    val id: String,

    @SerialName("email")
    val email: String? = null,

    @SerialName("full_name")
    val fullName: String? = null,

    @SerialName("phone")
    val phone: String? = null,

    @SerialName("bio")
    val bio: String? = null,

    @SerialName("avatar_url")
    val avatarUrl: String? = null,

    @SerialName("created_at")
    val createdAt: String? = null
)

/**
 * DTO for user settings (stored in SharedPreferences).
 */
@Serializable
data class UserSettingsDto(
    @SerialName("notifications_enabled")
    val notificationsEnabled: Boolean = true,

    @SerialName("biometric_lock_enabled")
    val biometricLockEnabled: Boolean = false,

    @SerialName("health_sync_enabled")
    val healthSyncEnabled: Boolean = true,

    @SerialName("dark_mode_enabled")
    val darkModeEnabled: Boolean = false,

    @SerialName("reminder_frequency")
    val reminderFrequency: String = "moderate"
)
