package com.swastricare.health.domain.usecase.analytics

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.analytics.ChartDataPoint
import com.swastricare.health.domain.model.analytics.MetricTrend
import com.swastricare.health.domain.model.analytics.MetricType
import com.swastricare.health.domain.model.analytics.TimeRange
import com.swastricare.health.domain.model.analytics.TrendDirection
import com.swastricare.health.domain.repository.AnalyticsRepository
import javax.inject.Inject
import kotlin.math.abs

/**
 * Use case: Get trend data for health metrics.
 * Analyzes data over time to identify patterns and trends.
 */
class GetTrendsUseCase @Inject constructor(
    private val repository: AnalyticsRepository
) {
    /**
     * Get trend data for a specific metric.
     *
     * @param metric The metric to analyze
     * @param timeRange The time range for the trend
     * @return Trend data with chart points and analysis
     */
    suspend operator fun invoke(
        metric: MetricType,
        timeRange: TimeRange
    ): ResultWrapper<MetricTrend> {
        return when (val result = repository.getChartData(metric, timeRange)) {
            is ResultWrapper.Success -> {
                val dataPoints = result.data
                val trend = analyzeTrend(dataPoints)

                ResultWrapper.Success(
                    MetricTrend(
                        type = metric,
                        dataPoints = dataPoints,
                        timeRange = timeRange,
                        average = calculateAverage(dataPoints),
                        peak = calculatePeak(dataPoints),
                        trend = trend
                    )
                )
            }
            is ResultWrapper.Error -> result
            is ResultWrapper.Loading -> ResultWrapper.Loading
        }
    }

    /**
     * Calculate average value from data points.
     */
    private fun calculateAverage(dataPoints: List<ChartDataPoint>): Float {
        if (dataPoints.isEmpty()) return 0f
        return dataPoints.map { it.value }.average().toFloat()
    }

    /**
     * Calculate peak value from data points.
     */
    private fun calculatePeak(dataPoints: List<ChartDataPoint>): Float {
        return dataPoints.maxOfOrNull { it.value } ?: 0f
    }

    /**
     * Analyze trend direction from data points.
     */
    private fun analyzeTrend(dataPoints: List<ChartDataPoint>): TrendDirection {
        if (dataPoints.size < 2) return TrendDirection.FLAT

        // Compare first half average to second half average
        val midpoint = dataPoints.size / 2
        val firstHalf = dataPoints.take(midpoint).map { it.value }.average().toFloat()
        val secondHalf = dataPoints.drop(midpoint).map { it.value }.average().toFloat()

        val change = ((secondHalf - firstHalf) / firstHalf) * 100f

        return when {
            abs(change) < 5f -> TrendDirection.FLAT
            change > 0 -> TrendDirection.UP
            else -> TrendDirection.DOWN
        }
    }
}
