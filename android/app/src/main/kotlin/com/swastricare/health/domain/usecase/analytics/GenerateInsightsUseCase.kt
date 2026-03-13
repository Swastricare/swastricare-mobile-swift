package com.swastricare.health.domain.usecase.analytics

import com.swastricare.health.domain.model.analytics.HealthInsight
import com.swastricare.health.domain.model.analytics.HealthSummary
import com.swastricare.health.domain.model.analytics.InsightPriority
import com.swastricare.health.domain.model.analytics.InsightType
import com.swastricare.health.domain.model.analytics.MetricType
import com.swastricare.health.domain.model.analytics.TrendDirection
import javax.inject.Inject
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Use case: Generate health insights from summary data.
 * Creates actionable recommendations and observations from health metrics.
 */
class GenerateInsightsUseCase @Inject constructor() {

    /**
     * Generate insights from health summary.
     *
     * @param summary The health summary to analyze
     * @return List of generated insights
     */
    operator fun invoke(summary: HealthSummary): List<HealthInsight> {
        val insights = mutableListOf<HealthInsight>()

        // Analyze each metric
        summary.summaries.forEach { metricSummary ->
            when (metricSummary.type) {
                MetricType.STEPS -> analyzeSteps(metricSummary, insights)
                MetricType.SLEEP -> analyzeSleep(metricSummary, insights)
                MetricType.HYDRATION -> analyzeHydration(metricSummary, insights)
                MetricType.MED_ADHERENCE -> analyzeMedicationAdherence(metricSummary, insights)
                MetricType.EXERCISE -> analyzeExercise(metricSummary, insights)
                MetricType.HEART_RATE -> analyzeHeartRate(metricSummary, insights)
                else -> {} // Other metrics don't generate insights yet
            }
        }

        // Overall health score insight
        val healthScore = summary.getHealthScore()
        if (healthScore >= 80f) {
            insights.add(
                HealthInsight(
                    message = "Excellent work! You're meeting ${healthScore.roundToInt()}% of your health goals today.",
                    type = InsightType.ACHIEVEMENT,
                    priority = InsightPriority.NORMAL
                )
            )
        }

        // If no insights, add a generic one
        if (insights.isEmpty()) {
            insights.add(
                HealthInsight(
                    message = "Start tracking your health data to receive personalized insights.",
                    type = InsightType.INFO,
                    priority = InsightPriority.LOW
                )
            )
        }

        return insights.sortedByDescending { it.priority }
    }

    private fun analyzeSteps(
        summary: com.swastricare.health.domain.model.analytics.MetricSummary,
        insights: MutableList<HealthInsight>
    ) {
        val pct = abs(summary.changePercent).roundToInt()

        when {
            summary.currentValue == 0f -> {
                insights.add(
                    HealthInsight(
                        message = "No step data available yet. Connect Health Connect to track your daily steps.",
                        type = InsightType.INFO,
                        relatedMetric = MetricType.STEPS,
                        priority = InsightPriority.LOW
                    )
                )
            }
            summary.trend == TrendDirection.UP && pct > 10 -> {
                insights.add(
                    HealthInsight(
                        message = "Your step count has increased by $pct% compared to your recent average. Keep up the great work!",
                        type = InsightType.ACHIEVEMENT,
                        relatedMetric = MetricType.STEPS,
                        priority = InsightPriority.NORMAL
                    )
                )
            }
            summary.trend == TrendDirection.DOWN && pct > 10 -> {
                insights.add(
                    HealthInsight(
                        message = "Your step count decreased by $pct%. Try taking short walks between tasks.",
                        type = InsightType.SUGGESTION,
                        relatedMetric = MetricType.STEPS,
                        priority = InsightPriority.NORMAL
                    )
                )
            }
            summary.isGoalMet() -> {
                insights.add(
                    HealthInsight(
                        message = "You've hit your step goal of ${MetricType.STEPS.goal?.roundToInt() ?: 10000} steps today!",
                        type = InsightType.ACHIEVEMENT,
                        relatedMetric = MetricType.STEPS,
                        priority = InsightPriority.NORMAL
                    )
                )
            }
            else -> {
                val remaining = (MetricType.STEPS.goal ?: 10000f) - summary.currentValue
                insights.add(
                    HealthInsight(
                        message = "You've taken ${summary.currentValue.roundToInt()} steps today. ${remaining.roundToInt()} more to reach your goal!",
                        type = InsightType.INFO,
                        relatedMetric = MetricType.STEPS,
                        priority = InsightPriority.LOW
                    )
                )
            }
        }
    }

    private fun analyzeSleep(
        summary: com.swastricare.health.domain.model.analytics.MetricSummary,
        insights: MutableList<HealthInsight>
    ) {
        when {
            summary.currentValue == 0f -> {} // No data, skip
            summary.currentValue >= 7f -> {
                insights.add(
                    HealthInsight(
                        message = "You are getting a healthy amount of sleep (${summary.currentValue.roundToInt()} hours). Consistency is key.",
                        type = InsightType.ACHIEVEMENT,
                        relatedMetric = MetricType.SLEEP,
                        priority = InsightPriority.NORMAL
                    )
                )
            }
            summary.currentValue > 0f -> {
                insights.add(
                    HealthInsight(
                        message = "You slept ${summary.currentValue.roundToInt()} hours. Consider aiming for 7-8 hours for optimal recovery.",
                        type = InsightType.SUGGESTION,
                        relatedMetric = MetricType.SLEEP,
                        priority = InsightPriority.HIGH
                    )
                )
            }
        }
    }

    private fun analyzeHydration(
        summary: com.swastricare.health.domain.model.analytics.MetricSummary,
        insights: MutableList<HealthInsight>
    ) {
        val goal = MetricType.HYDRATION.goal ?: 2500f

        when {
            summary.currentValue >= goal -> {
                insights.add(
                    HealthInsight(
                        message = "Great hydration today! You've hit your daily water goal of ${goal.roundToInt()}ml.",
                        type = InsightType.ACHIEVEMENT,
                        relatedMetric = MetricType.HYDRATION,
                        priority = InsightPriority.NORMAL
                    )
                )
            }
            summary.currentValue > 0f -> {
                val remaining = goal - summary.currentValue
                insights.add(
                    HealthInsight(
                        message = "You've had ${summary.currentValue.roundToInt()}ml of water. ${remaining.roundToInt()}ml more to reach your ${goal.roundToInt()}ml goal.",
                        type = InsightType.INFO,
                        relatedMetric = MetricType.HYDRATION,
                        priority = InsightPriority.LOW
                    )
                )
            }
        }
    }

    private fun analyzeMedicationAdherence(
        summary: com.swastricare.health.domain.model.analytics.MetricSummary,
        insights: MutableList<HealthInsight>
    ) {
        when {
            summary.currentValue >= 100f -> {
                insights.add(
                    HealthInsight(
                        message = "Perfect medication adherence today! Keep up the excellent routine.",
                        type = InsightType.ACHIEVEMENT,
                        relatedMetric = MetricType.MED_ADHERENCE,
                        priority = InsightPriority.NORMAL
                    )
                )
            }
            summary.currentValue < 80f && summary.currentValue > 0f -> {
                insights.add(
                    HealthInsight(
                        message = "Don't forget to take your medications. Adherence is at ${summary.currentValue.roundToInt()}%.",
                        type = InsightType.WARNING,
                        relatedMetric = MetricType.MED_ADHERENCE,
                        priority = InsightPriority.HIGH
                    )
                )
            }
        }
    }

    private fun analyzeExercise(
        summary: com.swastricare.health.domain.model.analytics.MetricSummary,
        insights: MutableList<HealthInsight>
    ) {
        val goal = MetricType.EXERCISE.goal ?: 30f

        if (summary.currentValue >= goal) {
            insights.add(
                HealthInsight(
                    message = "You've completed ${summary.currentValue.roundToInt()} minutes of exercise today. Great job!",
                    type = InsightType.ACHIEVEMENT,
                    relatedMetric = MetricType.EXERCISE,
                    priority = InsightPriority.NORMAL
                )
            )
        }
    }

    private fun analyzeHeartRate(
        summary: com.swastricare.health.domain.model.analytics.MetricSummary,
        insights: MutableList<HealthInsight>
    ) {
        val bpm = summary.currentValue.roundToInt()

        when {
            bpm == 0 -> {} // No data
            bpm < 60 -> {
                insights.add(
                    HealthInsight(
                        message = "Your resting heart rate is ${bpm} BPM, which is below the normal range. Consider consulting a healthcare provider.",
                        type = InsightType.WARNING,
                        relatedMetric = MetricType.HEART_RATE,
                        priority = InsightPriority.HIGH
                    )
                )
            }
            bpm in 60..100 -> {
                insights.add(
                    HealthInsight(
                        message = "Your resting heart rate is ${bpm} BPM, which is in the healthy range.",
                        type = InsightType.INFO,
                        relatedMetric = MetricType.HEART_RATE,
                        priority = InsightPriority.LOW
                    )
                )
            }
            bpm > 100 -> {
                insights.add(
                    HealthInsight(
                        message = "Your resting heart rate is ${bpm} BPM, which is elevated. Monitor it and consult a healthcare provider if it persists.",
                        type = InsightType.WARNING,
                        relatedMetric = MetricType.HEART_RATE,
                        priority = InsightPriority.HIGH
                    )
                )
            }
        }
    }
}
