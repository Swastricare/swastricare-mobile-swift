package com.swastricare.health.data.services

import android.content.Context
import android.content.SharedPreferences
import android.provider.Settings
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.abs

/**
 * Model for the app_versions Supabase table row.
 * Matches the actual table schema used by iOS.
 */
@Serializable
data class AppVersionRecord(
    val id: String = "",
    val platform: String = "",
    val channel: String = "production",
    @SerialName("min_supported_version")
    val minSupportedVersion: String? = null,
    @SerialName("min_supported_build")
    val minSupportedBuild: Int? = null,
    @SerialName("latest_version")
    val latestVersion: String? = null,
    @SerialName("latest_build")
    val latestBuild: Int? = null,
    @SerialName("force_update")
    val forceUpdate: Boolean = false,
    @SerialName("rollout_percentage")
    val rolloutPercentage: Int = 100,
    @SerialName("update_title")
    val updateTitle: String? = null,
    @SerialName("update_message")
    val updateMessage: String? = null,
    @SerialName("update_url")
    val updateUrl: String? = null,
    @SerialName("is_active")
    val isActive: Boolean = true,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("updated_at")
    val updatedAt: String? = null
)

/**
 * App update status enum — matches iOS AppUpdateStatus.
 */
enum class AppUpdateStatus {
    UP_TO_DATE,
    OPTIONAL_UPDATE,
    FORCE_UPDATE
}

/**
 * Result containing the status, record, and computed version info.
 */
data class AppUpdateCheckResult(
    val status: AppUpdateStatus,
    val record: AppVersionRecord? = null,
    val currentVersion: String = "",
    val currentBuild: Int = 0
)

/**
 * AppVersionService
 *
 * Checks Supabase app_versions table to determine if the user needs to update.
 * Matches iOS AppVersionService decision tree:
 *   1. Below min_supported_version/build -> FORCE_UPDATE
 *   2. force_update flag + newer version exists -> FORCE_UPDATE
 *   3. Newer version + rollout check passes -> OPTIONAL_UPDATE
 *   4. Otherwise -> UP_TO_DATE
 *
 * Caches results for 1 hour. On error, defaults to UP_TO_DATE.
 */
@Singleton
class AppVersionService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val supabaseClient: SupabaseClient
) {
    companion object {
        private const val TAG = "AppVersionService"
        private const val PREFS_NAME = "swastricare_version"
        private const val PREFS_KEY_CACHED_STATUS = "cached_update_status"
        private const val PREFS_KEY_CACHED_LATEST_VERSION = "cached_latest_version"
        private const val PREFS_KEY_CACHED_UPDATE_TITLE = "cached_update_title"
        private const val PREFS_KEY_CACHED_UPDATE_MESSAGE = "cached_update_message"
        private const val PREFS_KEY_CACHED_UPDATE_URL = "cached_update_url"
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
    suspend fun checkForUpdate(
        currentVersionName: String,
        currentBuildCode: Int
    ): AppUpdateCheckResult {
        val cached = getCachedResult(currentVersionName, currentBuildCode)
        if (cached != null) {
            Log.d(TAG, "Using cached update check result: ${cached.status}")
            return cached
        }

        return try {
            val result = fetchAndCompare(currentVersionName, currentBuildCode)
            cacheResult(result)
            Log.d(TAG, "Fetched update check: ${result.status}")
            result
        } catch (e: Exception) {
            Log.w(TAG, "Failed to check for update: ${e.message}")
            AppUpdateCheckResult(
                status = AppUpdateStatus.UP_TO_DATE,
                currentVersion = currentVersionName,
                currentBuild = currentBuildCode
            )
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

    // ── Core Logic (matches iOS) ──

    private suspend fun fetchAndCompare(
        currentVersionName: String,
        currentBuildCode: Int
    ): AppUpdateCheckResult {
        val channel = if (com.swastricare.health.BuildConfig.DEBUG) "staging" else "production"

        Log.d(TAG, "Checking for updates... version=$currentVersionName build=$currentBuildCode channel=$channel")

        val response = supabaseClient.postgrest["app_versions"]
            .select {
                filter {
                    eq("platform", "android")
                    eq("channel", channel)
                    eq("is_active", true)
                }
                limit(1)
            }

        val records = response.decodeList<AppVersionRecord>()
        if (records.isEmpty()) {
            Log.d(TAG, "No version record found for android/$channel")
            return AppUpdateCheckResult(
                status = AppUpdateStatus.UP_TO_DATE,
                currentVersion = currentVersionName,
                currentBuild = currentBuildCode
            )
        }

        val record = records.first()

        Log.d(TAG, "Server data: min=${record.minSupportedVersion}(${record.minSupportedBuild}) latest=${record.latestVersion}(${record.latestBuild}) force=${record.forceUpdate}")

        val isBelowMinimum = isBelowMinimum(currentVersionName, currentBuildCode, record)
        val hasNewerVersion = hasNewerVersion(currentVersionName, currentBuildCode, record)

        Log.d(TAG, "Computed: isBelowMinimum=$isBelowMinimum hasNewerVersion=$hasNewerVersion")

        val status = when {
            // 1. Below minimum supported version → force update
            isBelowMinimum -> {
                Log.d(TAG, "FORCE UPDATE - below minimum version")
                AppUpdateStatus.FORCE_UPDATE
            }
            // 2. Server force_update flag + newer version exists → force update
            record.forceUpdate && hasNewerVersion -> {
                Log.d(TAG, "FORCE UPDATE - server flag is true and update exists")
                AppUpdateStatus.FORCE_UPDATE
            }
            // 3. Newer version + passes rollout → optional update
            hasNewerVersion && shouldParticipateInRollout(record.rolloutPercentage) -> {
                Log.d(TAG, "Optional update available - ${record.latestVersion}")
                AppUpdateStatus.OPTIONAL_UPDATE
            }
            // 4. Up to date
            else -> {
                Log.d(TAG, "App is up to date")
                AppUpdateStatus.UP_TO_DATE
            }
        }

        return AppUpdateCheckResult(
            status = status,
            record = record,
            currentVersion = currentVersionName,
            currentBuild = currentBuildCode
        )
    }

    private fun isBelowMinimum(
        currentVersion: String,
        currentBuild: Int,
        record: AppVersionRecord
    ): Boolean {
        val minVersion = record.minSupportedVersion
        if (minVersion != null && compareVersions(currentVersion, minVersion) < 0) {
            return true
        }
        val minBuild = record.minSupportedBuild
        if (minBuild != null && currentBuild < minBuild) {
            return true
        }
        return false
    }

    private fun hasNewerVersion(
        currentVersion: String,
        currentBuild: Int,
        record: AppVersionRecord
    ): Boolean {
        val latest = record.latestVersion
        if (latest != null && compareVersions(currentVersion, latest) < 0) {
            return true
        }
        val latestBuild = record.latestBuild
        if (latestBuild != null && currentBuild < latestBuild) {
            return true
        }
        return false
    }

    /**
     * Deterministic rollout gating based on device ID — matches iOS logic.
     */
    private fun shouldParticipateInRollout(percentage: Int): Boolean {
        if (percentage >= 100) return true
        if (percentage <= 0) return false

        val deviceId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
            ?: java.util.UUID.randomUUID().toString()
        val normalizedValue = abs(deviceId.hashCode() % 100)
        return normalizedValue < percentage
    }

    /**
     * Semantic version comparison (e.g. "1.2.3" vs "1.2.4").
     * Returns negative if current < server, 0 if equal, positive if current > server.
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

    // ── Caching ──

    private fun getCachedResult(
        currentVersion: String,
        currentBuild: Int
    ): AppUpdateCheckResult? {
        val cacheTime = prefs.getLong(PREFS_KEY_CACHE_TIMESTAMP, 0L)
        if (System.currentTimeMillis() - cacheTime > CACHE_TTL_MS) return null

        val statusName = prefs.getString(PREFS_KEY_CACHED_STATUS, null) ?: return null
        val status = try {
            AppUpdateStatus.valueOf(statusName)
        } catch (_: Exception) {
            return null
        }

        val record = if (status != AppUpdateStatus.UP_TO_DATE) {
            AppVersionRecord(
                latestVersion = prefs.getString(PREFS_KEY_CACHED_LATEST_VERSION, null),
                updateTitle = prefs.getString(PREFS_KEY_CACHED_UPDATE_TITLE, null),
                updateMessage = prefs.getString(PREFS_KEY_CACHED_UPDATE_MESSAGE, null),
                updateUrl = prefs.getString(PREFS_KEY_CACHED_UPDATE_URL, null)
            )
        } else null

        return AppUpdateCheckResult(
            status = status,
            record = record,
            currentVersion = currentVersion,
            currentBuild = currentBuild
        )
    }

    private fun cacheResult(result: AppUpdateCheckResult) {
        val editor = prefs.edit()
            .putLong(PREFS_KEY_CACHE_TIMESTAMP, System.currentTimeMillis())
            .putString(PREFS_KEY_CACHED_STATUS, result.status.name)

        result.record?.let { record ->
            editor
                .putString(PREFS_KEY_CACHED_LATEST_VERSION, record.latestVersion)
                .putString(PREFS_KEY_CACHED_UPDATE_TITLE, record.updateTitle)
                .putString(PREFS_KEY_CACHED_UPDATE_MESSAGE, record.updateMessage)
                .putString(PREFS_KEY_CACHED_UPDATE_URL, record.updateUrl)
        }

        editor.apply()
    }
}
