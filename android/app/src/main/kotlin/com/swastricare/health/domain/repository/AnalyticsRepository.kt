package com.swastricare.health.domain.repository

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.analytics.ChartDataPoint
import com.swastricare.health.domain.model.analytics.HealthSummary
import com.swastricare.health.domain.model.analytics.MetricType
import com.swastricare.health.domain.model.analytics.TimeRange
import java.time.LocalDate

/**
 * Repository contract for health analytics data.
 * Aggregates data from multiple sources to provide health insights.
 */
interface AnalyticsRepository {

    // ── Summary data ──

    /**
     * Get health summary for today.
     */
    suspend fun getTodaySummary(): ResultWrapper<HealthSummary>

    /**
     * Get health summary for a specific date.
     */
    suspend fun getSummaryForDate(date: LocalDate): ResultWrapper<HealthSummary>

    // ── Chart data ──

    /**
     * Get chart data for a specific metric and time range.
     */
    suspend fun getChartData(
        metric: MetricType,
        timeRange: TimeRange
    ): ResultWrapper<List<ChartDataPoint>>

    // ── Individual metric data ──

    /**
     * Get step count data from Health Connect.
     */
    suspend fun getStepsData(): ResultWrapper<Pair<Int, List<Pair<LocalDate, Long>>>>

    /**
     * Get calories data from Health Connect.
     */
    suspend fun getCaloriesData(): ResultWrapper<Int>

    /**
     * Get heart rate data from Health Connect.
     */
    suspend fun getHeartRateData(): ResultWrapper<Int>

    /**
     * Get sleep data from Health Connect.
     */
    suspend fun getSleepData(): ResultWrapper<Float>

    /**
     * Get exercise minutes from Health Connect.
     */
    suspend fun getExerciseData(): ResultWrapper<Int>

    /**
     * Get distance data from Health Connect.
     */
    suspend fun getDistanceData(): ResultWrapper<Float>

    /**
     * Get hydration data from local storage.
     */
    suspend fun getHydrationData(): ResultWrapper<Map<LocalDate, Int>>

    /**
     * Get medication adherence data.
     */
    suspend fun getMedicationAdherence(date: LocalDate): ResultWrapper<Float>

    /**
     * Get diet/calories data from local storage.
     */
    suspend fun getDietData(): ResultWrapper<Map<LocalDate, Double>>

    /**
     * Get run activity data from local storage.
     */
    suspend fun getRunActivityData(): ResultWrapper<Map<LocalDate, Double>>
}
