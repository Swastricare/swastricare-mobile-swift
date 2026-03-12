package com.swastricare.health.data.services

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import java.time.*
import java.time.temporal.ChronoUnit
import kotlin.reflect.KClass

// -----------------------------------------------
// MARK: - DailyStepCount (used by weekly steps chart)
// -----------------------------------------------

data class DailyStepCount(
    val date: LocalDate,
    val steps: Long
)

/**
 * Health Connect Service — Expanded to match iOS HealthKit coverage.
 *
 * READ permissions:
 *   StepsRecord, HeartRateRecord, ActiveCaloriesBurnedRecord, TotalCaloriesBurnedRecord,
 *   SleepSessionRecord, DistanceRecord, ExerciseSessionRecord,
 *   BloodPressureRecord, WeightRecord, HeightRecord
 *
 * WRITE permissions:
 *   HeartRateRecord, HydrationRecord, ExerciseSessionRecord
 */
class HealthConnectService(
    private val context: Context,
    private val crashlyticsService: CrashlyticsService
) {

    companion object {
        private const val TAG = "HealthConnectService"

        // Core permissions needed for home screen - used for permission checks
        val CORE_READ_PERMISSIONS = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(HeartRateRecord::class),
            HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(SleepSessionRecord::class),
            HealthPermission.getReadPermission(DistanceRecord::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        )

        // All required permissions (includes optional ones)
        val READ_PERMISSIONS = CORE_READ_PERMISSIONS + setOf(
            HealthPermission.getReadPermission(BloodPressureRecord::class),
            HealthPermission.getReadPermission(WeightRecord::class),
            HealthPermission.getReadPermission(HeightRecord::class),
            HealthPermission.getReadPermission(Vo2MaxRecord::class)
        )

        val WRITE_PERMISSIONS = setOf(
            HealthPermission.getWritePermission(HeartRateRecord::class),
            HealthPermission.getWritePermission(HydrationRecord::class),
            HealthPermission.getWritePermission(ExerciseSessionRecord::class)
        )

        val ALL_PERMISSIONS = READ_PERMISSIONS + WRITE_PERMISSIONS
    }

    // ── Data Models ──

    data class DailyHealthSummary(
        val steps: Int = 0,
        val heartRate: Int = 0,
        val activeCalories: Int = 0,
        val totalCalories: Int = 0,
        val sleepMinutes: Int = 0,
        val distanceKm: Double = 0.0,
        val exerciseMinutes: Int = 0,
        val standHours: Int = 0,
        val systolic: Int = 0,
        val diastolic: Int = 0,
        val weightKg: Double = 0.0,
        val heightCm: Double = 0.0
    ) {
        val sleepFormatted: String
            get() {
                if (sleepMinutes <= 0) return "--"
                val hours = sleepMinutes / 60
                val mins = sleepMinutes % 60
                return "${hours}h ${mins}m"
            }

        val bloodPressureFormatted: String
            get() = if (systolic > 0 && diastolic > 0) "$systolic/$diastolic" else "--/--"
    }

    data class DailyStepEntry(
        val date: LocalDate,
        val steps: Int,
        val dayName: String
    )

    // ── Cache ──

    private var cachedSummary: DailyHealthSummary? = null
    private var cacheTimestamp: Long = 0L

    // ── Client ──

    private val client: HealthConnectClient? by lazy {
        try {
            if (HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE) {
                HealthConnectClient.getOrCreate(context)
            } else null
        } catch (e: Exception) {
            Log.w(TAG, "Health Connect unavailable: ${e.message}")
            null
        }
    }

    val isAvailable: Boolean
        get() = client != null

    /**
     * Check if Health Connect is available on this device (function form).
     */
    fun checkAvailability(): Boolean =
        try {
            HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE
        } catch (_: Exception) {
            false
        }

    // ── Permissions ──

    suspend fun hasAllPermissions(): Boolean = withContext(Dispatchers.IO) {
        try {
            val granted = client?.permissionController?.getGrantedPermissions() ?: return@withContext false
            ALL_PERMISSIONS.all { it in granted }
        } catch (e: Exception) {
            Log.w(TAG, "Permission check failed: ${e.message}")
            false
        }
    }

    /** Returns true if the core read permissions needed to display home vitals are granted. */
    suspend fun hasReadPermissions(): Boolean = withContext(Dispatchers.IO) {
        try {
            val granted = client?.permissionController?.getGrantedPermissions() ?: return@withContext false
            CORE_READ_PERMISSIONS.all { it in granted }
        } catch (e: Exception) {
            Log.w(TAG, "Read permission check failed: ${e.message}")
            false
        }
    }

    suspend fun getGrantedPermissions(): Set<String> = withContext(Dispatchers.IO) {
        try {
            client?.permissionController?.getGrantedPermissions() ?: emptySet()
        } catch (e: Exception) {
            Log.w(TAG, "getGrantedPermissions failed: ${e.message}")
            emptySet()
        }
    }

    private suspend fun hasWritePermission(recordClass: KClass<out Record>): Boolean {
        return try {
            val granted = client?.permissionController?.getGrantedPermissions() ?: return false
            HealthPermission.getWritePermission(recordClass) in granted
        } catch (e: Exception) {
            false
        }
    }

    fun invalidateCache() {
        cachedSummary = null
        cacheTimestamp = 0L
    }

    // ── READ: Today's Summary (cached for 60 seconds) ──

    suspend fun getTodaySummary(): DailyHealthSummary {
        val now = System.currentTimeMillis()
        cachedSummary?.let { cached ->
            if (now - cacheTimestamp < 60_000) return cached
        }
        val summary = fetchTodaySummary()
        cachedSummary = summary
        cacheTimestamp = now
        return summary
    }

    private suspend fun fetchTodaySummary(): DailyHealthSummary = withContext(Dispatchers.IO) {
        val hc = client ?: return@withContext DailyHealthSummary()

        val now = Instant.now()
        val startOfDay = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()
        val todayFilter = TimeRangeFilter.between(startOfDay, now)

        coroutineScope {
            val stepsDeferred = async {
                try {
                    val records = hc.readRecords(ReadRecordsRequest(StepsRecord::class, todayFilter))
                    records.records.sumOf { it.count }.toInt()
                } catch (e: Exception) {
                    Log.w(TAG, "Error reading steps: ${e.message}")
                    crashlyticsService.recordException(e)
                    0
                }
            }

            val hrDeferred = async {
                try {
                    val records = hc.readRecords(ReadRecordsRequest(HeartRateRecord::class, todayFilter))
                    records.records.lastOrNull()?.samples?.lastOrNull()?.beatsPerMinute?.toInt() ?: 0
                } catch (e: Exception) {
                    Log.w(TAG, "Error reading heart rate: ${e.message}")
                    crashlyticsService.recordException(e)
                    0
                }
            }

            val activeCalDeferred = async {
                try {
                    val records = hc.readRecords(ReadRecordsRequest(ActiveCaloriesBurnedRecord::class, todayFilter))
                    records.records.sumOf { it.energy.inKilocalories }.toInt()
                } catch (e: Exception) {
                    Log.w(TAG, "Error reading active calories: ${e.message}")
                    crashlyticsService.recordException(e)
                    0
                }
            }

            val totalCalDeferred = async {
                try {
                    val records = hc.readRecords(ReadRecordsRequest(TotalCaloriesBurnedRecord::class, todayFilter))
                    records.records.sumOf { it.energy.inKilocalories }.toInt()
                } catch (e: Exception) {
                    Log.w(TAG, "Error reading total calories: ${e.message}")
                    crashlyticsService.recordException(e)
                    0
                }
            }

            val sleepDeferred = async {
                try { getTodaySleep() } catch (e: Exception) {
                    Log.w(TAG, "Error reading sleep: ${e.message}")
                    crashlyticsService.recordException(e)
                    0
                }
            }

            val distDeferred = async {
                try { getTodayDistance() } catch (e: Exception) {
                    Log.w(TAG, "Error reading distance: ${e.message}")
                    crashlyticsService.recordException(e)
                    0.0
                }
            }

            val exerciseDeferred = async {
                try { getTodayExercise() } catch (e: Exception) {
                    Log.w(TAG, "Error reading exercise: ${e.message}")
                    crashlyticsService.recordException(e)
                    0
                }
            }

            val standDeferred = async {
                try { estimateStandHours() } catch (e: Exception) {
                    Log.w(TAG, "Error estimating stand hours: ${e.message}")
                    crashlyticsService.recordException(e)
                    0
                }
            }

            val bpDeferred = async {
                try { getLatestBloodPressure() } catch (e: Exception) {
                    Log.w(TAG, "Error reading blood pressure: ${e.message}")
                    crashlyticsService.recordException(e)
                    Pair(0, 0)
                }
            }

            val weightDeferred = async {
                try { getLatestWeight() } catch (e: Exception) {
                    Log.w(TAG, "Error reading weight: ${e.message}")
                    crashlyticsService.recordException(e)
                    0.0
                }
            }

            val heightDeferred = async {
                try { getLatestHeight() } catch (e: Exception) {
                    Log.w(TAG, "Error reading height: ${e.message}")
                    crashlyticsService.recordException(e)
                    0.0
                }
            }

            val steps = stepsDeferred.await()
            val heartRate = hrDeferred.await()
            val activeCal = activeCalDeferred.await()
            val totalCal = totalCalDeferred.await()
            val sleepMin = sleepDeferred.await()
            val distanceKm = distDeferred.await()
            val exerciseMin = exerciseDeferred.await()
            val standHours = standDeferred.await()
            val bp = bpDeferred.await()
            val weightKg = weightDeferred.await()
            val heightCm = heightDeferred.await()

            // Google Fit only writes TotalCaloriesBurnedRecord (not ActiveCaloriesBurnedRecord).
            // Fall back to totalCal when activeCal is unavailable so the home screen shows a value.
            val displayCalories = if (activeCal > 0) activeCal else totalCal

            DailyHealthSummary(
                steps = steps,
                heartRate = heartRate,
                activeCalories = displayCalories,
                totalCalories = totalCal,
                sleepMinutes = sleepMin,
                distanceKm = distanceKm,
                exerciseMinutes = exerciseMin,
                standHours = standHours,
                systolic = bp.first,
                diastolic = bp.second,
                weightKg = weightKg,
                heightCm = heightCm
            )
        }
    }

    // ── READ: Individual Metrics ──

    /** Reads SleepSessionRecord for last night (6pm yesterday -> now) and returns total minutes. */
    suspend fun getTodaySleep(): Int = withContext(Dispatchers.IO) {
        val hc = client ?: return@withContext 0
        val now = Instant.now()
        val yesterday6pm = LocalDate.now().minusDays(1).atTime(18, 0)
            .atZone(ZoneId.systemDefault()).toInstant()
        val filter = TimeRangeFilter.between(yesterday6pm, now)

        try {
            val records = hc.readRecords(ReadRecordsRequest(SleepSessionRecord::class, filter))
            records.records.sumOf {
                ChronoUnit.MINUTES.between(it.startTime, it.endTime)
            }.toInt()
        } catch (e: Exception) {
            Log.w(TAG, "getTodaySleep failed: ${e.message}")
            crashlyticsService.recordException(e)
            0
        }
    }

    /** Reads DistanceRecord for today and returns total km. */
    suspend fun getTodayDistance(): Double = withContext(Dispatchers.IO) {
        val hc = client ?: return@withContext 0.0
        val now = Instant.now()
        val startOfDay = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()
        val filter = TimeRangeFilter.between(startOfDay, now)

        try {
            val records = hc.readRecords(ReadRecordsRequest(DistanceRecord::class, filter))
            records.records.sumOf { it.distance.inKilometers }
        } catch (e: Exception) {
            Log.w(TAG, "getTodayDistance failed: ${e.message}")
            crashlyticsService.recordException(e)
            0.0
        }
    }

    /** Reads ExerciseSessionRecord for today and returns total minutes. */
    suspend fun getTodayExercise(): Int = withContext(Dispatchers.IO) {
        val hc = client ?: return@withContext 0
        val now = Instant.now()
        val startOfDay = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()
        val filter = TimeRangeFilter.between(startOfDay, now)

        try {
            val records = hc.readRecords(ReadRecordsRequest(ExerciseSessionRecord::class, filter))
            records.records.sumOf {
                ChronoUnit.MINUTES.between(it.startTime, it.endTime)
            }.toInt()
        } catch (e: Exception) {
            Log.w(TAG, "getTodayExercise failed: ${e.message}")
            crashlyticsService.recordException(e)
            0
        }
    }

    /** Reads most recent WeightRecord from the last 30 days. Returns kg or 0.0. */
    suspend fun getLatestWeight(): Double = withContext(Dispatchers.IO) {
        val hc = client ?: return@withContext 0.0
        val now = Instant.now()
        val thirtyDaysAgo = now.minus(30, ChronoUnit.DAYS)
        val filter = TimeRangeFilter.between(thirtyDaysAgo, now)

        try {
            val records = hc.readRecords(ReadRecordsRequest(WeightRecord::class, filter))
            records.records.lastOrNull()?.weight?.inKilograms ?: 0.0
        } catch (e: Exception) {
            Log.w(TAG, "getLatestWeight failed: ${e.message}")
            crashlyticsService.recordException(e)
            0.0
        }
    }

    /** Reads most recent HeightRecord. Returns cm or 0.0. */
    private suspend fun getLatestHeight(): Double = withContext(Dispatchers.IO) {
        val hc = client ?: return@withContext 0.0
        val now = Instant.now()
        val yearAgo = now.minus(365, ChronoUnit.DAYS)
        val filter = TimeRangeFilter.between(yearAgo, now)

        try {
            val records = hc.readRecords(ReadRecordsRequest(HeightRecord::class, filter))
            val meters = records.records.lastOrNull()?.height?.inMeters ?: 0.0
            meters * 100.0
        } catch (e: Exception) {
            Log.w(TAG, "getLatestHeight failed: ${e.message}")
            crashlyticsService.recordException(e)
            0.0
        }
    }

    /** Reads most recent BloodPressureRecord. Returns Pair(systolic, diastolic). */
    suspend fun getLatestBloodPressure(): Pair<Int, Int> = withContext(Dispatchers.IO) {
        val hc = client ?: return@withContext Pair(0, 0)
        val now = Instant.now()
        val sevenDaysAgo = now.minus(7, ChronoUnit.DAYS)
        val filter = TimeRangeFilter.between(sevenDaysAgo, now)

        try {
            val records = hc.readRecords(ReadRecordsRequest(BloodPressureRecord::class, filter))
            val latest = records.records.lastOrNull()
            if (latest != null) {
                Pair(
                    latest.systolic.inMillimetersOfMercury.toInt(),
                    latest.diastolic.inMillimetersOfMercury.toInt()
                )
            } else Pair(0, 0)
        } catch (e: Exception) {
            Log.w(TAG, "getLatestBloodPressure failed: ${e.message}")
            crashlyticsService.recordException(e)
            Pair(0, 0)
        }
    }

    /** Reads last 7 days of StepsRecord for the weekly chart (returns DailyStepEntry). */
    suspend fun getWeeklySteps(): List<DailyStepEntry> = withContext(Dispatchers.IO) {
        val hc = client ?: return@withContext emptyList()
        val today = LocalDate.now()
        val weekAgo = today.minusDays(6)

        try {
            val filter = TimeRangeFilter.between(
                weekAgo.atStartOfDay(ZoneId.systemDefault()).toInstant(),
                today.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()
            )
            val records = hc.readRecords(ReadRecordsRequest(StepsRecord::class, filter))

            // Group by day
            val dayFormatter = java.time.format.DateTimeFormatter.ofPattern("EEE")
            val stepsByDay = mutableMapOf<LocalDate, Int>()

            for (record in records.records) {
                val recordDate = record.startTime.atZone(ZoneId.systemDefault()).toLocalDate()
                stepsByDay[recordDate] = (stepsByDay[recordDate] ?: 0) + record.count.toInt()
            }

            // Build entries for last 7 days
            (0..6).map { offset ->
                val date = weekAgo.plusDays(offset.toLong())
                DailyStepEntry(
                    date = date,
                    steps = stepsByDay[date] ?: 0,
                    dayName = date.format(dayFormatter)
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "getWeeklySteps failed: ${e.message}")
            crashlyticsService.recordException(e)
            emptyList()
        }
    }

    /**
     * Query StepsRecord for the last 7 days using a SINGLE Health Connect query,
     * then group by day in memory.
     * Returns a list of [DailyStepCount], one entry per day.
     * Days with no data default to 0 steps.
     */
    suspend fun getWeeklyStepCounts(): List<DailyStepCount> = withContext(Dispatchers.IO) {
        val healthClient = client ?: return@withContext generateFallbackWeeklySteps()

        val zone = ZoneId.systemDefault()
        val today = LocalDate.now()
        val weekAgo = today.minusDays(6)

        try {
            val records = healthClient.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        weekAgo.atStartOfDay(zone).toInstant(),
                        today.plusDays(1).atStartOfDay(zone).toInstant()
                    )
                )
            ).records

            (0..6).map { daysAgo ->
                val date = today.minusDays(daysAgo.toLong())
                val dayStart = date.atStartOfDay(zone).toInstant()
                val dayEnd = date.plusDays(1).atStartOfDay(zone).toInstant()
                val steps = records.filter { it.startTime >= dayStart && it.startTime < dayEnd }
                    .sumOf { it.count }
                DailyStepCount(date = date, steps = steps)
            }.reversed()
        } catch (_: Exception) {
            generateFallbackWeeklySteps()
        }
    }

    /**
     * Get today's step count from Health Connect.
     */
    suspend fun getTodaySteps(): Long {
        val healthClient = client ?: return 0L

        val zone = ZoneId.systemDefault()
        val today = LocalDate.now()
        val startOfDay = today.atStartOfDay(zone).toInstant()
        val endOfDay = today.plusDays(1).atStartOfDay(zone).toInstant()

        return try {
            val response = healthClient.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(startOfDay, endOfDay)
                )
            )
            response.records.sumOf { it.count }
        } catch (_: Exception) {
            0L
        }
    }

    /**
     * Fallback data when Health Connect is not available.
     * Returns sample data so the UI is not empty.
     */
    private fun generateFallbackWeeklySteps(): List<DailyStepCount> {
        val today = LocalDate.now()
        val sampleSteps = listOf(6500L, 8200L, 7800L, 9100L, 8432L, 5600L, 4200L)
        return (6 downTo 0).mapIndexed { index, dayOffset ->
            DailyStepCount(
                date = today.minusDays(dayOffset.toLong()),
                steps = sampleSteps.getOrElse(index) { 0L }
            )
        }
    }

    // ── Estimate Stand Hours ──

    /**
     * Estimate stand hours using a SINGLE Health Connect query for all StepsRecords
     * from 6am-10pm, then group by hour in memory.
     * An hour counts as "standing" if it has at least one overlapping step record with count > 0.
     */
    private suspend fun estimateStandHours(): Int = withContext(Dispatchers.IO) {
        val hc = client ?: return@withContext 0
        try {
            val today = LocalDate.now()
            val zone = ZoneId.systemDefault()
            val now = Instant.now()
            val startOfRange = today.atTime(6, 0).atZone(zone).toInstant()
            val endOfRange = today.atTime(22, 0).atZone(zone).toInstant()

            // Clamp the end to current time so we don't query the future
            val effectiveEnd = if (now.isBefore(endOfRange)) now else endOfRange
            if (effectiveEnd.isBefore(startOfRange) || effectiveEnd == startOfRange) return@withContext 0

            val records = hc.readRecords(
                ReadRecordsRequest(
                    StepsRecord::class,
                    TimeRangeFilter.between(startOfRange, effectiveEnd)
                )
            ).records

            // Count hours (6..21) that have meaningful movement (>= 250 steps per hour)
            (6..21).count { hour ->
                val hourStart = today.atTime(hour, 0).atZone(zone).toInstant()
                val hourEnd = today.atTime(hour + 1, 0).atZone(zone).toInstant()
                // Only count completed hours (or current hour up to now)
                if (hourStart.isAfter(now)) return@count false
                records.filter { record ->
                    record.startTime < hourEnd && record.endTime > hourStart
                }.sumOf { it.count } >= 250
            }
        } catch (e: Exception) {
            Log.w(TAG, "estimateStandHours failed: ${e.message}")
            crashlyticsService.recordException(e)
            0
        }
    }

    /** Reads the most recent Vo2MaxRecord from the last 90 days. Returns ml/min/kg or null. */
    suspend fun getVo2Max(): Double? {
        return try {
            val hc = client ?: return null
            val now = java.time.Instant.now()
            val response = hc.readRecords(
                ReadRecordsRequest(
                    recordType = Vo2MaxRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        now.minus(90, ChronoUnit.DAYS),
                        now
                    )
                )
            )
            response.records.maxByOrNull { it.time }?.vo2MillilitersPerMinuteKilogram
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read VO2Max: ${e.message}")
            null
        }
    }

    // ── WRITE Functions ──

    /** Write a heart rate measurement (e.g., after camera PPG). */
    suspend fun writeHeartRate(bpm: Long, time: Instant = Instant.now()): Boolean =
        withContext(Dispatchers.IO) {
            val hc = client ?: return@withContext false
            if (!hasWritePermission(HeartRateRecord::class)) return@withContext false
            try {
                val record = HeartRateRecord(
                    startTime = time.minusSeconds(1),
                    endTime = time,
                    startZoneOffset = ZoneId.systemDefault().rules.getOffset(time),
                    endZoneOffset = ZoneId.systemDefault().rules.getOffset(time),
                    samples = listOf(
                        HeartRateRecord.Sample(time = time, beatsPerMinute = bpm)
                    )
                )
                hc.insertRecords(listOf(record))
                true
            } catch (e: Exception) {
                Log.e(TAG, "writeHeartRate failed: ${e.message}")
                crashlyticsService.recordException(e)
                false
            }
        }

    /** Write hydration (water intake in ml). */
    suspend fun writeHydration(volumeMl: Double, time: Instant = Instant.now()): Boolean =
        withContext(Dispatchers.IO) {
            val hc = client ?: return@withContext false
            if (!hasWritePermission(HydrationRecord::class)) return@withContext false
            try {
                val record = HydrationRecord(
                    startTime = time.minusSeconds(1),
                    endTime = time,
                    startZoneOffset = ZoneId.systemDefault().rules.getOffset(time),
                    endZoneOffset = ZoneId.systemDefault().rules.getOffset(time),
                    volume = Volume.liters(volumeMl / 1000.0)
                )
                hc.insertRecords(listOf(record))
                true
            } catch (e: Exception) {
                Log.e(TAG, "writeHydration failed: ${e.message}")
                crashlyticsService.recordException(e)
                false
            }
        }

    /** Write an exercise session. */
    suspend fun writeExerciseSession(
        exerciseType: Int = ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT,
        startTime: Instant,
        endTime: Instant,
        title: String? = null
    ): Boolean = withContext(Dispatchers.IO) {
        val hc = client ?: return@withContext false
        if (!hasWritePermission(ExerciseSessionRecord::class)) return@withContext false
        try {
            val record = ExerciseSessionRecord(
                startTime = startTime,
                endTime = endTime,
                startZoneOffset = ZoneId.systemDefault().rules.getOffset(startTime),
                endZoneOffset = ZoneId.systemDefault().rules.getOffset(endTime),
                exerciseType = exerciseType,
                title = title
            )
            hc.insertRecords(listOf(record))
            true
        } catch (e: Exception) {
            Log.e(TAG, "writeExerciseSession failed: ${e.message}")
            crashlyticsService.recordException(e)
            false
        }
    }
}
