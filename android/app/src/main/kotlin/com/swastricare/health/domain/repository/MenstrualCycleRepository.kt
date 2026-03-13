package com.swastricare.health.domain.repository

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.menstrualcycle.*
import java.time.LocalDate

/**
 * Repository interface for menstrual cycle data management.
 * Handles cycles, daily logs, predictions, and settings.
 */
interface MenstrualCycleRepository {

    // ── Cycle Management ──

    /**
     * Retrieves all cycle records for the user.
     */
    suspend fun getCycles(): ResultWrapper<List<CycleRecord>>

    /**
     * Starts a new menstrual cycle.
     * @param startDate The date the period began
     * @param notes Optional notes
     */
    suspend fun startCycle(
        startDate: LocalDate,
        notes: String? = null
    ): ResultWrapper<CycleRecord>

    /**
     * Ends the current active cycle.
     * @param endDate The date the period ended
     */
    suspend fun endCycle(
        cycleId: String,
        endDate: LocalDate
    ): ResultWrapper<CycleRecord>

    /**
     * Deletes a cycle record.
     */
    suspend fun deleteCycle(cycleId: String): ResultWrapper<Unit>

    // ── Daily Logs ──

    /**
     * Retrieves daily logs for a specific date range.
     */
    suspend fun getDailyLogs(
        startDate: LocalDate,
        endDate: LocalDate
    ): ResultWrapper<List<DailyLog>>

    /**
     * Logs daily cycle data (flow, symptoms, mood, pain).
     */
    suspend fun logDailyData(
        date: LocalDate,
        flowLevel: FlowLevel,
        symptoms: List<Symptom>,
        mood: Mood?,
        notes: String?,
        painLevel: Int
    ): ResultWrapper<DailyLog>

    /**
     * Updates an existing daily log.
     */
    suspend fun updateDailyLog(log: DailyLog): ResultWrapper<DailyLog>

    /**
     * Deletes a daily log.
     */
    suspend fun deleteDailyLog(logId: String): ResultWrapper<Unit>

    // ── Settings ──

    /**
     * Retrieves user's cycle settings.
     */
    suspend fun getSettings(): ResultWrapper<CycleSettings>

    /**
     * Updates cycle settings.
     */
    suspend fun updateSettings(settings: CycleSettings): ResultWrapper<CycleSettings>

    // ── Predictions & Insights ──

    /**
     * Calculates next period prediction based on cycle history.
     */
    suspend fun getPrediction(): ResultWrapper<CyclePrediction?>

    /**
     * Calculates cycle statistics and insights.
     */
    suspend fun getStatistics(): ResultWrapper<CycleStatistics>

    /**
     * Detects the current cycle phase based on history.
     */
    suspend fun getCurrentPhase(): ResultWrapper<CyclePhase>

    /**
     * Generates calendar data for a specific month.
     * Combines logged data with predictions.
     */
    suspend fun getCalendarData(month: LocalDate): ResultWrapper<List<CalendarDayData>>

    // ── Sync ──

    /**
     * Syncs local data with cloud backend.
     */
    suspend fun syncData(): ResultWrapper<Unit>
}
