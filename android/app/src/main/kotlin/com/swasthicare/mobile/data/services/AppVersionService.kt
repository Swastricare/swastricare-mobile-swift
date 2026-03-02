package com.swasthicare.mobile.data.services

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Model for the app_versions Supabase table row.
 */
@Serializable
data class AppVersionInfo(
    val version: String,
    val platform: String,
    @SerialName("force_update")
    val forceUpdate: Boolean = false,
    @SerialName("optional_update")
    val optionalUpdate: Boolean = false,
    @SerialName("release_notes")
    val releaseNotes: String? = null,
    @SerialName("store_url")
    val storeUrl: String? = null,
    @SerialName("created_at")
    val createdAt: String = ""
)

/**
 * App update status enum.
 */
enum class AppUpdateStatus {
    UP_TO_DATE,
    OPTIONAL_UPDATE,
    FORCE_UPDATE
}

/**
 * Result containing the status and optional version info.
 */
data class AppUpdateCheckResult(
    val status: AppUpdateStatus,
    val versionInfo: AppVersionInfo? = null
)

/**
 * AppVersionService
 *
 * Checks Supabase app_versions table to determine if the user needs to update.
 * Caches results for 1 hour. Matches iOS AppVersionService behavior.
 */
class AppVersionService(
    private val context: Context,
    private val supabaseClient: SupabaseClient
) {
    companion object {
        private const val TAG = "AppVersionService"
        private const val PREFS_NAME = "swasthicare_version"
        private const val PREFS_KEY_CACHED_STATUS = "cached_update_status"
        private const val PREFS_KEY_CACHED_VERSION = "cached_version"
        private const val PREFS_KEY_CACHED_RELEASE_NOTES = "cached_release_notes"
        private const val PREFS_KEY_CACHED_STORE_URL = "cached_store_url"
        private const val PREFS_KEY_CACHED_FORCE = "cached_force_update"
        private const val PREFS_KEY_CACHED_OPTIONAL = "cached_optional_update"
        private const val PREFS_KEY_CACHE_TIMESTAMP = "cache_timestamp"
        private const val CACHE_TTL_MS = 60 * 60 * 1000L // 1 hour

        private const val PREFS_KEY_OPTIONAL_DISMISS_TIME = "optional_update_dismiss_time"
        private const val OPTIONAL_DISMISS_COOLDOWN_MS = 24 * 60 * 60 * 1000L // 24 hours
    }

    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    /**
     * Check for available updates. Uses cached result if within TTL.
     */
    suspend fun checkForUpdate(currentVersionName: String): AppUpdateCheckResult {
        // Check cache first
        val cached = getCachedResult()
        if (cached != null) {
            Log.d(TAG, "Using cached update check result: ${cached.status}")
            return cached
        }

        return try {
            val result = fetchAndCompare(currentVersionName)
            cacheResult(result)
            Log.d(TAG, "Fetched update check: ${result.status}")
            result
        } catch (e: Exception) {
            Log.w(TAG, "Failed to check for update: ${e.message}")
            AppUpdateCheckResult(status = AppUpdateStatus.UP_TO_DATE)
        }
    }

    /**
     * Whether the optional update dialog should be shown (not dismissed in last 24h).
     */
    fun shouldShowOptionalUpdate(): Boolean {
        val lastDismissed = prefs.getLong(PREFS_KEY_OPTIONAL_DISMISS_TIME, 0L)
        return System.currentTimeMillis() - lastDismissed > OPTIONAL_DISMISS_COOLDOWN_MS
    }

    /**
     * Record that the user dismissed the optional update dialog.
     */
    fun dismissOptionalUpdate() {
        prefs.edit().putLong(PREFS_KEY_OPTIONAL_DISMISS_TIME, System.currentTimeMillis()).apply()
    }

    /**
     * Clear the cache so next check fetches from Supabase.
     */
    fun clearCache() {
        prefs.edit()
            .remove(PREFS_KEY_CACHE_TIMESTAMP)
            .remove(PREFS_KEY_CACHED_STATUS)
            .apply()
    }

    private suspend fun fetchAndCompare(currentVersionName: String): AppUpdateCheckResult {
        val response = supabaseClient.postgrest["app_versions"]
            .select {
                filter {
                    eq("platform", "android")
                }
                order("created_at", Order.DESCENDING)
                limit(1)
            }

        val versions = response.decodeList<AppVersionInfo>()
        if (versions.isEmpty()) {
            return AppUpdateCheckResult(status = AppUpdateStatus.UP_TO_DATE)
        }

        val serverVersion = versions.first()

        // Compare versions
        val comparison = compareVersions(currentVersionName, serverVersion.version)
        if (comparison >= 0) {
            // Current version is equal or newer
            return AppUpdateCheckResult(status = AppUpdateStatus.UP_TO_DATE)
        }

        // Server version is newer
        return when {
            serverVersion.forceUpdate -> AppUpdateCheckResult(
                status = AppUpdateStatus.FORCE_UPDATE,
                versionInfo = serverVersion
            )
            serverVersion.optionalUpdate -> AppUpdateCheckResult(
                status = AppUpdateStatus.OPTIONAL_UPDATE,
                versionInfo = serverVersion
            )
            else -> AppUpdateCheckResult(status = AppUpdateStatus.UP_TO_DATE)
        }
    }

    /**
     * Semantic version comparison. Returns:
     * - negative if current < server
     * - 0 if equal
     * - positive if current > server
     */
    private fun compareVersions(current: String, server: String): Int {
        val currentParts = current.split(".").map { it.toIntOrNull() ?: 0 }
        val serverParts = server.split(".").map { it.toIntOrNull() ?: 0 }

        val maxLen = maxOf(currentParts.size, serverParts.size)
        for (i in 0 until maxLen) {
            val c = currentParts.getOrElse(i) { 0 }
            val s = serverParts.getOrElse(i) { 0 }
            if (c != s) return c - s
        }
        return 0
    }

    private fun getCachedResult(): AppUpdateCheckResult? {
        val cacheTime = prefs.getLong(PREFS_KEY_CACHE_TIMESTAMP, 0L)
        if (System.currentTimeMillis() - cacheTime > CACHE_TTL_MS) return null

        val statusName = prefs.getString(PREFS_KEY_CACHED_STATUS, null) ?: return null
        val status = try {
            AppUpdateStatus.valueOf(statusName)
        } catch (e: Exception) {
            return null
        }

        val versionInfo = if (status != AppUpdateStatus.UP_TO_DATE) {
            AppVersionInfo(
                version = prefs.getString(PREFS_KEY_CACHED_VERSION, "") ?: "",
                platform = "android",
                forceUpdate = prefs.getBoolean(PREFS_KEY_CACHED_FORCE, false),
                optionalUpdate = prefs.getBoolean(PREFS_KEY_CACHED_OPTIONAL, false),
                releaseNotes = prefs.getString(PREFS_KEY_CACHED_RELEASE_NOTES, null),
                storeUrl = prefs.getString(PREFS_KEY_CACHED_STORE_URL, null)
            )
        } else null

        return AppUpdateCheckResult(status = status, versionInfo = versionInfo)
    }

    private fun cacheResult(result: AppUpdateCheckResult) {
        val editor = prefs.edit()
            .putLong(PREFS_KEY_CACHE_TIMESTAMP, System.currentTimeMillis())
            .putString(PREFS_KEY_CACHED_STATUS, result.status.name)

        result.versionInfo?.let { info ->
            editor
                .putString(PREFS_KEY_CACHED_VERSION, info.version)
                .putBoolean(PREFS_KEY_CACHED_FORCE, info.forceUpdate)
                .putBoolean(PREFS_KEY_CACHED_OPTIONAL, info.optionalUpdate)
                .putString(PREFS_KEY_CACHED_RELEASE_NOTES, info.releaseNotes)
                .putString(PREFS_KEY_CACHED_STORE_URL, info.storeUrl)
        }

        editor.apply()
    }
}
