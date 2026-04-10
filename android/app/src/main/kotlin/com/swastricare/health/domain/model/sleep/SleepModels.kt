package com.swastricare.health.domain.model.sleep

import java.time.LocalDate
import java.time.LocalTime

/**
 * Type of sleep stage recorded by Health Connect.
 */
enum class SleepStageType(
    val displayName: String,
    val colorHex: Long
) {
    DEEP("Deep", 0xFF1E3A5F),
    LIGHT("Light", 0xFF5B8FB9),
    REM("REM", 0xFF7C3AED),
    AWAKE("Awake", 0xFFEF4444),
    UNKNOWN("Unknown", 0xFF6B7280);
}

/**
 * A single sleep stage within a session.
 */
data class SleepStage(
    val type: SleepStageType,
    val startTimeEpochMillis: Long,
    val endTimeEpochMillis: Long,
    val durationMinutes: Int
)

/**
 * A complete sleep session (one night of sleep).
 */
data class SleepSession(
    val date: LocalDate,
    val startTimeEpochMillis: Long,
    val endTimeEpochMillis: Long,
    val totalMinutes: Int,
    val deepMinutes: Int = 0,
    val lightMinutes: Int = 0,
    val remMinutes: Int = 0,
    val awakeMinutes: Int = 0,
    val stages: List<SleepStage> = emptyList()
) {
    val hasStageData: Boolean
        get() = stages.isNotEmpty()

    val bedtime: LocalTime?
        get() = if (startTimeEpochMillis > 0) {
            java.time.Instant.ofEpochMilli(startTimeEpochMillis)
                .atZone(java.time.ZoneId.systemDefault())
                .toLocalTime()
        } else null

    val wakeTime: LocalTime?
        get() = if (endTimeEpochMillis > 0) {
            java.time.Instant.ofEpochMilli(endTimeEpochMillis)
                .atZone(java.time.ZoneId.systemDefault())
                .toLocalTime()
        } else null

    /**
     * Sleep quality score (0-100) based on NSF guidelines:
     * - Ideal: 20-25% deep, 20-25% REM, <10% awake, 7-9h total
     */
    val qualityScore: Int
        get() {
            if (totalMinutes <= 0) return 0
            var score = 0

            // Duration score (40 points max) — ideal is 420-540 min (7-9h)
            score += when {
                totalMinutes in 420..540 -> 40
                totalMinutes in 360..419 || totalMinutes in 541..600 -> 30
                totalMinutes in 300..359 || totalMinutes in 601..660 -> 20
                totalMinutes in 240..299 -> 10
                else -> 5
            }

            if (!hasStageData) {
                // Without stage data, scale duration score to full 100
                return (score * 100) / 40
            }

            val totalStaged = deepMinutes + lightMinutes + remMinutes + awakeMinutes
            if (totalStaged <= 0) return (score * 100) / 40

            val deepPct = deepMinutes.toFloat() / totalStaged
            val remPct = remMinutes.toFloat() / totalStaged
            val awakePct = awakeMinutes.toFloat() / totalStaged

            // Deep sleep score (20 points) — ideal 20-25%
            score += when {
                deepPct in 0.18f..0.28f -> 20
                deepPct in 0.13f..0.17f || deepPct in 0.29f..0.35f -> 15
                deepPct in 0.08f..0.12f -> 10
                deepPct > 0f -> 5
                else -> 0
            }

            // REM score (20 points) — ideal 20-25%
            score += when {
                remPct in 0.18f..0.28f -> 20
                remPct in 0.13f..0.17f || remPct in 0.29f..0.35f -> 15
                remPct in 0.08f..0.12f -> 10
                remPct > 0f -> 5
                else -> 0
            }

            // Awake score (20 points) — ideal <10%
            score += when {
                awakePct <= 0.05f -> 20
                awakePct <= 0.10f -> 15
                awakePct <= 0.15f -> 10
                awakePct <= 0.25f -> 5
                else -> 0
            }

            return score.coerceIn(0, 100)
        }

    val qualityLabel: String
        get() = when {
            qualityScore >= 80 -> "Excellent"
            qualityScore >= 60 -> "Good"
            qualityScore >= 40 -> "Fair"
            else -> "Poor"
        }

    val totalFormatted: String
        get() {
            if (totalMinutes <= 0) return "--"
            val hours = totalMinutes / 60
            val mins = totalMinutes % 60
            return "${hours}h ${mins}m"
        }
}

/**
 * Aggregated sleep statistics over a date range.
 */
data class SleepStats(
    val averageSleepMinutes: Int = 0,
    val bestNightMinutes: Int = 0,
    val consistencyScore: Int = 0,
    val avgBedtime: LocalTime? = null,
    val avgWakeTime: LocalTime? = null
) {
    val averageFormatted: String
        get() {
            if (averageSleepMinutes <= 0) return "--"
            val hours = averageSleepMinutes / 60
            val mins = averageSleepMinutes % 60
            return "${hours}h ${mins}m"
        }

    val bestNightFormatted: String
        get() {
            if (bestNightMinutes <= 0) return "--"
            val hours = bestNightMinutes / 60
            val mins = bestNightMinutes % 60
            return "${hours}h ${mins}m"
        }
}
