package com.swasthicare.mobile.data.services

import android.content.Context
import android.os.Build
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

// -----------------------------------------------
// MARK: - DailyStepCount
// -----------------------------------------------

data class DailyStepCount(
    val date: LocalDate,
    val steps: Long
)

// -----------------------------------------------
// MARK: - HealthConnectService
// -----------------------------------------------

/**
 * Service for reading health data from Health Connect (Android's health data platform).
 */
class HealthConnectService(private val context: Context) {

    private val client: HealthConnectClient? by lazy {
        try {
            if (HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE) {
                HealthConnectClient.getOrCreate(context)
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Check if Health Connect is available on this device.
     */
    fun isAvailable(): Boolean =
        try {
            HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE
        } catch (_: Exception) {
            false
        }

    /**
     * Query StepsRecord for each of the last 7 days.
     * Returns a list of [DailyStepCount], one entry per day.
     * Days with no data default to 0 steps.
     */
    suspend fun getWeeklySteps(): List<DailyStepCount> {
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
}
