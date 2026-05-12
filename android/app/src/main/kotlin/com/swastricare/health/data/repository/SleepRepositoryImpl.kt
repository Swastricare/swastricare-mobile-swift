package com.swastricare.health.data.repository

import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.mapper.SleepMapper
import com.swastricare.health.data.remote.dto.sleep.DailyMetricsSleepDto
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.domain.model.sleep.SleepSession
import com.swastricare.health.domain.repository.SleepRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.time.ZoneId
import javax.inject.Inject

/**
 * Implementation of SleepRepository.
 * Reads sleep data from Health Connect and syncs to Supabase daily_health_metrics.
 */
class SleepRepositoryImpl @Inject constructor(
    private val healthConnectService: HealthConnectService,
    private val supabaseClient: SupabaseClient,
    private val logger: Logger
) : SleepRepository {

    companion object {
        private const val TAG = "SleepRepository"
    }

    override suspend fun getTodaySleepSession(): ResultWrapper<SleepSession?> =
        withContext(Dispatchers.IO) {
            try {
                val detail = healthConnectService.getSleepSessionDetail()
                if (detail == null) {
                    ResultWrapper.Success(null)
                } else {
                    ResultWrapper.Success(SleepMapper.toDomain(detail))
                }
            } catch (e: Exception) {
                logger.e(TAG, "Failed to get today's sleep session", e)
                ResultWrapper.Error(AppException.UnknownException("Failed to read sleep data", e))
            }
        }

    override suspend fun getSleepSessions(
        startDate: LocalDate,
        endDate: LocalDate
    ): ResultWrapper<List<SleepSession>> = withContext(Dispatchers.IO) {
        try {
            val days = java.time.temporal.ChronoUnit.DAYS.between(startDate, endDate).toInt() + 1
            val details = healthConnectService.getSleepHistory(days)
            val sessions = details
                .filter { it.nightDate in startDate..endDate }
                .map { SleepMapper.toDomain(it) }
            ResultWrapper.Success(sessions)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to get sleep sessions", e)
            ResultWrapper.Error(AppException.UnknownException("Failed to read sleep history", e))
        }
    }

    override suspend fun getSupabaseSleepSessions(
        profileId: String,
        startDate: LocalDate,
        endDate: LocalDate
    ): ResultWrapper<List<SleepSession>> = withContext(Dispatchers.IO) {
        try {
            val rows = supabaseClient.from("daily_health_metrics").select {
                filter {
                    eq("health_profile_id", profileId)
                    gte("metric_date", startDate.toString())
                    lte("metric_date", endDate.toString())
                }
            }.decodeList<DailyMetricsSleepDto>()

            val sessions = rows.mapNotNull { SleepMapper.fromDailyMetrics(it) }
            ResultWrapper.Success(sessions)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to fetch Supabase sleep sessions", e)
            ResultWrapper.Error(AppException.UnknownException("Failed to load manual sleep entries", e))
        }
    }

    override suspend fun syncToCloud(
        session: SleepSession,
        profileId: String
    ): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            val dto = SleepMapper.toDailyMetricsDto(session, profileId)
            supabaseClient.from("daily_health_metrics").upsert(dto)
            logger.i(TAG, "Synced sleep data for ${session.date}")
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to sync sleep to cloud", e)
            ResultWrapper.Error(AppException.UnknownException("Failed to sync sleep data", e))
        }
    }

    override suspend fun saveManualSession(
        session: SleepSession,
        profileId: String
    ): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            val dto = SleepMapper.toDailyMetricsDto(session, profileId)
            supabaseClient.from("daily_health_metrics").upsert(dto)
            logger.i(TAG, "Saved manual sleep for ${session.date}")
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to save manual sleep", e)
            ResultWrapper.Error(AppException.UnknownException("Failed to save sleep", e))
        }
    }

    @Serializable
    private data class SleepHoursRow(@SerialName("sleep_hours") val sleepHours: Double? = null)

    override suspend fun getNightSleepHours(
        profileId: String,
        date: LocalDate
    ): ResultWrapper<Double?> = withContext(Dispatchers.IO) {
        try {
            val rows = supabaseClient.from("daily_health_metrics").select(
                columns = io.github.jan.supabase.postgrest.query.Columns.raw("sleep_hours")
            ) {
                filter {
                    eq("health_profile_id", profileId)
                    eq("metric_date", date.toString())
                }
                limit(1)
            }.decodeList<SleepHoursRow>()

            ResultWrapper.Success(rows.firstOrNull()?.sleepHours)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to fetch night sleep hours for profile=$profileId date=$date", e)
            ResultWrapper.Error(AppException.UnknownException("Failed to fetch sleep hours", e))
        }
    }
}
