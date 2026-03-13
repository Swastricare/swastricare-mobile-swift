package com.swastricare.health.domain.usecase.hydration

import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.HydrationRepository
import javax.inject.Inject

/**
 * Use case: Sync hydration data between local and cloud.
 * Handles bidirectional sync to prevent data loss.
 */
class SyncHydrationUseCase @Inject constructor(
    private val repository: HydrationRepository,
    private val logger: Logger
) {
    /**
     * Sync hydration data for a specific profile.
     *
     * Strategy:
     * 1. Fetch cloud entries
     * 2. Merge with local unsynced entries
     * 3. Save merged data locally
     * 4. Push unsynced entries to cloud
     *
     * @param profileId Health profile ID
     * @return Result indicating success or failure
     */
    suspend operator fun invoke(profileId: String): ResultWrapper<Unit> {
        logger.d(TAG, "Starting hydration sync for profile: $profileId")

        // 1. Fetch from cloud
        val cloudResult = repository.fetchFromCloud(profileId)
        if (cloudResult is ResultWrapper.Error) {
            logger.e(TAG, "Failed to fetch from cloud", cloudResult.exception)
            // Don't return error - continue with local data
        }

        val cloudEntries = when (cloudResult) {
            is ResultWrapper.Success -> cloudResult.data
            else -> emptyList()
        }

        // 2. Get local unsynced entries
        val localEntries = repository.loadLocalEntries()
        val localUnsynced = localEntries.filter { !it.synced }

        // 3. Merge: cloud + local unsynced (avoid duplicates)
        val cloudIds = cloudEntries.map { it.id }.toSet()
        val uniqueLocalUnsynced = localUnsynced.filter { it.id !in cloudIds }
        val merged = cloudEntries + uniqueLocalUnsynced

        // 4. Save merged data locally
        repository.saveLocalEntries(merged)
        logger.d(TAG, "Merged ${merged.size} entries (${cloudEntries.size} cloud, ${uniqueLocalUnsynced.size} local)")

        // 5. Push unsynced entries to cloud
        if (uniqueLocalUnsynced.isNotEmpty()) {
            logger.d(TAG, "Syncing ${uniqueLocalUnsynced.size} local entries to cloud")
            when (val syncResult = repository.syncEntriesToCloud(uniqueLocalUnsynced, profileId)) {
                is ResultWrapper.Error -> {
                    logger.e(TAG, "Failed to sync to cloud", syncResult.exception)
                    return syncResult
                }
                else -> {}
            }
        }

        logger.d(TAG, "Hydration sync completed successfully")
        return ResultWrapper.Success(Unit)
    }

    companion object {
        private const val TAG = "SyncHydrationUseCase"
    }
}
