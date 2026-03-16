package com.swastricare.health.ui.screens.analytics

import android.util.Log
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.repository.SupabaseDietRepository
import com.swastricare.health.data.repository.SupabaseHydrationRepository
import com.swastricare.health.data.repository.SupabaseMedicationRepository
import com.swastricare.health.data.repository.SupabaseProfileRepository
import com.swastricare.health.data.repository.SupabaseRunActivityRepository
import com.swastricare.health.data.services.HealthConnectService
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import kotlin.math.abs
import kotlin.math.roundToInt

// ── Time Range ──────────────────────────────────────────────────────────────
enum class LegacyTimeRange(val label: String) {
    Day("Day"),
    Week("Week"),
    Month("Month")
}

// ── Metric Type ─────────────────────────────────────────────────────────────
enum class LegacyMetricType(
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
    Distance("Distance", "km", Color(0xFF00BCD4), 5f),
    Hydration("Hydration", "ml", Color(0xFF03A9F4), 2500f),
    MedAdherence("Medication", "%", Color(0xFFE91E63), 100f)
}

// ── Trend Direction ─────────────────────────────────────────────────────────
enum class LegacyTrendDirection { Up, Down, Flat }

// ── Data Point for charts ───────────────────────────────────────────────────
data class LegacyChartDataPoint(
    val label: String,
    val value: Float
)

// ── Summary for a single metric ─────────────────────────────────────────────
data class LegacyMetricSummary(
    val type: LegacyMetricType,
    val currentValue: Float,
    val previousValue: Float,
    val trend: LegacyTrendDirection,
    val changePercent: Float
)

// ── Metric stats (current / average / best / goal) ──────────────────────────
data class MetricStats(
    val current: Float,
    val average: Float,
    val best: Float,
    val goal: Float?
)

// ── Overall UI State ────────────────────────────────────────────────────────
data class LegacyHealthAnalyticsState(
    val isLoading: Boolean = true,
    val selectedTimeRange: LegacyTimeRange = LegacyTimeRange.Week,
    val selectedMetric: LegacyMetricType = LegacyMetricType.Steps,
    val summaries: List<LegacyMetricSummary> = emptyList(),
    val chartData: List<LegacyChartDataPoint> = emptyList(),
    val aiInsight: String = "",
    val healthScore: Int = 0
)

@HiltViewModel
class HealthAnalyticsViewModel @Inject constructor(
    private val healthConnectService: HealthConnectService,
    private val hydrationRepository: SupabaseHydrationRepository,
    private val dietRepository: SupabaseDietRepository,
    private val medicationRepository: SupabaseMedicationRepository,
    private val runActivityRepository: SupabaseRunActivityRepository,
    private val profileRepository: SupabaseProfileRepository,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(LegacyHealthAnalyticsState())
    val uiState: StateFlow<LegacyHealthAnalyticsState> = _uiState.asStateFlow()

    // Cached data for chart generation
    private var weeklyStepCounts: List<Pair<LocalDate, Long>> = emptyList()
    private var hydrationByDay: Map<LocalDate, Int> = emptyMap()
    private var dietCaloriesByDay: Map<LocalDate, Double> = emptyMap()
    private var runActivitiesByDay: Map<LocalDate, Double> = emptyMap() // distance in km
    private var todaySteps: Int = 0
    private var todayCalories: Int = 0
    private var todayHeartRate: Int = 0
    private var todaySleepHours: Float = 0f
    private var todayExerciseMin: Int = 0
    private var todayDistanceKm: Float = 0f
    private var todayHydrationMl: Int = 0
    private var todayMedAdherence: Float = 0f

    init {
        loadData()
    }

    // ── Public actions ──────────────────────────────────────────────────────

    fun selectTimeRange(range: LegacyTimeRange) {
        _uiState.value = _uiState.value.copy(selectedTimeRange = range)
        refreshChart()
    }

    fun selectMetric(metric: LegacyMetricType) {
        _uiState.value = _uiState.value.copy(selectedMetric = metric)
        refreshChart()
    }

    // ── Data loading ────────────────────────────────────────────────────────

    private fun loadData() {
        viewModelScope.launch {
            try {
                val today = LocalDate.now()
                val yesterday = today.minusDays(1)

                // Fetch data from all sources concurrently
                coroutineScope {
                    val summaryDeferred = async { fetchHealthConnectData() }
                    val weeklyStepsDeferred = async { fetchWeeklySteps() }
                    val hydrationDeferred = async { fetchHydrationData(today) }
                    val dietDeferred = async { fetchDietData(today) }
                    val medDeferred = async { fetchMedicationAdherence(today) }
                    val runDeferred = async { fetchRunActivityData() }

                    summaryDeferred.await()
                    weeklyStepsDeferred.await()
                    hydrationDeferred.await()
                    dietDeferred.await()
                    medDeferred.await()
                    runDeferred.await()
                }

                // Compute previous values for comparison
                val yesterdaySteps = weeklyStepCounts
                    .find { it.first == yesterday }?.second?.toInt() ?: 0
                val weekAvgSteps = if (weeklyStepCounts.isNotEmpty()) {
                    weeklyStepCounts.map { it.second }.average().toFloat()
                } else 0f

                val yesterdayHydration = hydrationByDay[yesterday] ?: 0
                val yesterdayDietCal = dietCaloriesByDay[yesterday] ?: 0.0

                // Build summaries for all metrics
                val summaries = buildSummaries(
                    prevSteps = if (yesterdaySteps > 0) yesterdaySteps.toFloat() else weekAvgSteps,
                    prevHydration = yesterdayHydration.toFloat()
                )

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    summaries = summaries,
                    aiInsight = generateInsight(summaries),
                    healthScore = computeHealthScore()
                )
                refreshChart()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to load analytics data", e)
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }

    private suspend fun fetchHealthConnectData() {
        try {
            val summary = healthConnectService.getTodaySummary()
            todaySteps = summary.steps
            todayCalories = summary.activeCalories
            todayHeartRate = summary.heartRate
            todaySleepHours = summary.sleepMinutes / 60f
            todayExerciseMin = summary.exerciseMinutes
            todayDistanceKm = summary.distanceKm.toFloat()
        } catch (e: Exception) {
            Log.w(TAG, "HealthConnect data unavailable", e)
        }
    }

    private suspend fun fetchWeeklySteps() {
        try {
            val counts = healthConnectService.getWeeklyStepCounts()
            weeklyStepCounts = counts.map { it.date to it.steps }
        } catch (e: Exception) {
            Log.w(TAG, "Weekly steps unavailable", e)
        }
    }

    private fun fetchHydrationData(today: LocalDate) {
        try {
            val entries = hydrationRepository.loadLocalEntries()
            hydrationByDay = entries.groupBy { parseDateFromIso(it.consumedAt) }
                .mapValues { (_, list) -> list.sumOf { it.amountMl } }
            todayHydrationMl = hydrationByDay[today] ?: 0
        } catch (e: Exception) {
            Log.w(TAG, "Hydration data unavailable", e)
        }
    }

    private fun fetchDietData(today: LocalDate) {
        try {
            val logs = dietRepository.loadLocalLogs()
            dietCaloriesByDay = logs.groupBy { parseDateFromIso(it.loggedAt) }
                .mapValues { (_, list) -> list.sumOf { it.calories } }
        } catch (e: Exception) {
            Log.w(TAG, "Diet data unavailable", e)
        }
    }

    private suspend fun fetchMedicationAdherence(today: LocalDate) {
        try {
            val userId = supabaseClient.auth.currentSessionOrNull()?.user?.id ?: return
            val profile = profileRepository.getHealthProfile(userId) ?: return
            val profileId = profile.id ?: return
            val todayLogs = medicationRepository.fetchTodayLogs(profileId, today)
            if (todayLogs.isNotEmpty()) {
                val taken = todayLogs.count { it.status == "taken" || it.status == "late" || it.status == "early" }
                todayMedAdherence = (taken.toFloat() / todayLogs.size) * 100f
            }
        } catch (e: Exception) {
            Log.w(TAG, "Medication adherence unavailable", e)
        }
    }

    private fun fetchRunActivityData() {
        try {
            val activities = runActivityRepository.loadLocalActivities()
            runActivitiesByDay = activities
                .filter { it.startTime != null }
                .groupBy { it.startTime!!.toLocalDate() }
                .mapValues { (_, list) -> list.sumOf { it.distanceMeters } / 1000.0 }
        } catch (e: Exception) {
            Log.w(TAG, "Run activity data unavailable", e)
        }
    }

    // ── Build summaries ──────────────────────────────────────────────────────

    private fun buildSummaries(
        prevSteps: Float,
        prevHydration: Float
    ): List<LegacyMetricSummary> {
        return LegacyMetricType.entries.map { type ->
            val (current, previous) = when (type) {
                LegacyMetricType.Steps -> todaySteps.toFloat() to prevSteps
                LegacyMetricType.Calories -> todayCalories.toFloat() to todayCalories.toFloat()
                LegacyMetricType.HeartRate -> todayHeartRate.toFloat() to todayHeartRate.toFloat()
                LegacyMetricType.Sleep -> todaySleepHours to todaySleepHours
                LegacyMetricType.Exercise -> todayExerciseMin.toFloat() to todayExerciseMin.toFloat()
                LegacyMetricType.Distance -> todayDistanceKm to todayDistanceKm
                LegacyMetricType.Hydration -> todayHydrationMl.toFloat() to prevHydration
                LegacyMetricType.MedAdherence -> todayMedAdherence to todayMedAdherence
            }
            val change = if (previous != 0f) ((current - previous) / previous * 100f) else 0f
            val trend = when {
                change > 2f -> LegacyTrendDirection.Up
                change < -2f -> LegacyTrendDirection.Down
                else -> LegacyTrendDirection.Flat
            }
            LegacyMetricSummary(
                type = type,
                currentValue = current,
                previousValue = previous,
                trend = trend,
                changePercent = change
            )
        }
    }

    // ── Chart data generation ────────────────────────────────────────────────

    private fun refreshChart() {
        val state = _uiState.value
        val data = generateChartData(state.selectedMetric, state.selectedTimeRange)
        _uiState.value = state.copy(chartData = data)
    }

    private fun generateChartData(
        metric: LegacyMetricType,
        range: LegacyTimeRange
    ): List<LegacyChartDataPoint> {
        val today = LocalDate.now()
        return when (range) {
            LegacyTimeRange.Day -> generateDayChart(metric, today)
            LegacyTimeRange.Week -> generateWeekChart(metric, today)
            LegacyTimeRange.Month -> generateMonthChart(metric, today)
        }
    }

    private fun generateDayChart(metric: LegacyMetricType, today: LocalDate): List<LegacyChartDataPoint> {
        // For day view, distribute today's total across time-of-day activity pattern
        val totalValue = when (metric) {
            LegacyMetricType.Steps -> todaySteps.toFloat()
            LegacyMetricType.Calories -> todayCalories.toFloat()
            LegacyMetricType.HeartRate -> todayHeartRate.toFloat()
            LegacyMetricType.Sleep -> todaySleepHours
            LegacyMetricType.Exercise -> todayExerciseMin.toFloat()
            LegacyMetricType.Distance -> todayDistanceKm
            LegacyMetricType.Hydration -> todayHydrationMl.toFloat()
            LegacyMetricType.MedAdherence -> todayMedAdherence
        }

        return (0..23).map { hour ->
            val label = if (hour % 4 == 0) "${hour}h" else ""
            val multiplier = hourlyActivityMultiplier(hour)
            val value = when (metric) {
                LegacyMetricType.HeartRate -> if (todayHeartRate > 0) 60f + 20f * multiplier else 0f
                LegacyMetricType.Sleep -> if (hour in 0..7 || hour >= 23) todaySleepHours / 8f else 0f
                LegacyMetricType.MedAdherence -> if (hour == 8 || hour == 20) todayMedAdherence / 2f else 0f
                else -> totalValue * multiplier / HOURLY_MULTIPLIER_SUM
            }
            LegacyChartDataPoint(label, value.coerceAtLeast(0f))
        }
    }

    private fun generateWeekChart(metric: LegacyMetricType, today: LocalDate): List<LegacyChartDataPoint> {
        val days = (6 downTo 0).map { today.minusDays(it.toLong()) }
        val dayLabels = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

        return days.map { date ->
            val label = dayLabels[date.dayOfWeek.value - 1]
            val value = getDailyValueForMetric(metric, date)
            LegacyChartDataPoint(label, value)
        }
    }

    private fun generateMonthChart(metric: LegacyMetricType, today: LocalDate): List<LegacyChartDataPoint> {
        return (29 downTo 0).map { daysAgo ->
            val date = today.minusDays(daysAgo.toLong())
            val dayNum = date.dayOfMonth
            val label = if (dayNum % 5 == 0 || dayNum == 1) "$dayNum" else ""
            val value = getDailyValueForMetric(metric, date)
            LegacyChartDataPoint(label, value)
        }
    }

    private fun getDailyValueForMetric(metric: LegacyMetricType, date: LocalDate): Float {
        val today = LocalDate.now()
        return when (metric) {
            LegacyMetricType.Steps -> {
                if (date == today) todaySteps.toFloat()
                else weeklyStepCounts.find { it.first == date }?.second?.toFloat() ?: 0f
            }
            LegacyMetricType.Calories -> {
                if (date == today) todayCalories.toFloat() else 0f
            }
            LegacyMetricType.HeartRate -> {
                if (date == today) todayHeartRate.toFloat() else 0f
            }
            LegacyMetricType.Sleep -> {
                if (date == today) todaySleepHours else 0f
            }
            LegacyMetricType.Exercise -> {
                if (date == today) todayExerciseMin.toFloat() else 0f
            }
            LegacyMetricType.Distance -> {
                val runDistance = runActivitiesByDay[date]?.toFloat() ?: 0f
                if (date == today) maxOf(todayDistanceKm, runDistance) else runDistance
            }
            LegacyMetricType.Hydration -> {
                (hydrationByDay[date] ?: 0).toFloat()
            }
            LegacyMetricType.MedAdherence -> {
                if (date == today) todayMedAdherence else 0f
            }
        }
    }

    // ── Insights generation ──────────────────────────────────────────────────

    private fun generateInsight(summaries: List<LegacyMetricSummary>): String {
        val parts = mutableListOf<String>()

        val stepsSummary = summaries.find { it.type == LegacyMetricType.Steps }
        stepsSummary?.let {
            val pct = abs(it.changePercent).roundToInt()
            when {
                it.currentValue == 0f -> parts.add("No step data available yet. Connect Health Connect to track your daily steps.")
                it.trend == LegacyTrendDirection.Up -> parts.add("Your step count has increased by $pct% compared to your recent average. Keep up the great work!")
                it.trend == LegacyTrendDirection.Down -> parts.add("Your step count decreased by $pct%. Try taking short walks between tasks.")
                else -> parts.add("You've taken ${it.currentValue.roundToInt()} steps today. Aim for ${LegacyMetricType.Steps.goal?.roundToInt() ?: 10000} to hit your goal!")
            }
        }

        val sleepSummary = summaries.find { it.type == LegacyMetricType.Sleep }
        sleepSummary?.let {
            when {
                it.currentValue == 0f -> {} // no data, skip
                it.currentValue >= 7f -> parts.add("You are getting a healthy amount of sleep. Consistency is key.")
                it.currentValue > 0f -> parts.add("Consider aiming for 7-8 hours of sleep for optimal recovery.")
            }
        }

        val hydrationSummary = summaries.find { it.type == LegacyMetricType.Hydration }
        hydrationSummary?.let {
            val goal = LegacyMetricType.Hydration.goal ?: 2500f
            when {
                it.currentValue >= goal -> parts.add("Great hydration today! You've hit your daily water goal.")
                it.currentValue > 0f -> parts.add("You've had ${it.currentValue.roundToInt()}ml of water. Keep drinking to reach your ${goal.roundToInt()}ml goal.")
            }
        }

        if (parts.isEmpty()) {
            parts.add("Start tracking your health data to receive personalized insights.")
        }

        return parts.joinToString(" ")
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun parseDateFromIso(dateTimeStr: String): LocalDate {
        return try {
            LocalDate.parse(dateTimeStr.take(10), DateTimeFormatter.ISO_LOCAL_DATE)
        } catch (_: Exception) {
            LocalDate.now()
        }
    }

    private fun hourlyActivityMultiplier(hour: Int): Float = when (hour) {
        in 0..5 -> 0.1f
        in 6..8 -> 0.8f
        in 9..11 -> 0.6f
        12 -> 0.5f
        in 13..16 -> 0.5f
        in 17..19 -> 0.9f
        in 20..22 -> 0.3f
        else -> 0.1f
    }

    private fun computeHealthScore(): Int {
        val stepsScore = if (LegacyMetricType.Steps.goal != null)
            (todaySteps.toFloat() / LegacyMetricType.Steps.goal!! * 100f).coerceIn(0f, 100f)
        else 0f
        val sleepScore = (todaySleepHours / 8f * 100f).coerceIn(0f, 100f)
        val hydrationScore = if (LegacyMetricType.Hydration.goal != null)
            (todayHydrationMl.toFloat() / LegacyMetricType.Hydration.goal!! * 100f).coerceIn(0f, 100f)
        else 0f
        val heartScore = when {
            todayHeartRate == 0 -> 0f
            todayHeartRate in 60..100 -> 100f
            todayHeartRate in 50..59 || todayHeartRate in 101..110 -> 70f
            else -> 30f
        }

        return (stepsScore * 0.30f + sleepScore * 0.25f + hydrationScore * 0.25f + heartScore * 0.20f)
            .toInt().coerceIn(0, 100)
    }

    fun getMetricStats(metric: LegacyMetricType): MetricStats {
        val allValues: List<Float> = when (metric) {
            LegacyMetricType.Steps -> weeklyStepCounts.map { it.second.toFloat() }
                .ifEmpty { listOf(todaySteps.toFloat()) }
            LegacyMetricType.Hydration -> hydrationByDay.values.map { it.toFloat() }
                .ifEmpty { listOf(todayHydrationMl.toFloat()) }
            LegacyMetricType.Distance -> runActivitiesByDay.values.map { it.toFloat() }
                .ifEmpty { listOf(todayDistanceKm) }
            else -> listOf(getDailyValueForMetric(metric, java.time.LocalDate.now()))
        }
        val current = getDailyValueForMetric(metric, java.time.LocalDate.now())
        val avg = if (allValues.isNotEmpty()) allValues.average().toFloat() else current
        val best = allValues.maxOrNull() ?: current
        return MetricStats(current = current, average = avg, best = best, goal = metric.goal)
    }

    fun generatePublicChartData(metric: LegacyMetricType, range: LegacyTimeRange): List<LegacyChartDataPoint> {
        return generateChartData(metric, range)
    }

    companion object {
        private const val TAG = "HealthAnalyticsVM"
        // Sum of all hourly multipliers for normalization
        private val HOURLY_MULTIPLIER_SUM: Float = run {
            var total = 0
            for (hour in 0..23) {
                total += when (hour) {
                    in 0..5 -> 10
                    in 6..8 -> 80
                    in 9..11 -> 60
                    12 -> 50
                    in 13..16 -> 50
                    in 17..19 -> 90
                    in 20..22 -> 30
                    else -> 10
                }
            }
            total.toFloat() / 100f
        }
    }
}
