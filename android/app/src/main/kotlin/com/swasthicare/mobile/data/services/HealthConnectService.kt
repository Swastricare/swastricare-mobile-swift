package com.swasthicare.mobile.data.services

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.*
import java.time.temporal.ChronoUnit

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
class HealthConnectService(private val context: Context) {

    companion object {
        private const val TAG = "HealthConnectService"

        // All required permissions
        val READ_PERMISSIONS = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(HeartRateRecord::class),
            HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(SleepSessionRecord::class),
            HealthPermission.getReadPermission(DistanceRecord::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
            HealthPermission.getReadPermission(BloodPressureRecord::class),
            HealthPermission.getReadPermission(WeightRecord::class),
            HealthPermission.getReadPermission(HeightRecord::class)
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
    fun isAvailable(): Boolean =
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

    // ── READ: Today's Summary ──

    suspend fun getTodaySummary(): DailyHealthSummary = withContext(Dispatchers.IO) {
        val hc = client ?: return@withContext DailyHealthSummary()

        val now = Instant.now()
        val startOfDay = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()
        val todayFilter = TimeRangeFilter.between(startOfDay, now)

        var steps = 0
        var heartRate = 0
        var activeCal = 0
        var totalCal = 0
        var sleepMin = 0
        var distanceKm = 0.0
        var exerciseMin = 0
        var standHours = 0
        var systolic = 0
        var diastolic = 0
        var weightKg = 0.0
        var heightCm = 0.0

        try {
            // Steps
            val stepsRecords = hc.readRecords(ReadRecordsRequest(StepsRecord::class, todayFilter))
            steps = stepsRecords.records.sumOf { it.count }.toInt()

            // Heart Rate (latest)
            val hrRecords = hc.readRecords(ReadRecordsRequest(HeartRateRecord::class, todayFilter))
            heartRate = hrRecords.records.lastOrNull()?.samples?.lastOrNull()?.beatsPerMinute?.toInt() ?: 0

            // Active Calories
            val activeCalRecords = hc.readRecords(ReadRecordsRequest(ActiveCaloriesBurnedRecord::class, todayFilter))
            activeCal = activeCalRecords.records.sumOf { it.energy.inKilocalories }.toInt()

            // Total Calories
            val totalCalRecords = hc.readRecords(ReadRecordsRequest(TotalCaloriesBurnedRecord::class, todayFilter))
            totalCal = totalCalRecords.records.sumOf { it.energy.inKilocalories }.toInt()
        } catch (e: Exception) {
            Log.w(TAG, "Error reading basic metrics: ${e.message}")
        }

        try {
            // Sleep (look at last night: 6pm yesterday to now)
            sleepMin = getTodaySleep()
        } catch (e: Exception) {
            Log.w(TAG, "Error reading sleep: ${e.message}")
        }

        try {
            // Distance
            distanceKm = getTodayDistance()
        } catch (e: Exception) {
            Log.w(TAG, "Error reading distance: ${e.message}")
        }

        try {
            // Exercise Minutes
            exerciseMin = getTodayExercise()
        } catch (e: Exception) {
            Log.w(TAG, "Error reading exercise: ${e.message}")
        }

        try {
            // Estimate stand hours from activity (if steps > 250 in an hour, count as standing)
            standHours = estimateStandHours()
        } catch (e: Exception) {
            Log.w(TAG, "Error estimating stand hours: ${e.message}")
        }

        try {
            // Blood Pressure (latest)
            val bp = getLatestBloodPressure()
            systolic = bp.first
            diastolic = bp.second
        } catch (e: Exception) {
            Log.w(TAG, "Error reading blood pressure: ${e.message}")
        }

        try {
            // Weight (latest)
            weightKg = getLatestWeight()
        } catch (e: Exception) {
            Log.w(TAG, "Error reading weight: ${e.message}")
        }

        try {
            // Height (latest)
            heightCm = getLatestHeight()
        } catch (e: Exception) {
            Log.w(TAG, "Error reading height: ${e.message}")
        }

        DailyHealthSummary(
            steps = steps,
            heartRate = heartRate,
            activeCalories = activeCal,
            totalCalories = totalCal,
            sleepMinutes = sleepMin,
            distanceKm = distanceKm,
            exerciseMinutes = exerciseMin,
            standHours = standHours,
            systolic = systolic,
            diastolic = diastolic,
            weightKg = weightKg,
            heightCm = heightCm
        )
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
            emptyList()
        }
    }

    /**
     * Query StepsRecord for each of the last 7 days.
     * Returns a list of [DailyStepCount], one entry per day.
     * Days with no data default to 0 steps.
     */
    suspend fun getWeeklyStepCounts(): List<DailyStepCount> {
        val healthClient = client ?: return generateFallbackWeeklySteps()

        val zone = ZoneId.systemDefault()
        val today = LocalDate.now()
        val result = mutableListOf<DailyStepCount>()

        for (dayOffset in 6 downTo 0) {
            val date = today.minusDays(dayOffset.toLong())
            val startOfDay = date.atStartOfDay(zone).toInstant()
            val endOfDay = date.plusDays(1).atStartOfDay(zone).toInstant()

            val steps = try {
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

            result.add(DailyStepCount(date = date, steps = steps))
        }

        return result
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

    private suspend fun estimateStandHours(): Int = withContext(Dispatchers.IO) {
        val hc = client ?: return@withContext 0
        val today = LocalDate.now()
        var standCount = 0

        try {
            for (hour in 6..22) { // 6am to 10pm
                val hourStart = today.atTime(hour, 0).atZone(ZoneId.systemDefault()).toInstant()
                val hourEnd = today.atTime(hour, 59, 59).atZone(ZoneId.systemDefault()).toInstant()
                if (hourEnd.isAfter(Instant.now())) break

                val filter = TimeRangeFilter.between(hourStart, hourEnd)
                val records = hc.readRecords(ReadRecordsRequest(StepsRecord::class, filter))
                val hourSteps = records.records.sumOf { it.count }.toInt()
                if (hourSteps >= 100) standCount++ // 100 steps in an hour = standing
            }
        } catch (e: Exception) {
            Log.w(TAG, "estimateStandHours failed: ${e.message}")
        }
        standCount
    }

    // ── WRITE Functions ──

    /** Write a heart rate measurement (e.g., after camera PPG). */
    suspend fun writeHeartRate(bpm: Long, time: Instant = Instant.now()): Boolean =
        withContext(Dispatchers.IO) {
            val hc = client ?: return@withContext false
            try {
                val record = HeartRateRecord(
                    startTime = time.minusSeconds(1),
                    endTime = time,
                    startZoneOffset = ZoneOffset.systemDefault().rules.getOffset(time),
                    endZoneOffset = ZoneOffset.systemDefault().rules.getOffset(time),
                    samples = listOf(
                        HeartRateRecord.Sample(time = time, beatsPerMinute = bpm)
                    )
                )
                hc.insertRecords(listOf(record))
                true
            } catch (e: Exception) {
                Log.e(TAG, "writeHeartRate failed: ${e.message}")
                false
            }
        }

    /** Write hydration (water intake in ml). */
    suspend fun writeHydration(volumeMl: Double, time: Instant = Instant.now()): Boolean =
        withContext(Dispatchers.IO) {
            val hc = client ?: return@withContext false
            try {
                val record = HydrationRecord(
                    startTime = time.minusSeconds(1),
                    endTime = time,
                    startZoneOffset = ZoneOffset.systemDefault().rules.getOffset(time),
                    endZoneOffset = ZoneOffset.systemDefault().rules.getOffset(time),
                    volume = Volume.liters(volumeMl / 1000.0)
                )
                hc.insertRecords(listOf(record))
                true
            } catch (e: Exception) {
                Log.e(TAG, "writeHydration failed: ${e.message}")
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
        try {
            val record = ExerciseSessionRecord(
                startTime = startTime,
                endTime = endTime,
                startZoneOffset = ZoneOffset.systemDefault().rules.getOffset(startTime),
                endZoneOffset = ZoneOffset.systemDefault().rules.getOffset(endTime),
                exerciseType = exerciseType,
                title = title
            )
            hc.insertRecords(listOf(record))
            true
        } catch (e: Exception) {
            Log.e(TAG, "writeExerciseSession failed: ${e.message}")
            false
        }
    }
}
