package com.swastricare.health.data.services

import android.os.Bundle
import android.util.Log
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.analytics.ktx.analytics
import com.google.firebase.ktx.Firebase

/**
 * Firebase Analytics wrapper service.
 * Matches iOS AnalyticsService pattern.
 * Gracefully handles cases where Firebase is not configured (missing google-services.json).
 */
class AnalyticsService {

    private val analytics: FirebaseAnalytics? = try {
        Firebase.analytics
    } catch (e: Exception) {
        Log.w(TAG, "Firebase Analytics not available: ${e.message}")
        null
    }

    // ─────────────────────────────────────
    // MARK: - Screen Tracking
    // ─────────────────────────────────────

    fun logScreenView(screenName: String) {
        val bundle = Bundle().apply {
            putString(FirebaseAnalytics.Param.SCREEN_NAME, screenName)
            putString(FirebaseAnalytics.Param.SCREEN_CLASS, screenName)
        }
        analytics?.logEvent(FirebaseAnalytics.Event.SCREEN_VIEW, bundle)
    }

    // ─────────────────────────────────────
    // MARK: - Generic Event Logging
    // ─────────────────────────────────────

    fun logEvent(eventName: String, params: Map<String, Any> = emptyMap()) {
        val bundle = Bundle().apply {
            params.forEach { (key, value) ->
                when (value) {
                    is String -> putString(key, value)
                    is Int -> putInt(key, value)
                    is Long -> putLong(key, value)
                    is Double -> putDouble(key, value)
                    is Float -> putFloat(key, value)
                    is Boolean -> putBoolean(key, value)
                    else -> putString(key, value.toString())
                }
            }
        }
        analytics?.logEvent(eventName, bundle)
    }

    // ─────────────────────────────────────
    // MARK: - Workout Events
    // ─────────────────────────────────────

    fun logWorkoutStart(activityType: String) {
        logEvent("workout_start", mapOf("activity_type" to activityType))
    }

    fun logWorkoutComplete(activityType: String, duration: Long, distance: Double) {
        logEvent("workout_complete", mapOf(
            "activity_type" to activityType,
            "duration_seconds" to duration,
            "distance_km" to distance
        ))
    }

    // ─────────────────────────────────────
    // MARK: - Hydration Events
    // ─────────────────────────────────────

    fun logHydrationLogged(amount: Int, drinkType: String) {
        logEvent("hydration_logged", mapOf(
            "amount_ml" to amount,
            "drink_type" to drinkType
        ))
    }

    // ─────────────────────────────────────
    // MARK: - Medication Events
    // ─────────────────────────────────────

    fun logMedicationTaken(medicationName: String) {
        logEvent("medication_taken", mapOf("medication_name" to medicationName))
    }

    fun logMedicationSkipped(medicationName: String, reason: String?) {
        logEvent("medication_skipped", mapOf(
            "medication_name" to medicationName,
            "reason" to (reason ?: "none")
        ))
    }

    // ─────────────────────────────────────
    // MARK: - AI Events
    // ─────────────────────────────────────

    fun logAIMessageSent(mode: String) {
        logEvent("ai_message_sent", mapOf("mode" to mode))
    }

    // ─────────────────────────────────────
    // MARK: - Vault Events
    // ─────────────────────────────────────

    fun logVaultUpload(category: String) {
        logEvent("vault_upload", mapOf("category" to category))
    }

    // ─────────────────────────────────────
    // MARK: - User Identity
    // ─────────────────────────────────────

    fun setUserId(userId: String) {
        analytics?.setUserId(userId)
    }

    fun setUserProperties(properties: Map<String, String>) {
        properties.forEach { (key, value) ->
            analytics?.setUserProperty(key, value)
        }
    }

    companion object {
        private const val TAG = "AnalyticsService"
    }
}
