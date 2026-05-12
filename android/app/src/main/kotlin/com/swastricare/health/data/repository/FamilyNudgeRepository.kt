package com.swastricare.health.data.repository

import android.util.Log
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.call.body
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Built-in nudge presets supported by the `send-family-nudge` edge function.
 *
 * The `key` is the `preset_key` sent in the request; `category` is the matching
 * `category` field. Keys and categories happen to match today but are tracked
 * separately so they can diverge (e.g. `MEDICATION_MISSED` category for a
 * `MEDICATION` preset triggered by a missed-dose detector).
 */
enum class NudgePreset(val key: String, val category: String) {
    MEDICATION("MEDICATION", "MEDICATION"),
    HYDRATION("HYDRATION", "HYDRATION"),
    VITALS("VITALS", "VITALS"),
    APPOINTMENT("APPOINTMENT", "APPOINTMENT"),
    CHECKIN("CHECKIN", "CHECKIN"),
}

@Serializable
private data class NudgeRequest(
    @SerialName("recipient_user_id") val recipientUserId: String,
    @SerialName("target_health_profile_id") val targetHealthProfileId: String? = null,
    @SerialName("preset_key") val presetKey: String? = null,
    @SerialName("custom_message") val customMessage: String? = null,
    @SerialName("category") val category: String,
    @SerialName("is_critical") val isCritical: Boolean = false,
)

@Serializable
data class NudgeResponse(
    val delivered: Boolean = false,
    @SerialName("nudge_id") val nudgeId: String? = null,
    val reason: String? = null,
)

/**
 * Sends family nudges via the `send-family-nudge` Supabase edge function.
 *
 * The function handles: permission checks (`has_family_access`), recipient-side opt-outs
 * (quiet hours, per-category preferences), nudge row insert, and FCM fan-out to all the
 * recipient's device tokens. We only need to POST the request and surface the result.
 */
@Singleton
class FamilyNudgeRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
) {
    companion object {
        private const val TAG = "FamilyNudgeRepo"
        private const val FUNCTION_NAME = "send-family-nudge"
    }

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    /**
     * Send a preset nudge (Medication / Hydration / Vitals / Appointment / Checkin).
     * The recipient sees a localized title+body chosen by the edge function.
     */
    suspend fun sendPreset(
        recipientUserId: String,
        targetProfileId: String,
        preset: NudgePreset,
        isCritical: Boolean = false,
    ): Result<NudgeResponse> = runCatching {
        invoke(
            NudgeRequest(
                recipientUserId = recipientUserId,
                targetHealthProfileId = targetProfileId,
                presetKey = preset.key,
                customMessage = null,
                category = preset.category,
                isCritical = isCritical,
            )
        )
    }.onFailure { e ->
        Log.e(TAG, "sendPreset failed", e)
    }

    /**
     * Send a free-form nudge written by the caregiver. Defaults to CHECKIN category
     * for routing/preferences; pass another category to override.
     */
    suspend fun sendCustom(
        recipientUserId: String,
        targetProfileId: String,
        message: String,
        category: String = "CHECKIN",
        isCritical: Boolean = false,
    ): Result<NudgeResponse> = runCatching {
        invoke(
            NudgeRequest(
                recipientUserId = recipientUserId,
                targetHealthProfileId = targetProfileId,
                presetKey = null,
                customMessage = message,
                category = category,
                isCritical = isCritical,
            )
        )
    }.onFailure { e ->
        Log.e(TAG, "sendCustom failed", e)
    }

    private suspend fun invoke(req: NudgeRequest): NudgeResponse {
        val response = supabaseClient.functions.invoke(
            function = FUNCTION_NAME,
            body = req,
        )
        val raw = response.body<String>()
        if (raw.isBlank()) {
            return NudgeResponse(delivered = false, reason = "empty_response")
        }
        return try {
            json.decodeFromString(NudgeResponse.serializer(), raw)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse nudge response: $raw", e)
            NudgeResponse(delivered = false, reason = "parse_error")
        }
    }
}
