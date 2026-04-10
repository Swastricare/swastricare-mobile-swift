package com.swastricare.health.domain.repository

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.sleep.SleepSession
import java.time.LocalDate

/**
 * Repository contract for sleep data.
 * Reads from Health Connect and syncs to Supabase.
 */
interface SleepRepository {

    /**
     * Get last night's sleep session with stage breakdown.
     */
    suspend fun getTodaySleepSession(): ResultWrapper<SleepSession?>

    /**
     * Get sleep sessions for a date range.
     */
    suspend fun getSleepSessions(startDate: LocalDate, endDate: LocalDate): ResultWrapper<List<SleepSession>>

    /**
     * Sync a sleep session to Supabase daily_health_metrics.
     */
    suspend fun syncToCloud(session: SleepSession, profileId: String): ResultWrapper<Unit>
}
