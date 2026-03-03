package com.swasthicare.mobile.ui.screens.analytics

import androidx.compose.ui.graphics.Color
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.random.Random

// ── Time Range ──────────────────────────────────────────────────────────────
enum class TimeRange(val label: String) {
    Day("Day"),
    Week("Week"),
    Month("Month")
}

// ── Metric Type ─────────────────────────────────────────────────────────────
enum class MetricType(
    val label: String,
    val unit: String,
    val color: Color,
    val goal: Float?
) {
    Steps("Steps", "steps", Color(0xFF2196F3), 10_000f),
    Calories("Calories", "kcal", Color(0xFFFF9800), 500f),
    HeartRate("Heart Rate", "BPM", Color(0xFFF44336), null),
    Sleep("Sleep", "hrs", Color(0xFF3F51B5), 8f),
    Exercise("Exercise", "min", Color(0xFF4CAF50), 30f),
    Distance("Distance", "km", Color(0xFF00BCD4), 5f)
}

// ── Trend Direction ─────────────────────────────────────────────────────────
enum class TrendDirection { Up, Down, Flat }

// ── Data Point for charts ───────────────────────────────────────────────────
data class ChartDataPoint(
    val label: String,
    val value: Float
)

// ── Summary for a single metric ─────────────────────────────────────────────
data class MetricSummary(
    val type: MetricType,
    val currentValue: Float,
    val previousValue: Float,
    val trend: TrendDirection,
    val changePercent: Float
)

// ── Overall UI State ────────────────────────────────────────────────────────
data class HealthAnalyticsState(
    val isLoading: Boolean = true,
    val selectedTimeRange: TimeRange = TimeRange.Week,
    val selectedMetric: MetricType = MetricType.Steps,
    val summaries: List<MetricSummary> = emptyList(),
    val chartData: List<ChartDataPoint> = emptyList(),
    val aiInsight: String = ""
)

class HealthAnalyticsViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(HealthAnalyticsState())
    val uiState: StateFlow<HealthAnalyticsState> = _uiState.asStateFlow()

    init {
        loadData()
    }

    // ── Public actions ──────────────────────────────────────────────────────

    fun selectTimeRange(range: TimeRange) {
        _uiState.value = _uiState.value.copy(selectedTimeRange = range)
        refreshChart()
    }

    fun selectMetric(metric: MetricType) {
        _uiState.value = _uiState.value.copy(selectedMetric = metric)
        refreshChart()
    }

    // ── Data loading ────────────────────────────────────────────────────────

    private fun loadData() {
        viewModelScope.launch {
            delay(800)

            val summaries = MetricType.entries.map { type ->
                val (current, previous) = generateSummaryValues(type)
                val change = if (previous != 0f) ((current - previous) / previous * 100f) else 0f
                val trend = when {
                    change > 2f -> TrendDirection.Up
                    change < -2f -> TrendDirection.Down
                    else -> TrendDirection.Flat
                }
                MetricSummary(
                    type = type,
                    currentValue = current,
                    previousValue = previous,
                    trend = trend,
                    changePercent = change
                )
            }

            _uiState.value = _uiState.value.copy(
                isLoading = false,
                summaries = summaries,
                aiInsight = generateInsight(summaries)
            )
            refreshChart()
        }
    }

    private fun refreshChart() {
        val state = _uiState.value
        val data = generateChartData(state.selectedMetric, state.selectedTimeRange)
        _uiState.value = state.copy(chartData = data)
    }

    // ── Sample data generators ──────────────────────────────────────────────

    private fun generateSummaryValues(type: MetricType): Pair<Float, Float> = when (type) {
        MetricType.Steps -> 8432f to 7350f
        MetricType.Calories -> 450f to 410f
        MetricType.HeartRate -> 72f to 74f
        MetricType.Sleep -> 7.5f to 6.8f
        MetricType.Exercise -> 45f to 38f
        MetricType.Distance -> 5.2f to 4.8f
    }

    private fun generateChartData(
        metric: MetricType,
        range: TimeRange
    ): List<ChartDataPoint> {
        val rng = Random(metric.ordinal.toLong() + range.ordinal.toLong())
        return when (range) {
            TimeRange.Day -> {
                // Hourly data (24 bars)
                (0..23).map { hour ->
                    val label = if (hour % 4 == 0) "${hour}h" else ""
                    val base = baseValueForHour(metric, hour)
                    ChartDataPoint(label, base * (0.7f + rng.nextFloat() * 0.6f))
                }
            }
            TimeRange.Week -> {
                val days = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
                days.map { day ->
                    val base = baseDailyValue(metric)
                    ChartDataPoint(day, base * (0.6f + rng.nextFloat() * 0.8f))
                }
            }
            TimeRange.Month -> {
                (1..30).map { day ->
                    val label = if (day % 5 == 0 || day == 1) "$day" else ""
                    val base = baseDailyValue(metric)
                    ChartDataPoint(label, base * (0.5f + rng.nextFloat() * 1.0f))
                }
            }
        }
    }

    private fun baseValueForHour(metric: MetricType, hour: Int): Float {
        // Simulate activity distribution across the day
        val activityMultiplier = when (hour) {
            in 0..5 -> 0.1f
            in 6..8 -> 0.8f
            in 9..11 -> 0.6f
            12 -> 0.5f
            in 13..16 -> 0.5f
            in 17..19 -> 0.9f
            in 20..22 -> 0.3f
            else -> 0.1f
        }
        return when (metric) {
            MetricType.Steps -> 500f * activityMultiplier
            MetricType.Calories -> 30f * activityMultiplier
            MetricType.HeartRate -> 65f + 20f * activityMultiplier
            MetricType.Sleep -> if (hour in 0..7 || hour >= 23) 1f else 0f
            MetricType.Exercise -> 5f * activityMultiplier
            MetricType.Distance -> 0.3f * activityMultiplier
        }
    }

    private fun baseDailyValue(metric: MetricType): Float = when (metric) {
        MetricType.Steps -> 8000f
        MetricType.Calories -> 450f
        MetricType.HeartRate -> 72f
        MetricType.Sleep -> 7f
        MetricType.Exercise -> 40f
        MetricType.Distance -> 5f
    }

    private fun generateInsight(summaries: List<MetricSummary>): String {
        val stepsSummary = summaries.find { it.type == MetricType.Steps }
        val sleepSummary = summaries.find { it.type == MetricType.Sleep }
        val parts = mutableListOf<String>()
        stepsSummary?.let {
            val pct = abs(it.changePercent).roundToInt()
            if (it.trend == TrendDirection.Up) {
                parts.add("Your step count has increased by $pct% compared to last period. Keep up the great work!")
            } else if (it.trend == TrendDirection.Down) {
                parts.add("Your step count decreased by $pct%. Try taking short walks between tasks.")
            }
        }
        sleepSummary?.let {
            if (it.currentValue >= 7f) {
                parts.add("You are getting a healthy amount of sleep. Consistency is key.")
            } else {
                parts.add("Consider aiming for 7-8 hours of sleep for optimal recovery.")
            }
        }
        return parts.joinToString(" ")
    }
}
