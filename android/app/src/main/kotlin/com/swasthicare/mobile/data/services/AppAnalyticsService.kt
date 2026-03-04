package com.swasthicare.mobile.data.services

import android.content.Context
import android.content.SharedPreferences
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.*
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.util.*
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.CopyOnWriteArrayList

/**
 * App event to be tracked and flushed to Supabase.
 */
@Serializable
data class AppEvent(
    val id: String = UUID.randomUUID().toString(),
    @SerialName("event_name")
    val eventName: String,
    val properties: Map<String, String> = emptyMap(),
    val timestamp: String = "",
    val sessionId: String = "",
    @SerialName("user_id")
    val userId: String? = null
)

/**
 * Supabase row shape for app_events table.
 */
@Serializable
data class AppEventRow(
    val event_name: String,
    val properties: JsonObject,
    val timestamp: String,
    val session_id: String,
    val platform: String = "android",
    val user_id: String? = null
)

/**
 * AppAnalyticsService
 *
 * Custom analytics pipeline that queues events locally and batch-flushes to Supabase.
 * Matches the iOS AppAnalyticsService behavior.
 *
 * Features:
 * - In-memory queue (max 500 events)
 * - Batch flush every 30 seconds or at 50 events
 * - Flush on app background (via ProcessLifecycleOwner)
 * - Offline support with SharedPreferences persistence
 * - Retry with exponential backoff (3 attempts)
 * - Session tracking
 * - User ID tagging
 */
class AppAnalyticsService(
    private val context: Context,
    private val supabaseClient: SupabaseClient
) : DefaultLifecycleObserver {

    companion object {
        private const val TAG = "AppAnalyticsService"
        private const val MAX_QUEUE_SIZE = 500
        private const val FLUSH_THRESHOLD = 50
        private const val FLUSH_INTERVAL_MS = 30_000L // 30 seconds
        private const val MAX_RETRY_ATTEMPTS = 3
        private const val RETRY_BASE_MS = 1000L
        private const val PREFS_KEY_QUEUED_EVENTS = "persisted_events"
        private const val PREFS_NAME = "swasthicare_analytics"
    }

    private var currentUserId: String? = null

    private val eventQueue = ConcurrentLinkedQueue<AppEvent>()
    private var sessionId: String = UUID.randomUUID().toString()
    private var sessionStartTime: Long = System.currentTimeMillis()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var flushJob: Job? = null

    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val isoFormatter = java.time.format.DateTimeFormatter
        .ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
        .withZone(java.time.ZoneOffset.UTC)

    // ─────────────────────────────────────
    // MARK: - Initialization (Agent 3 start/stop pattern)
    // ─────────────────────────────────────

    /**
     * Start the analytics service: restore persisted events, begin periodic flush,
     * and register the ProcessLifecycleOwner observer for automatic app_open/app_background tracking.
     * Called from SwasthiCareApplication.onCreate().
     */
    fun start() {
        loadPersistedEvents()
        startPeriodicFlush()
        try {
            ProcessLifecycleOwner.get().lifecycle.addObserver(this)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to register lifecycle observer: ${e.message}")
        }
        track("app_open")
        Log.d(TAG, "Analytics started. Session: $sessionId")
    }

    /**
     * Stop the analytics service: persist unsent events and cancel jobs.
     * Called from SwasthiCareApplication.onTerminate().
     */
    fun stop() {
        persistQueue()
        flushJob?.cancel()
        scope.cancel()
    }

    /**
     * Initialize the service with lifecycle observer support (Agent 5 pattern):
     * load persisted events, start periodic flush, register lifecycle observer.
     */
    fun initialize() {
        loadPersistedEvents()
        startPeriodicFlush()
        try {
            ProcessLifecycleOwner.get().lifecycle.addObserver(this)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to register lifecycle observer: ${e.message}")
        }
        track("app_open")
        Log.d(TAG, "Analytics initialized. Session: $sessionId")
    }

    // Lifecycle callbacks
    override fun onStart(owner: LifecycleOwner) {
        // App comes to foreground
        track("app_open")
    }

    override fun onStop(owner: LifecycleOwner) {
        // App goes to background - flush events
        track("app_background")
        scope.launch { flush() }
    }

    // ─────────────────────────────────────
    // MARK: - Event Tracking
    // ─────────────────────────────────────

    /**
     * Track a named event with optional properties.
     */
    fun track(eventName: String, properties: Map<String, String> = emptyMap()) {
        val event = AppEvent(
            id = UUID.randomUUID().toString(),
            eventName = eventName,
            properties = properties,
            timestamp = isoFormatter.format(java.time.Instant.now()),
            sessionId = sessionId,
            userId = currentUserId
        )

        // Overflow: drop oldest if exceeding max size
        while (eventQueue.size >= MAX_QUEUE_SIZE) {
            eventQueue.poll()
        }

        eventQueue.add(event)

        // Trigger flush if threshold reached
        if (eventQueue.size >= FLUSH_THRESHOLD) {
            scope.launch { flush() }
        }
    }

    fun setUserId(userId: String) {
        currentUserId = userId
    }

    // ─────────────────────────────────────
    // MARK: - Convenience Tracking Methods
    // ─────────────────────────────────────

    fun trackScreenView(screenName: String) {
        track("screen_view", mapOf("screen_name" to screenName))
    }

    fun trackTabSelected(tabName: String) {
        track("tab_selected", mapOf("tab_name" to tabName))
    }

    fun trackHydrationLogged(amount: Int, drinkType: String) {
        track("hydration_logged", mapOf("amount" to amount.toString(), "drink_type" to drinkType))
    }

    fun trackHydrationGoalMet() {
        track("hydration_goal_met")
    }

    fun trackMedicationTaken(medicationName: String) {
        track("medication_taken", mapOf("medication_name" to medicationName))
    }

    fun trackMedicationSkipped(medicationName: String, reason: String) {
        track("medication_skipped", mapOf("medication_name" to medicationName, "reason" to reason))
    }

    fun trackHeartbeatMeasurement(bpm: Int, confidence: Float) {
        track("heartbeat_measurement", mapOf("bpm" to bpm.toString(), "confidence" to confidence.toString()))
    }

    fun trackAIMessageSent(mode: String) {
        track("ai_message_sent", mapOf("mode" to mode))
    }

    fun trackAIAnalysisRequest() {
        track("ai_analysis_request")
    }

    fun trackConversationStarted() {
        track("conversation_started")
    }

    fun trackWorkoutStarted(activityType: String) {
        track("workout_started", mapOf("activity_type" to activityType))
    }

    fun trackWorkoutCompleted(activityType: String, durationSeconds: Long, distanceMeters: Double) {
        track(
            "workout_completed",
            mapOf(
                "activity_type" to activityType,
                "duration" to durationSeconds.toString(),
                "distance" to distanceMeters.toString()
            )
        )
    }

    fun trackVaultUpload(category: String) {
        track("vault_upload", mapOf("category" to category))
    }

    fun trackError(errorType: String, message: String) {
        track("error", mapOf("error_type" to errorType, "message" to message))
    }

    // ─────────────────────────────────────
    // MARK: - Flush Logic
    // ─────────────────────────────────────

    private fun startPeriodicFlush() {
        flushJob?.cancel()
        flushJob = scope.launch {
            while (isActive) {
                delay(FLUSH_INTERVAL_MS)
                flush()
            }
        }
    }

    /**
     * Flush all queued events to Supabase.
     */
    private suspend fun flush() {
        if (eventQueue.isEmpty()) return
        if (!isNetworkAvailable()) {
            persistQueue()
            return
        }

        // Drain events into a batch
        val batch = mutableListOf<AppEvent>()
        while (eventQueue.isNotEmpty() && batch.size < MAX_QUEUE_SIZE) {
            eventQueue.poll()?.let { batch.add(it) }
        }

        if (batch.isEmpty()) return

        // Tag events with userId if not already set
        val taggedBatch = batch.map { event ->
            if (event.userId == null && currentUserId != null) {
                event.copy(userId = currentUserId)
            } else event
        }

        var success = false
        var lastException: Exception? = null

        for (attempt in 1..MAX_RETRY_ATTEMPTS) {
            try {
                val rows = taggedBatch.map { event ->
                    AppEventRow(
                        event_name = event.eventName,
                        properties = JsonObject(
                            event.properties.mapValues { JsonPrimitive(it.value) }
                        ),
                        timestamp = event.timestamp,
                        session_id = event.sessionId,
                        platform = "android",
                        user_id = event.userId
                    )
                }

                supabaseClient.postgrest["app_events"].insert(rows)
                success = true
                Log.d(TAG, "Flushed ${taggedBatch.size} events (attempt $attempt)")
                break
            } catch (e: Exception) {
                lastException = e
                Log.w(TAG, "Flush attempt $attempt failed: ${e.message}")
                if (attempt < MAX_RETRY_ATTEMPTS) {
                    // Exponential backoff: 1s, 2s, 4s
                    val delayMs = RETRY_BASE_MS * (1L shl (attempt - 1))
                    delay(delayMs)
                }
            }
        }

        if (!success) {
            // Re-add events to queue for next flush
            Log.w(TAG, "All flush attempts failed. Persisting ${taggedBatch.size} events.")
            taggedBatch.forEach { eventQueue.add(it) }
            persistQueue()
        }
    }

    // ─────────────────────────────────────
    // MARK: - Persistence
    // ─────────────────────────────────────

    private fun persistQueue() {
        try {
            val events = eventQueue.toList()
            val serialized = json.encodeToString(events)
            prefs.edit().putString(PREFS_KEY_QUEUED_EVENTS, serialized).apply()
            Log.d(TAG, "Persisted ${events.size} events to disk")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to persist event queue: ${e.message}")
        }
    }

    private fun loadPersistedEvents() {
        try {
            val serialized = prefs.getString(PREFS_KEY_QUEUED_EVENTS, null) ?: return
            val events = json.decodeFromString<List<AppEvent>>(serialized)
            events.forEach { eventQueue.add(it) }
            // Clear persisted data
            prefs.edit().remove(PREFS_KEY_QUEUED_EVENTS).apply()
            Log.d(TAG, "Loaded ${events.size} persisted events")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load persisted events: ${e.message}")
            // Clear corrupted data
            prefs.edit().remove(PREFS_KEY_QUEUED_EVENTS).apply()
        }
    }

    // ─────────────────────────────────────
    // MARK: - Network Check
    // ─────────────────────────────────────

    private fun isNetworkAvailable(): Boolean {
        return try {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = connectivityManager.activeNetwork ?: return false
            val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Shutdown the service, flush remaining events.
     */
    fun shutdown() {
        scope.launch {
            flush()
            flushJob?.cancel()
        }
    }
}
