package com.swastricare.health.domain.model.analytics

import androidx.compose.ui.graphics.Color
import java.time.LocalDate

/**
 * Time range for analytics views.
 */
enum class TimeRange(val label: String, val days: Int) {
    DAY("Day", 1),
    WEEK("Week", 7),
    MONTH("Month", 30)
}

/**
 * Health metric type with metadata.
 */
enum class MetricType(
    val label: String,
    val unit: String,
    val color: Color,
    val goal: Float?
) {
    STEPS("Steps", "steps", Color(0xFF2196F3), 10_000f),
    CALORIES("Calories", "kcal", Color(0xFFFF9800), 500f),
    HEART_RATE("Heart Rate", "BPM", Color(0xFFF44336), null),
    SLEEP("Sleep", "hrs", Color(0xFF3F51B5), 8f),
    EXERCISE("Exercise", "min", Color(0xFF4CAF50), 30f),
    DISTANCE("Distance", "km", Color(0xFF00BCD4), 5f),
    HYDRATION("Hydration", "ml", Color(0xFF03A9F4), 2500f),
    MED_ADHERENCE("Medication", "%", Color(0xFFE91E63), 100f)
}

/**
 * Trend direction for a metric.
 */
enum class TrendDirection {
    UP, DOWN, FLAT;

    fun getIcon(): String = when (this) {
        UP -> "↑"
        DOWN -> "↓"
        FLAT -> "→"
    }
}

/**
 * Data point for chart visualization.
 */
data class ChartDataPoint(
    val label: String,
    val value: Float,
    val date: LocalDate? = null
)

/**
 * Summary statistics for a single metric.
 */
data class MetricSummary(
    val type: MetricType,
    val currentValue: Float,
    val previousValue: Float,
    val trend: TrendDirection,
    val changePercent: Float,
    val goalProgress: Float? = null
) {
    /**
     * Whether the goal has been met.
     */
    fun isGoalMet(): Boolean {
        return type.goal?.let { currentValue >= it } ?: false
    }

    /**
     * Progress towards goal as percentage (0-100).
     */
    fun getGoalProgressPercent(): Float {
        return type.goal?.let {
            ((currentValue / it) * 100f).coerceIn(0f, 100f)
        } ?: 0f
    }
}

/**
 * Complete health summary with all metrics.
 */
data class HealthSummary(
    val summaries: List<MetricSummary>,
    val date: LocalDate = LocalDate.now()
) {
    /**
     * Get summary for a specific metric type.
     */
    fun getSummary(type: MetricType): MetricSummary? {
        return summaries.find { it.type == type }
    }

    /**
     * Get all metrics that met their goals.
     */
    fun getMetGoals(): List<MetricSummary> {
        return summaries.filter { it.isGoalMet() }
    }

    /**
     * Overall health score (percentage of goals met).
     */
    fun getHealthScore(): Float {
        val metricsWithGoals = summaries.filter { it.type.goal != null }
        if (metricsWithGoals.isEmpty()) return 0f

        val metGoals = metricsWithGoals.count { it.isGoalMet() }
        return (metGoals.toFloat() / metricsWithGoals.size) * 100f
    }
}

/**
 * Trend data for a metric over time.
 */
data class MetricTrend(
    val type: MetricType,
    val dataPoints: List<ChartDataPoint>,
    val timeRange: TimeRange,
    val average: Float,
    val peak: Float,
    val trend: TrendDirection
) {
    /**
     * Get the most recent value.
     */
    fun getCurrentValue(): Float {
        return dataPoints.lastOrNull()?.value ?: 0f
    }

    /**
     * Check if the trend is improving (based on metric type).
     */
    fun isImproving(): Boolean {
        // For most metrics, UP is good. For heart rate at rest, it depends.
        return when (type) {
            MetricType.HEART_RATE -> trend == TrendDirection.FLAT ||
                                     (average in 60f..100f && trend == TrendDirection.DOWN)
            else -> trend == TrendDirection.UP
        }
    }
}

/**
 * AI-generated or rule-based health insight.
 */
data class HealthInsight(
    val message: String,
    val type: InsightType,
    val relatedMetric: MetricType? = null,
    val priority: InsightPriority = InsightPriority.NORMAL
)

/**
 * Type of insight.
 */
enum class InsightType {
    ACHIEVEMENT,  // Positive accomplishment
    SUGGESTION,   // Actionable recommendation
    WARNING,      // Attention needed
    INFO          // General information
}

/**
 * Priority level for insights.
 */
enum class InsightPriority {
    LOW, NORMAL, HIGH
}
