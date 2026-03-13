package com.swastricare.health.domain.usecase.runactivity

import com.swastricare.health.domain.repository.RunActivityRepository
import javax.inject.Inject

/**
 * Use case for syncing workouts with cloud storage.
 *
 * Responsibilities:
 * - Sync unsynced workouts to cloud
 * - Fetch latest workouts from cloud
 * - Handle sync conflicts
 *
 * @param repository RunActivity repository
 */
class SyncWorkoutsUseCase @Inject constructor(
    private val repository: RunActivityRepository
) {

    /**
     * Sync workouts with cloud storage.
     *
     * @param profileId User's health profile ID
     * @return Result indicating success or failure
     */
    suspend operator fun invoke(profileId: String): Result<Unit> {
        return try {
            // Load local activities
            val localActivities = repository.loadLocalActivities()

            // Sync unsynced activities to cloud
            val unsynced = localActivities.filter { !it.synced }
            if (unsynced.isNotEmpty()) {
                repository.syncActivitiesToCloud(unsynced, profileId)
                    .getOrElse { return Result.failure(it) }
            }

            // Fetch latest from cloud to ensure we have all data
            repository.fetchActivitiesFromCloud(profileId)
                .getOrElse { return Result.failure(it) }

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
