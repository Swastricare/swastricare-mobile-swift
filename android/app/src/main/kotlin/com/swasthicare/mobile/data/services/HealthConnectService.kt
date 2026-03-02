package com.swasthicare.mobile.data.services

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

data class DailyHealthSummary(
    val steps: Int = 0,
    val heartRate: Int = 0,
    val activeCalories: Int = 0,
    val totalCalories: Int = 0
)

class HealthConnectService(private val context: Context) {

    val client: HealthConnectClient? by lazy {
        if (HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE) {
            HealthConnectClient.getOrCreate(context)
        } else null
    }

    val isAvailable: Boolean get() = client != null

    val requiredPermissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class)
    )

    suspend fun hasPermissions(): Boolean {
        val client = client ?: return false
        val granted = client.permissionController.getGrantedPermissions()
        return granted.containsAll(requiredPermissions)
    }

    suspend fun getTodaySummary(): DailyHealthSummary {
        val client = client ?: return DailyHealthSummary()
        if (!hasPermissions()) return DailyHealthSummary()

        val startOfDay = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()
        val now = Instant.now()
        val range = TimeRangeFilter.between(startOfDay, now)

        val steps = try {
            client.readRecords(ReadRecordsRequest(StepsRecord::class, range))
                .records.sumOf { it.count }.toInt()
        } catch (e: Exception) { 0 }

        val heartRate = try {
            client.readRecords(ReadRecordsRequest(HeartRateRecord::class, range))
                .records.lastOrNull()?.samples?.lastOrNull()?.beatsPerMinute?.toInt() ?: 0
        } catch (e: Exception) { 0 }

        val activeCalories = try {
            client.readRecords(ReadRecordsRequest(ActiveCaloriesBurnedRecord::class, range))
                .records.sumOf { it.energy.inKilocalories }.toInt()
        } catch (e: Exception) { 0 }

        val totalCalories = try {
            client.readRecords(ReadRecordsRequest(TotalCaloriesBurnedRecord::class, range))
                .records.sumOf { it.energy.inKilocalories }.toInt()
        } catch (e: Exception) { 0 }

        return DailyHealthSummary(steps, heartRate, activeCalories, totalCalories)
    }
}
