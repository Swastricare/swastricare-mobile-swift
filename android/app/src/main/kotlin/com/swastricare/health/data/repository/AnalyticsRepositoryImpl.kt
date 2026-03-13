package com.swastricare.health.data.repository

import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.DietRepository
import com.swastricare.health.domain.repository.HydrationRepository
import com.swastricare.health.domain.repository.MedicationRepository
import com.swastricare.health.domain.repository.ProfileRepository
import com.swastricare.health.domain.repository.RunActivityRepository
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.domain.model.analytics.ChartDataPoint
import com.swastricare.health.domain.model.analytics.HealthSummary
import com.swastricare.health.domain.model.analytics.MetricSummary
import com.swastricare.health.domain.model.analytics.MetricType
import com.swastricare.health.domain.model.analytics.TimeRange
import com.swastricare.health.domain.model.analytics.TrendDirection
import com.swastricare.health.domain.repository.AnalyticsRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import kotlin.math.abs

/**
 * Implementation of AnalyticsRepository.
 * Aggregates data from multiple sources to provide health analytics.
 */
class AnalyticsRepositoryImpl @Inject constructor(
    private val healthConnectService: HealthConnectService,
    private val hydrationRepository: HydrationRepository,
    private val dietRepository: DietRepository,
    private val medicationRepository: MedicationRepository,
    private val runActivityRepository: RunActivityRepository,
    private val profileRepository: ProfileRepository,
    private val supabaseClient: SupabaseClient,
    private val logger: Logger
) : AnalyticsRepository {

    // Cached data
    private var cachedStepsData: Pair<Int, List<Pair<LocalDate, Long>>>? = null
    private var cachedHydrationData: Map<LocalDate, Int>? = null
    private var cachedDietData: Map<LocalDate, Double>? = null
    private var cachedRunActivityData: Map<LocalDate, Double>? = null
    private var lastCacheTime: Long = 0
    private val CACHE_DURATION_MS = 60_000L // 1 minute

    // ── Summary data ──

    override suspend fun getTodaySummary(): ResultWrapper<HealthSummary> {
        return getSummaryForDate(LocalDate.now())
    }

    override suspend fun getSummaryForDate(date: LocalDate): ResultWrapper<HealthSummary> =
        withContext(Dispatchers.IO) {
            try {
                // Refresh cache if needed
                if (System.currentTimeMillis() - lastCacheTime > CACHE_DURATION_MS) {
                    refreshCache()
                }

                // Fetch current day data
                val summary = healthConnectService.getTodaySummary()
                val todaySteps = summary.steps
                val todayCalories = summary.activeCalories
                val todayHeartRate = summary.heartRate
                val todaySleepHours = summary.sleepMinutes / 60f
                val todayExerciseMin = summary.exerciseMinutes
                val todayDistanceKm = summary.distanceKm.toFloat()

                // Get hydration
                val todayHydrationMl = cachedHydrationData?.get(date) ?: 0

                // Get medication adherence
                val todayMedAdherence = getMedicationAdherence(date).let {
                    when (it) {
                        is ResultWrapper.Success -> it.data
                        else -> 0f
                    }
                }

                // Calculate previous values for comparison
                val yesterday = date.minusDays(1)
                val yesterdaySteps = cachedStepsData?.second?.find { it.first == yesterday }?.second?.toInt() ?: 0
                val yesterdayHydration = cachedHydrationData?.get(yesterday) ?: 0

                // Build summaries
                val summaries = buildSummaries(
                    todaySteps = todaySteps.toFloat(),
                    todayCalories = todayCalories.toFloat(),
                    todayHeartRate = todayHeartRate.toFloat(),
                    todaySleepHours = todaySleepHours,
                    todayExerciseMin = todayExerciseMin.toFloat(),
                    todayDistanceKm = todayDistanceKm,
                    todayHydrationMl = todayHydrationMl.toFloat(),
                    todayMedAdherence = todayMedAdherence,
                    prevSteps = yesterdaySteps.toFloat(),
                    prevHydration = yesterdayHydration.toFloat()
                )

                ResultWrapper.Success(HealthSummary(summaries, date))
            } catch (e: Exception) {
                logger.e(TAG, "Failed to get health summary", e)
                ResultWrapper.Error(AppException.UnknownException("Failed to get health summary", e))
            }
        }

    // ── Chart data ──

    override suspend fun getChartData(
        metric: MetricType,
        timeRange: TimeRange
    ): ResultWrapper<List<ChartDataPoint>> = withContext(Dispatchers.IO) {
        try {
            val today = LocalDate.now()
            val dataPoints = when (timeRange) {
                TimeRange.DAY -> generateDayChart(metric, today)
                TimeRange.WEEK -> generateWeekChart(metric, today)
                TimeRange.MONTH -> generateMonthChart(metric, today)
            }
            ResultWrapper.Success(dataPoints)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to get chart data", e)
            ResultWrapper.Error(AppException.UnknownException("Failed to get chart data", e))
        }
    }

    // ── Individual metric data ──

    override suspend fun getStepsData(): ResultWrapper<Pair<Int, List<Pair<LocalDate, Long>>>> {
        return try {
            if (cachedStepsData == null) {
                refreshCache()
            }
            ResultWrapper.Success(cachedStepsData ?: (0 to emptyList()))
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException("Failed to get steps data", e))
        }
    }

    override suspend fun getCaloriesData(): ResultWrapper<Int> {
        return try {
            val summary = healthConnectService.getTodaySummary()
            ResultWrapper.Success(summary.activeCalories)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException("Failed to get calories data", e))
        }
    }

    override suspend fun getHeartRateData(): ResultWrapper<Int> {
        return try {
            val summary = healthConnectService.getTodaySummary()
            ResultWrapper.Success(summary.heartRate)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException("Failed to get heart rate data", e))
        }
    }

    override suspend fun getSleepData(): ResultWrapper<Float> {
        return try {
            val summary = healthConnectService.getTodaySummary()
            ResultWrapper.Success(summary.sleepMinutes / 60f)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException("Failed to get sleep data", e))
        }
    }

    override suspend fun getExerciseData(): ResultWrapper<Int> {
        return try {
            val summary = healthConnectService.getTodaySummary()
            ResultWrapper.Success(summary.exerciseMinutes)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException("Failed to get exercise data", e))
        }
    }

    override suspend fun getDistanceData(): ResultWrapper<Float> {
        return try {
            val summary = healthConnectService.getTodaySummary()
            ResultWrapper.Success(summary.distanceKm.toFloat())
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException("Failed to get distance data", e))
        }
    }

    override suspend fun getHydrationData(): ResultWrapper<Map<LocalDate, Int>> {
        return try {
            if (cachedHydrationData == null) {
                refreshCache()
            }
            ResultWrapper.Success(cachedHydrationData ?: emptyMap())
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException("Failed to get hydration data", e))
        }
    }

    override suspend fun getMedicationAdherence(date: LocalDate): ResultWrapper<Float> {
        return try {
            val userId = supabaseClient.auth.currentSessionOrNull()?.user?.id
                ?: return ResultWrapper.Success(0f)

            val profile = when (val result = profileRepository.getHealthProfile(userId)) {
                is ResultWrapper.Success -> result.data
                else -> null
            } ?: return ResultWrapper.Success(0f)

            val profileId = profile.id

            val logsResult = medicationRepository.getLogsForDate(profileId, date)
            if (logsResult.isSuccess) {
                val logs = logsResult.getOrThrow()
                if (logs.isEmpty()) {
                    ResultWrapper.Success(0f)
                } else {
                    val taken = logs.count { log ->
                        log.status == com.swastricare.health.domain.model.AdherenceStatus.TAKEN ||
                        log.status == com.swastricare.health.domain.model.AdherenceStatus.LATE ||
                        log.status == com.swastricare.health.domain.model.AdherenceStatus.EARLY
                    }
                    val adherence = (taken.toFloat() / logs.size) * 100f
                    ResultWrapper.Success(adherence)
                }
            } else {
                ResultWrapper.Success(0f)
            }
        } catch (e: Exception) {
            logger.e(TAG, "Failed to get medication adherence", e)
            ResultWrapper.Success(0f)
        }
    }

    override suspend fun getDietData(): ResultWrapper<Map<LocalDate, Double>> {
        return try {
            if (cachedDietData == null) {
                refreshCache()
            }
            ResultWrapper.Success(cachedDietData ?: emptyMap())
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException("Failed to get diet data", e))
        }
    }

    override suspend fun getRunActivityData(): ResultWrapper<Map<LocalDate, Double>> {
        return try {
            if (cachedRunActivityData == null) {
                refreshCache()
            }
            ResultWrapper.Success(cachedRunActivityData ?: emptyMap())
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException("Failed to get run activity data", e))
        }
    }

    // ── Private helpers ──

    private suspend fun refreshCache() = coroutineScope {
        try {
            val stepsDeferred = async { fetchStepsData() }
            val hydrationDeferred = async { fetchHydrationData() }
            val dietDeferred = async { fetchDietData() }
            val runActivityDeferred = async { fetchRunActivityData() }

            cachedStepsData = stepsDeferred.await()
            cachedHydrationData = hydrationDeferred.await()
            cachedDietData = dietDeferred.await()
            cachedRunActivityData = runActivityDeferred.await()

            lastCacheTime = System.currentTimeMillis()
        } catch (e: Exception) {
            logger.e(TAG, "Failed to refresh cache", e)
        }
    }

    private suspend fun fetchStepsData(): Pair<Int, List<Pair<LocalDate, Long>>> {
        return try {
            val summary = healthConnectService.getTodaySummary()
            val weekly = healthConnectService.getWeeklyStepCounts()
            summary.steps to weekly.map { it.date to it.steps }
        } catch (e: Exception) {
            0 to emptyList()
        }
    }

    private suspend fun fetchHydrationData(): Map<LocalDate, Int> {
        return try {
            val entries = hydrationRepository.loadLocalEntries()
            entries.groupBy { parseDateFromIso(it.consumedAt.toString()) }
                .mapValues { (_, list) -> list.sumOf { it.amountMl } }
        } catch (e: Exception) {
            emptyMap()
        }
    }

    private suspend fun fetchDietData(): Map<LocalDate, Double> {
        return try {
            when (val result = dietRepository.getAllFoodEntries()) {
                is ResultWrapper.Success -> {
                    result.data.groupBy { parseDateFromIso(it.loggedAt.toString()) }
                        .mapValues { (_, list) -> list.sumOf { it.nutritionInfo.calories } }
                }
                else -> emptyMap()
            }
        } catch (e: Exception) {
            emptyMap()
        }
    }

    private suspend fun fetchRunActivityData(): Map<LocalDate, Double> {
        return try {
            val activities = runActivityRepository.loadLocalActivities()
            activities
                .filter { it.startTime != null }
                .groupBy { it.startTime!!.toLocalDate() }
                .mapValues { (_, list) -> list.sumOf { it.distanceMeters } / 1000.0 }
        } catch (e: Exception) {
            emptyMap()
        }
    }

    private fun buildSummaries(
        todaySteps: Float,
        todayCalories: Float,
        todayHeartRate: Float,
        todaySleepHours: Float,
        todayExerciseMin: Float,
        todayDistanceKm: Float,
        todayHydrationMl: Float,
        todayMedAdherence: Float,
        prevSteps: Float,
        prevHydration: Float
    ): List<MetricSummary> {
        return MetricType.entries.map { type ->
            val (current, previous) = when (type) {
                MetricType.STEPS -> todaySteps to prevSteps
                MetricType.CALORIES -> todayCalories to todayCalories
                MetricType.HEART_RATE -> todayHeartRate to todayHeartRate
                MetricType.SLEEP -> todaySleepHours to todaySleepHours
                MetricType.EXERCISE -> todayExerciseMin to todayExerciseMin
                MetricType.DISTANCE -> todayDistanceKm to todayDistanceKm
                MetricType.HYDRATION -> todayHydrationMl to prevHydration
                MetricType.MED_ADHERENCE -> todayMedAdherence to todayMedAdherence
            }
            val change = if (previous != 0f) ((current - previous) / previous * 100f) else 0f
            val trend = when {
                change > 2f -> TrendDirection.UP
                change < -2f -> TrendDirection.DOWN
                else -> TrendDirection.FLAT
            }
            MetricSummary(
                type = type,
                currentValue = current,
                previousValue = previous,
                trend = trend,
                changePercent = change
            )
        }
    }

    private suspend fun generateDayChart(metric: MetricType, today: LocalDate): List<ChartDataPoint> {
        val summary = try {
            healthConnectService.getTodaySummary()
        } catch (e: Exception) {
            return emptyList()
        }

        val totalValue = when (metric) {
            MetricType.STEPS -> summary.steps.toFloat()
            MetricType.CALORIES -> summary.activeCalories.toFloat()
            MetricType.HEART_RATE -> summary.heartRate.toFloat()
            MetricType.SLEEP -> summary.sleepMinutes / 60f
            MetricType.EXERCISE -> summary.exerciseMinutes.toFloat()
            MetricType.DISTANCE -> summary.distanceKm.toFloat()
            MetricType.HYDRATION -> (cachedHydrationData?.get(today) ?: 0).toFloat()
            MetricType.MED_ADHERENCE -> 0f // Not applicable to hourly view
        }

        return (0..23).map { hour ->
            val label = if (hour % 4 == 0) "${hour}h" else ""
            val multiplier = hourlyActivityMultiplier(hour)
            val value = when (metric) {
                MetricType.HEART_RATE -> if (summary.heartRate > 0) 60f + 20f * multiplier else 0f
                MetricType.SLEEP -> if (hour in 0..7 || hour >= 23) (summary.sleepMinutes / 60f) / 8f else 0f
                MetricType.MED_ADHERENCE -> 0f
                else -> totalValue * multiplier / HOURLY_MULTIPLIER_SUM
            }
            ChartDataPoint(label, value.coerceAtLeast(0f))
        }
    }

    private fun generateWeekChart(metric: MetricType, today: LocalDate): List<ChartDataPoint> {
        val days = (6 downTo 0).map { today.minusDays(it.toLong()) }
        val dayLabels = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

        return days.map { date ->
            val label = dayLabels[date.dayOfWeek.value - 1]
            val value = getDailyValueForMetric(metric, date)
            ChartDataPoint(label, value, date)
        }
    }

    private fun generateMonthChart(metric: MetricType, today: LocalDate): List<ChartDataPoint> {
        return (29 downTo 0).map { daysAgo ->
            val date = today.minusDays(daysAgo.toLong())
            val dayNum = date.dayOfMonth
            val label = if (dayNum % 5 == 0 || dayNum == 1) "$dayNum" else ""
            val value = getDailyValueForMetric(metric, date)
            ChartDataPoint(label, value, date)
        }
    }

    private fun getDailyValueForMetric(metric: MetricType, date: LocalDate): Float {
        val today = LocalDate.now()
        return when (metric) {
            MetricType.STEPS -> {
                if (date == today) {
                    cachedStepsData?.first?.toFloat() ?: 0f
                } else {
                    cachedStepsData?.second?.find { it.first == date }?.second?.toFloat() ?: 0f
                }
            }
            MetricType.HYDRATION -> (cachedHydrationData?.get(date) ?: 0).toFloat()
            MetricType.DISTANCE -> (cachedRunActivityData?.get(date)?.toFloat() ?: 0f)
            else -> 0f // Other metrics only have today's data
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

    private fun parseDateFromIso(dateTimeStr: String): LocalDate {
        return try {
            LocalDate.parse(dateTimeStr.take(10), DateTimeFormatter.ISO_LOCAL_DATE)
        } catch (_: Exception) {
            LocalDate.now()
        }
    }

    companion object {
        private const val TAG = "AnalyticsRepository"
        private val HOURLY_MULTIPLIER_SUM: Float = (0..23).sumOf { hour ->
            when (hour) {
                in 0..5 -> 10
                in 6..8 -> 80
                in 9..11 -> 60
                12 -> 50
                in 13..16 -> 50
                in 17..19 -> 90
                in 20..22 -> 30
                else -> 10
            }.toLong()
        }.toFloat() / 100f
    }
}
