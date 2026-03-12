package com.swastricare.health.data.services

import com.swastricare.health.data.models.RunActivity
import com.swastricare.health.data.models.ActivityType
import java.time.LocalDateTime

class FitnessAnalyticsService(
    private val healthConnectService: HealthConnectService
) {
    data class FitnessData(
        val vo2Max: Double? = null,
        val vo2MaxSource: String = "",
        val weeklyTrainingLoad: Int = 0,
        val todayTrainingLoad: Int = 0,
        val loadTrend: LoadTrend = LoadTrend.MAINTAINING
    )

    enum class LoadTrend { INCREASING, MAINTAINING, DECREASING }

    suspend fun getFitnessData(activities: List<RunActivity>): FitnessData {
        val vo2MaxFromHC = healthConnectService.getVo2Max()

        val vo2Max: Double?
        val vo2Source: String
        if (vo2MaxFromHC != null) {
            vo2Max = vo2MaxFromHC
            vo2Source = "Health Connect"
        } else {
            vo2Max = estimateVo2MaxCooper(activities)
            vo2Source = if (vo2Max != null) "Estimated" else ""
        }

        val now = LocalDateTime.now()
        val weekAgo = now.minusDays(7)
        val twoWeeksAgo = now.minusDays(14)

        val thisWeekActivities = activities.filter {
            it.startTime?.isAfter(weekAgo) == true
        }
        val lastWeekActivities = activities.filter {
            it.startTime?.isAfter(twoWeeksAgo) == true &&
            it.startTime?.isBefore(weekAgo) == true
        }

        val weeklyLoad = thisWeekActivities.sumOf { calculateTrainingLoad(it, activities) }
        val lastWeekLoad = lastWeekActivities.sumOf { calculateTrainingLoad(it, activities) }

        val todayActivities = activities.filter {
            it.startTime?.toLocalDate() == now.toLocalDate()
        }
        val todayLoad = todayActivities.sumOf { calculateTrainingLoad(it, activities) }

        val trend = when {
            weeklyLoad > lastWeekLoad * 1.15 -> LoadTrend.INCREASING
            weeklyLoad < lastWeekLoad * 0.85 -> LoadTrend.DECREASING
            else -> LoadTrend.MAINTAINING
        }

        return FitnessData(
            vo2Max = vo2Max,
            vo2MaxSource = vo2Source,
            weeklyTrainingLoad = weeklyLoad,
            todayTrainingLoad = todayLoad,
            loadTrend = trend
        )
    }

    private fun estimateVo2MaxCooper(activities: List<RunActivity>): Double? {
        val qualifying = activities.filter {
            it.activityType == ActivityType.RUNNING &&
            it.durationSeconds >= 720 &&
            it.distanceMeters > 0
        }
        if (qualifying.isEmpty()) return null

        val best = qualifying.maxByOrNull { it.distanceMeters / it.durationSeconds }
            ?: return null

        val metersPerSecond = best.distanceMeters / best.durationSeconds
        val twelveMinsDistance = metersPerSecond * 720

        val vo2 = (twelveMinsDistance - 504.9) / 44.73
        return if (vo2 in 15.0..85.0) vo2 else null
    }

    private fun calculateTrainingLoad(activity: RunActivity, allActivities: List<RunActivity>): Int {
        val durationMinutes = activity.durationSeconds / 60.0

        val bestPace = allActivities
            .filter { it.activityType == activity.activityType && it.avgPaceSecondsPerKm > 0 }
            .minOfOrNull { it.avgPaceSecondsPerKm }
            ?: activity.avgPaceSecondsPerKm

        val intensity = if (activity.avgPaceSecondsPerKm > 0 && bestPace > 0) {
            (bestPace.toDouble() / activity.avgPaceSecondsPerKm).coerceIn(0.5, 2.0)
        } else 1.0

        return (durationMinutes * intensity).toInt()
    }
}
