package com.swastricare.health.domain.repository

import com.swastricare.health.domain.model.TimeRangeFilter
import com.swastricare.health.domain.model.WorkoutRecoveryState
import com.swastricare.health.domain.model.WorkoutSession
import com.swastricare.health.domain.model.WorkoutStats

/**
 * Domain repository interface for run activity operations.
 * This interface defines the contract that the data layer must implement.
 *
 * Following Clean Architecture principles:
 * - Domain layer defines the interface
 * - Data layer provides the implementation
 * - Presentation layer depends on this abstraction
 */
interface RunActivityRepository {

    // ── Local Storage Operations ──

    /**
     * Load all workout sessions from local storage.
     * @return List of workout sessions, newest first
     */
    suspend fun loadLocalActivities(): List<WorkoutSession>

    /**
     * Save workout sessions to local storage.
     * @param activities List of sessions to save
     */
    suspend fun saveLocalActivities(activities: List<WorkoutSession>)

    /**
     * Add a new workout session to local storage.
     * @param activity Workout session to add
     */
    suspend fun addLocalActivity(activity: WorkoutSession)

    /**
     * Delete a workout session from local storage.
     * @param id ID of the session to delete
     */
    suspend fun deleteLocalActivity(id: String)

    // ── Cloud Sync Operations ──

    /**
     * Sync unsynced activities to cloud storage.
     * @param activities List of activities to sync
     * @param profileId User's health profile ID
     * @return Result indicating success or failure
     */
    suspend fun syncActivitiesToCloud(
        activities: List<WorkoutSession>,
        profileId: String
    ): Result<Unit>

    /**
     * Fetch all activities from cloud storage.
     * @param profileId User's health profile ID
     * @return Result with list of activities or error
     */
    suspend fun fetchActivitiesFromCloud(profileId: String): Result<List<WorkoutSession>>

    // ── Statistics Operations ──

    /**
     * Calculate statistics for a given time range.
     * @param activities List of all activities
     * @param filter Time range filter to apply
     * @return Calculated statistics
     */
    suspend fun calculateStatistics(
        activities: List<WorkoutSession>,
        filter: TimeRangeFilter
    ): WorkoutStats

    // ── Workout Recovery Operations ──

    /**
     * Save current workout state for crash recovery.
     * @param state Current workout state
     */
    suspend fun saveWorkoutState(state: WorkoutRecoveryState)

    /**
     * Load saved workout state for recovery.
     * @return Saved state if available and active, null otherwise
     */
    suspend fun loadWorkoutState(): WorkoutRecoveryState?

    /**
     * Clear saved workout state after successful completion or recovery.
     */
    suspend fun clearWorkoutState()
}
