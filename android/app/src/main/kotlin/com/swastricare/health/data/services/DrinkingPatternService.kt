package com.swastricare.health.data.services

import android.content.SharedPreferences
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class DrinkingPattern(
    val clusterTimes: List<String>,      // ISO times like "08:30", "12:15", "18:00"
    val gapMinutes: List<Int>,           // minutes between clusters
    val longestGapStartHour: Int,        // hour where user goes longest without drinking
    val totalDataDays: Int,
    val updatedAt: String
)

class DrinkingPatternService(
    private val prefs: SharedPreferences
) {
    companion object {
        private const val PREF_KEY = "drinking_pattern"
        private const val MIN_ENTRIES_FOR_PATTERN = 20
        private const val CLUSTER_THRESHOLD_MINUTES = 60
    }

    private val json = Json { ignoreUnknownKeys = true }

    fun getPattern(): DrinkingPattern? {
        val raw = prefs.getString(PREF_KEY, null) ?: return null
        return try { json.decodeFromString<DrinkingPattern>(raw) } catch (_: Exception) { null }
    }

    /**
     * Analyze drink timestamps to find clusters.
     * @param timestamps list of ISO datetime strings (e.g. "2026-03-01T08:30:00")
     */
    fun analyzePatterns(timestamps: List<String>): DrinkingPattern? {
        if (timestamps.size < MIN_ENTRIES_FOR_PATTERN) return null

        // Extract minutes-since-midnight from each timestamp
        val times = timestamps.mapNotNull { ts ->
            try {
                val timePart = ts.substringAfter("T").take(5)
                val parts = timePart.split(":")
                parts[0].toInt() * 60 + parts[1].toInt()
            } catch (_: Exception) { null }
        }.sorted()

        if (times.isEmpty()) return null

        // Cluster times within CLUSTER_THRESHOLD_MINUTES
        val clusters = mutableListOf<MutableList<Int>>()
        var currentCluster = mutableListOf(times.first())

        for (i in 1 until times.size) {
            if (times[i] - currentCluster.last() <= CLUSTER_THRESHOLD_MINUTES) {
                currentCluster.add(times[i])
            } else {
                clusters.add(currentCluster)
                currentCluster = mutableListOf(times[i])
            }
        }
        clusters.add(currentCluster)

        // Median of each cluster = representative time (only clusters with 3+ entries)
        val clusterMedians = clusters
            .filter { it.size >= 3 }
            .map { cluster ->
                val sorted = cluster.sorted()
                sorted[sorted.size / 2]
            }

        if (clusterMedians.size < 2) return null

        val clusterTimes = clusterMedians.map { mins ->
            "${(mins / 60).toString().padStart(2, '0')}:${(mins % 60).toString().padStart(2, '0')}"
        }

        val gaps = clusterMedians.zipWithNext { a, b -> b - a }
        val longestGapIdx = gaps.indexOf(gaps.maxOrNull())
        val longestGapStartHour = clusterMedians.getOrNull(longestGapIdx)?.div(60) ?: 12

        val totalDays = timestamps.mapNotNull { it.take(10) }.distinct().size

        val pattern = DrinkingPattern(
            clusterTimes = clusterTimes,
            gapMinutes = gaps,
            longestGapStartHour = longestGapStartHour,
            totalDataDays = totalDays,
            updatedAt = java.time.LocalDateTime.now().toString()
        )

        prefs.edit().putString(PREF_KEY, json.encodeToString(pattern)).apply()
        return pattern
    }

    /**
     * Get suggested reminder times based on patterns.
     * Adds reminders in detected gaps where user typically doesn't drink.
     */
    fun getSuggestedReminderTimes(): List<String> {
        val pattern = getPattern() ?: return defaultReminderTimes()

        val reminders = pattern.clusterTimes.toMutableList()
        if (pattern.gapMinutes.isNotEmpty()) {
            val longestGap = pattern.gapMinutes.max()
            if (longestGap > 120) {
                val gapIdx = pattern.gapMinutes.indexOf(longestGap)
                val gapStart = pattern.clusterTimes.getOrNull(gapIdx) ?: return reminders
                val startMinutes = gapStart.split(":").let { it[0].toInt() * 60 + it[1].toInt() }
                val midpoint = (startMinutes + longestGap / 2) % 1440  // 1440 = 24 * 60
                val midTime = "${(midpoint / 60).toString().padStart(2, '0')}:${(midpoint % 60).toString().padStart(2, '0')}"
                reminders.add(gapIdx + 1, midTime)
            }
        }
        return reminders
    }

    private fun defaultReminderTimes() = listOf("08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00")
}
