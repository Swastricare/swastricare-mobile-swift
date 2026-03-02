package com.swasthicare.mobile.data.services

import android.content.Context
import android.content.SharedPreferences
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.*
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Custom Supabase-backed analytics service.
 * Matches iOS AppAnalyticsService pattern:
 * - Queue events in memory (max 500)
 * - Flush to Supabase `app_events` table every 30 seconds or when queue hits 50
 * - Offline queue with SharedPreferences persistence
 * - Retry logic (3 attempts, exponential backoff: 1s/2s/4s)
 */
class AppAnalyticsService(
    private val context: Context,
    private val supabaseClient: SupabaseClient
) {
    private val eventQueue = CopyOnWriteArrayList<AppEvent>()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
    private val isoFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    private var flushJob: Job? = null

    // ─────────────────────────────────────
    // MARK: - Initialization
    // ─────────────────────────────────────

    fun start() {
        // Restore persisted events from previous session
        restorePersistedEvents()
        // Start periodic flush
        startPeriodicFlush()
    }

    fun stop() {
        // Persist unsent events
        persistEvents()
        flushJob?.cancel()
        scope.cancel()
    }

    // ─────────────────────────────────────
    // MARK: - Event Tracking
    // ─────────────────────────────────────

    fun track(eventName: String, properties: Map<String, String> = emptyMap()) {
        val event = AppEvent(
            id = UUID.randomUUID().toString(),
            eventName = eventName,
            properties = properties,
            timestamp = isoFormatter.format(Date()),
            userId = null // Set externally if needed
        )

        if (eventQueue.size >= MAX_QUEUE_SIZE) {
            // Drop oldest events to prevent unbounded growth
            eventQueue.removeAt(0)
        }
        eventQueue.add(event)

        // Flush immediately if we hit the batch threshold
        if (eventQueue.size >= FLUSH_THRESHOLD) {
            scope.launch { flush() }
        }
    }

    fun setUserId(userId: String) {
        // Tag future events with the user ID
        currentUserId = userId
    }

    // ─────────────────────────────────────
    // MARK: - Flush Logic
    // ─────────────────────────────────────

    private fun startPeriodicFlush() {
        flushJob = scope.launch {
            while (isActive) {
                delay(FLUSH_INTERVAL_MS)
                flush()
            }
        }
    }

    private suspend fun flush() {
        if (eventQueue.isEmpty()) return
        if (!isNetworkAvailable()) {
            Log.d(TAG, "No network, deferring flush. Queue size: ${eventQueue.size}")
            return
        }

        // Snapshot and clear the queue
        val batch = eventQueue.toList()
        eventQueue.clear()

        // Tag events with userId
        val taggedBatch = batch.map { event ->
            if (event.userId == null && currentUserId != null) {
                event.copy(userId = currentUserId)
            } else event
        }

        var success = false
        var attempts = 0
        while (attempts < MAX_RETRIES && !success) {
            try {
                supabaseClient.postgrest["app_events"].insert(taggedBatch)
                success = true
                Log.d(TAG, "Flushed ${taggedBatch.size} events to Supabase")
            } catch (e: Exception) {
                attempts++
                Log.w(TAG, "Flush attempt $attempts failed: ${e.message}")
                if (attempts < MAX_RETRIES) {
                    // Exponential backoff: 1s, 2s, 4s
                    delay(RETRY_BASE_MS * (1L shl (attempts - 1)))
                }
            }
        }

        if (!success) {
            // Re-queue failed events
            Log.w(TAG, "Failed to flush ${taggedBatch.size} events after $MAX_RETRIES retries, re-queuing")
            eventQueue.addAll(0, taggedBatch)
            // Persist to survive app kill
            persistEvents()
        }
    }

    // ─────────────────────────────────────
    // MARK: - Persistence
    // ─────────────────────────────────────

    private fun persistEvents() {
        try {
            val eventsJson = json.encodeToString(eventQueue.toList())
            prefs.edit().putString(KEY_PERSISTED_EVENTS, eventsJson).apply()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to persist events: ${e.message}")
        }
    }

    private fun restorePersistedEvents() {
        try {
            val eventsJson = prefs.getString(KEY_PERSISTED_EVENTS, null) ?: return
            val events = json.decodeFromString<List<AppEvent>>(eventsJson)
            eventQueue.addAll(events)
            // Clear persisted events after restoring
            prefs.edit().remove(KEY_PERSISTED_EVENTS).apply()
            Log.d(TAG, "Restored ${events.size} persisted events")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to restore persisted events: ${e.message}")
        }
    }

    // ─────────────────────────────────────
    // MARK: - Network Check
    // ─────────────────────────────────────

    private fun isNetworkAvailable(): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
        val network = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(network) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    companion object {
        private const val TAG = "AppAnalyticsService"
        private const val PREFS_NAME = "swasthicare_analytics"
        private const val KEY_PERSISTED_EVENTS = "persisted_events"
        private const val MAX_QUEUE_SIZE = 500
        private const val FLUSH_THRESHOLD = 50
        private const val FLUSH_INTERVAL_MS = 30_000L // 30 seconds
        private const val MAX_RETRIES = 3
        private const val RETRY_BASE_MS = 1000L

        private var currentUserId: String? = null
    }
}

@Serializable
data class AppEvent(
    val id: String,

    @SerialName("event_name")
    val eventName: String,

    val properties: Map<String, String> = emptyMap(),

    val timestamp: String,

    @SerialName("user_id")
    val userId: String? = null
)
