package com.swastricare.health.domain.repository

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.HeartRateSnapshot
import com.swastricare.health.domain.model.heartrate.HeartRateMeasurement
import kotlinx.coroutines.flow.Flow
import java.time.LocalDate

/**
 * Repository contract for heart rate data.
 * Handles local storage and cloud sync of heart rate measurements.
 */
interface HeartRateRepository {

    // ── Local storage ──

    /**
     * Load all heart rate measurements from local storage.
     */
    suspend fun loadLocalMeasurements(): List<HeartRateMeasurement>

    /**
     * Load measurements for a specific date.
     */
    suspend fun loadMeasurementsForDate(date: LocalDate): List<HeartRateMeasurement>

    /**
     * Add a new heart rate measurement to local storage.
     */
    suspend fun addMeasurement(measurement: HeartRateMeasurement): ResultWrapper<Unit>

    /**
     * Delete a measurement from local storage.
     */
    suspend fun deleteMeasurement(timestamp: Long): ResultWrapper<Unit>

    /**
     * Clear all measurements from local storage.
     */
    suspend fun clearAllMeasurements(): ResultWrapper<Unit>

    /**
     * Get the most recent heart rate measurement.
     */
    suspend fun getLastMeasurement(): HeartRateMeasurement?

    // ── Cloud sync ──

    /**
     * Fetch heart rate measurements from cloud for a specific health profile.
     */
    suspend fun fetchFromCloud(profileId: String): ResultWrapper<List<HeartRateMeasurement>>

    /**
     * Sync local measurements to cloud.
     */
    suspend fun syncToCloud(
        measurements: List<HeartRateMeasurement>,
        profileId: String
    ): ResultWrapper<Unit>

    // ── Health Connect integration ──

    /**
     * Write heart rate measurement to Health Connect.
     */
    suspend fun writeToHealthConnect(bpm: Long): ResultWrapper<Unit>

    /**
     * Fetch heart rate data from Health Connect.
     */
    suspend fun fetchFromHealthConnect(): ResultWrapper<List<HeartRateMeasurement>>

    // ── Family Dashboard ──

    /**
     * Latest heart-rate row for the given profile (from `vital_signs`).
     * Returns null wrapped in success when the profile has no measurements yet.
     */
    suspend fun getLatestForProfile(profileId: String): Result<HeartRateSnapshot?>
}
