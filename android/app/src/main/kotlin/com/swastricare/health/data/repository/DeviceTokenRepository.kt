package com.swastricare.health.data.repository

import android.util.Log
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for managing FCM device tokens in the Supabase `device_tokens` table.
 *
 * The table enforces UNIQUE (user_id, fcm_token), so we upsert with that conflict target
 * to update `app_version`, `device_model`, and `updated_at` (handled by a DB trigger)
 * whenever a token is refreshed.
 *
 * RLS policies in 20260512000003_device_tokens.sql restrict select/insert/update/delete
 * to rows where `user_id = auth.uid()`, so all calls require an authenticated session.
 */
@Singleton
class DeviceTokenRepository @Inject constructor(
    private val supabaseClient: SupabaseClient
) {
    companion object {
        private const val TAG = "DeviceTokenRepo"
        private const val TABLE = "device_tokens"
        private const val PLATFORM_ANDROID = "android"
        private const val ON_CONFLICT = "user_id,fcm_token"
    }

    /**
     * Upsert (or refresh) a token row for the given user.
     * Safe to call repeatedly with the same token — the DB trigger bumps `updated_at`.
     */
    suspend fun upsertToken(
        userId: String,
        token: String,
        appVersion: String?,
        deviceModel: String?
    ): Result<Unit> = runCatching {
        val row = DeviceTokenRow(
            userId = userId,
            fcmToken = token,
            platform = PLATFORM_ANDROID,
            appVersion = appVersion,
            deviceModel = deviceModel
        )
        supabaseClient.from(TABLE).upsert(row, onConflict = ON_CONFLICT)
        Log.d(TAG, "Upserted FCM token for user=$userId (model=$deviceModel, version=$appVersion)")
        Unit
    }.onFailure { e ->
        Log.e(TAG, "Failed to upsert device token", e)
    }

    /**
     * Remove a specific token for a user — call on sign-out before the auth context goes away.
     */
    suspend fun deleteToken(userId: String, token: String): Result<Unit> = runCatching {
        supabaseClient.from(TABLE).delete {
            filter {
                eq("user_id", userId)
                eq("fcm_token", token)
            }
        }
        Log.d(TAG, "Deleted FCM token for user=$userId")
        Unit
    }.onFailure { e ->
        Log.e(TAG, "Failed to delete device token", e)
    }

    @Serializable
    private data class DeviceTokenRow(
        @SerialName("user_id") val userId: String,
        @SerialName("fcm_token") val fcmToken: String,
        @SerialName("platform") val platform: String,
        @SerialName("app_version") val appVersion: String?,
        @SerialName("device_model") val deviceModel: String?
    )
}
