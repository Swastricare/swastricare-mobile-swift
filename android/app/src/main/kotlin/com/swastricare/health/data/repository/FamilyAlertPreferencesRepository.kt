package com.swastricare.health.data.repository

import android.util.Log
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for the `family_alert_preferences` table.
 *
 * Each row stores a caregiver's per-target alert preferences (which alert types are enabled,
 * quiet hours, missed-medication grace period). Primary key is the composite
 * (caregiver_user_id, target_health_profile_id).
 *
 * RLS restricts all operations to rows where `caregiver_user_id = auth.uid()`, so calls
 * require an authenticated session and the caller can only manage their own preferences.
 */
@Serializable
data class FamilyAlertPreferences(
    @SerialName("caregiver_user_id") val caregiverUserId: String,
    @SerialName("target_health_profile_id") val targetHealthProfileId: String,
    @SerialName("missed_medication_alerts") val missedMedicationAlerts: Boolean = true,
    @SerialName("low_hydration_alerts") val lowHydrationAlerts: Boolean = true,
    @SerialName("missed_vitals_alerts") val missedVitalsAlerts: Boolean = false,
    @SerialName("custom_nudge_alerts") val customNudgeAlerts: Boolean = true,
    /** "HH:mm:ss" 24-hour, nullable when quiet hours are disabled. */
    @SerialName("quiet_hours_start") val quietHoursStart: String? = null,
    @SerialName("quiet_hours_end") val quietHoursEnd: String? = null,
    /** DB CHECK constraint: 5..240. */
    @SerialName("missed_med_grace_minutes") val missedMedGraceMinutes: Int = 30,
)

@Singleton
class FamilyAlertPreferencesRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
) {
    companion object {
        private const val TAG = "FamilyAlertPrefsRepo"
        private const val TABLE = "family_alert_preferences"
        private const val ON_CONFLICT = "caregiver_user_id,target_health_profile_id"
    }

    /**
     * Fetch the caregiver's preferences for a specific target profile, or null if none saved yet.
     * Callers should treat null as "use defaults" — do not pre-create a row on first read.
     */
    suspend fun get(
        caregiverUserId: String,
        targetProfileId: String,
    ): Result<FamilyAlertPreferences?> = runCatching {
        supabaseClient.from(TABLE)
            .select {
                filter {
                    eq("caregiver_user_id", caregiverUserId)
                    eq("target_health_profile_id", targetProfileId)
                }
                limit(1)
            }
            .decodeSingleOrNull<FamilyAlertPreferences>()
    }.onFailure { e ->
        Log.e(TAG, "Failed to load alert preferences", e)
    }

    /**
     * Insert-or-update the preferences row. Safe to call on every save — `updated_at` is
     * bumped by a DB trigger.
     */
    suspend fun upsert(prefs: FamilyAlertPreferences): Result<Unit> = runCatching {
        supabaseClient.from(TABLE).upsert(prefs, onConflict = ON_CONFLICT)
        Unit
    }.onFailure { e ->
        Log.e(TAG, "Failed to upsert alert preferences", e)
    }
}
