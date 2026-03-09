package com.swasthicare.mobile.data.models

import android.content.SharedPreferences
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class WorkoutTemplate(
    val id: String = java.util.UUID.randomUUID().toString(),
    val name: String,
    val activityType: String,
    val targetDistanceMeters: Double? = null,
    val targetDurationSeconds: Long? = null,
    val targetPaceSecondsPerKm: Long? = null,
    val isBuiltIn: Boolean = false
) {
    val targetDistanceKm: Double? get() = targetDistanceMeters?.let { it / 1000.0 }

    val formattedTarget: String get() = buildString {
        targetDistanceKm?.let { append("%.1f km".format(it)) }
        targetDurationSeconds?.let {
            if (isNotEmpty()) append(" / ")
            val mins = it / 60
            append("${mins} min")
        }
        targetPaceSecondsPerKm?.let {
            if (isNotEmpty()) append(" / ")
            val m = it / 60
            val s = it % 60
            append("%d:%02d /km".format(m, s))
        }
    }

    companion object {
        private const val PREFS_KEY = "workout_templates"
        private val json = Json { encodeDefaults = true; ignoreUnknownKeys = true }

        val builtInTemplates = listOf(
            WorkoutTemplate(
                id = "builtin_easy_5k",
                name = "Easy Run 5K",
                activityType = "RUN",
                targetDistanceMeters = 5000.0,
                isBuiltIn = true
            ),
            WorkoutTemplate(
                id = "builtin_long_10k",
                name = "Long Run 10K",
                activityType = "RUN",
                targetDistanceMeters = 10000.0,
                isBuiltIn = true
            ),
            WorkoutTemplate(
                id = "builtin_walk_30",
                name = "Walk 30 min",
                activityType = "WALK",
                targetDurationSeconds = 1800,
                isBuiltIn = true
            ),
            WorkoutTemplate(
                id = "builtin_cycle_20k",
                name = "Cycle 20K",
                activityType = "CYCLE",
                targetDistanceMeters = 20000.0,
                isBuiltIn = true
            )
        )

        fun loadTemplates(prefs: SharedPreferences): List<WorkoutTemplate> {
            val saved = prefs.getString(PREFS_KEY, null)
            val custom = if (saved != null) {
                try {
                    json.decodeFromString<List<WorkoutTemplate>>(saved)
                } catch (_: Exception) { emptyList() }
            } else emptyList()
            return builtInTemplates + custom
        }

        fun saveCustomTemplate(prefs: SharedPreferences, template: WorkoutTemplate) {
            val existing = loadTemplates(prefs).filter { !it.isBuiltIn }
            val updated = existing + template
            prefs.edit().putString(PREFS_KEY, json.encodeToString(updated)).apply()
        }

        fun deleteCustomTemplate(prefs: SharedPreferences, templateId: String) {
            val existing = loadTemplates(prefs).filter { !it.isBuiltIn && it.id != templateId }
            prefs.edit().putString(PREFS_KEY, json.encodeToString(existing)).apply()
        }
    }
}
