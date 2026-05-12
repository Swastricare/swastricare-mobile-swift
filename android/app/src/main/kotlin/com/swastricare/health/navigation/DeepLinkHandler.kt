package com.swastricare.health.navigation

import android.net.Uri

/**
 * Parsed deep link route with optional parameters.
 */
sealed class DeepLinkRoute {
    /** Navigate to Vitals (Home) tab */
    object Home : DeepLinkRoute()

    /** Navigate to Hydration screen */
    object Hydration : DeepLinkRoute()

    /** Navigate to Medications screen */
    object Medications : DeepLinkRoute()

    /** Navigate to Heart Rate screen */
    object HeartRate : DeepLinkRoute()

    /** Navigate to Steps tab */
    object Steps : DeepLinkRoute()

    /** Navigate to Run/Steps tab */
    object Run : DeepLinkRoute()

    /** Navigate to Live Workout with a specific type (e.g. walk, run) */
    data class StartRun(val type: String) : DeepLinkRoute()

    /** Navigate to Diet screen */
    object Diet : DeepLinkRoute()

    /** Navigate to Vault tab */
    object Vault : DeepLinkRoute()

    /** Navigate to AI tab */
    object AI : DeepLinkRoute()

    /** Navigate to Family join flow with an invite code */
    data class FamilyJoin(val code: String) : DeepLinkRoute()

    /** Open a specific FCM nudge by id (swastricareapp://nudge/<id>) */
    data class NudgeDetail(val nudgeId: String) : DeepLinkRoute()

    /** Unknown/unsupported deep link */
    object Unknown : DeepLinkRoute()
}

/**
 * DeepLinkHandler parses incoming URIs with the `swastricare://` or `swastricareapp://` scheme
 * and returns the corresponding [DeepLinkRoute].
 *
 * Matching iOS behavior defined in the iOS `DeepLinkHandler`.
 */
object DeepLinkHandler {

    private val SUPPORTED_SCHEMES = setOf("swastricare", "swastricareapp")
    private val FAMILY_CODE_REGEX = Regex("^[A-Za-z0-9]{6}$")

    /**
     * Parse an incoming [Uri] and return the matching [DeepLinkRoute].
     * Returns `null` if the URI scheme is not supported (e.g. the auth-callback URI).
     */
    fun parse(uri: Uri?): DeepLinkRoute? {
        if (uri == null) return null

        val scheme = uri.scheme?.lowercase() ?: return null
        if (scheme !in SUPPORTED_SCHEMES) return null

        // Skip auth callback URIs
        if (uri.host == "auth-callback") return null

        val host = uri.host?.lowercase() ?: return DeepLinkRoute.Unknown
        val pathSegments = uri.pathSegments

        return when (host) {
            "home" -> DeepLinkRoute.Home
            "hydration" -> DeepLinkRoute.Hydration
            "medications" -> DeepLinkRoute.Medications
            "heartrate" -> DeepLinkRoute.HeartRate
            "steps" -> DeepLinkRoute.Steps
            "run" -> {
                // Check for /run/start?type=walk pattern
                if (pathSegments.firstOrNull() == "start") {
                    val type = uri.getQueryParameter("type") ?: "run"
                    DeepLinkRoute.StartRun(type)
                } else {
                    DeepLinkRoute.Run
                }
            }
            "activeworkout" -> DeepLinkRoute.StartRun("run")
            "startrun" -> {
                val type = pathSegments.firstOrNull() ?: uri.getQueryParameter("type") ?: "run"
                DeepLinkRoute.StartRun(type)
            }
            "diet" -> DeepLinkRoute.Diet
            "vault" -> DeepLinkRoute.Vault
            "ai" -> DeepLinkRoute.AI
            "family" -> {
                // swastricare://family/join?code=ABC123
                if (pathSegments.firstOrNull() == "join") {
                    val code = uri.getQueryParameter("code")
                    if (!code.isNullOrBlank() && FAMILY_CODE_REGEX.matches(code)) {
                        DeepLinkRoute.FamilyJoin(code)
                    } else {
                        DeepLinkRoute.Unknown
                    }
                } else {
                    DeepLinkRoute.Unknown
                }
            }
            "nudge" -> {
                // swastricareapp://nudge/<nudgeId>
                val id = pathSegments.firstOrNull()?.takeIf { it.isNotBlank() }
                if (id != null) DeepLinkRoute.NudgeDetail(id) else DeepLinkRoute.Unknown
            }
            else -> DeepLinkRoute.Unknown
        }
    }

    /**
     * Convert a [DeepLinkRoute] into a navigation route string
     * that can be used with NavController.navigate().
     *
     * The special type `__resume__` is used for the notification deep link so
     * the navigation system routes to `live_workout` without a workout_type arg,
     * which keeps any existing back-stack entry (launchSingleTop) rather than
     * starting a fresh workout.
     */
    fun toNavRoute(route: DeepLinkRoute): String = when (route) {
        is DeepLinkRoute.Home -> "vitals"
        is DeepLinkRoute.Hydration -> "hydration"
        is DeepLinkRoute.Medications -> "medications"
        is DeepLinkRoute.HeartRate -> "heart_rate"
        is DeepLinkRoute.Steps -> "steps"
        is DeepLinkRoute.Run -> "steps"
        is DeepLinkRoute.StartRun ->
            if (route.type == "__resume__") "live_workout"
            else "live_workout?type=${route.type}"
        is DeepLinkRoute.Diet -> "diet"
        is DeepLinkRoute.Vault -> "vault"
        is DeepLinkRoute.AI -> "ai"
        is DeepLinkRoute.FamilyJoin -> "family_join/${route.code}"
        is DeepLinkRoute.NudgeDetail -> "nudge/${route.nudgeId}"
        is DeepLinkRoute.Unknown -> "vitals"
    }
}
