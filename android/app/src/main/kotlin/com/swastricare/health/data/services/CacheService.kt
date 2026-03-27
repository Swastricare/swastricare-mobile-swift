package com.swastricare.health.data.services

import android.content.SharedPreferences
import android.util.Log
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class CacheService(
    @PublishedApi internal val sharedPreferences: SharedPreferences
) {
    companion object {
        @PublishedApi internal const val TAG = "CacheService"
        @PublishedApi internal const val EXPIRY_SUFFIX = "_expiry"
    }

    @PublishedApi internal val json = Json { ignoreUnknownKeys = true }
    private var currentUserId: String? = null

    fun setCurrentUser(userId: String) {
        currentUserId = userId
    }

    inline fun <reified T> save(key: String, data: T, ttlMs: Long = 86_400_000L) {
        try {
            val prefixed = prefixedKey(key)
            val encoded = json.encodeToString(data)
            sharedPreferences.edit()
                .putString(prefixed, encoded)
                .putLong(prefixed + EXPIRY_SUFFIX, System.currentTimeMillis() + ttlMs)
                .apply()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to cache $key", e)
        }
    }

    inline fun <reified T> load(key: String): T? {
        return try {
            val prefixed = prefixedKey(key)
            val raw = sharedPreferences.getString(prefixed, null) ?: return null
            json.decodeFromString<T>(raw)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load cache $key", e)
            null
        }
    }

    fun isExpired(key: String): Boolean {
        val prefixed = prefixedKey(key)
        val expiry = sharedPreferences.getLong(prefixed + EXPIRY_SUFFIX, 0L)
        return System.currentTimeMillis() > expiry
    }

    fun remove(key: String) {
        val prefixed = prefixedKey(key)
        sharedPreferences.edit()
            .remove(prefixed)
            .remove(prefixed + EXPIRY_SUFFIX)
            .apply()
    }

    fun clearAll(userId: String) {
        val prefix = "${userId}_"
        val editor = sharedPreferences.edit()
        sharedPreferences.all.keys.filter { it.startsWith(prefix) }.forEach { editor.remove(it) }
        editor.apply()
    }

    @PublishedApi
    internal fun prefixedKey(key: String): String {
        val uid = currentUserId ?: return key
        return "${uid}_$key"
    }
}
