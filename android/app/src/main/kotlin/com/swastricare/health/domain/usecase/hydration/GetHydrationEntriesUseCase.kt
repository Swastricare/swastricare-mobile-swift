package com.swastricare.health.domain.usecase.hydration

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.hydration.HydrationEntry
import com.swastricare.health.domain.repository.HydrationRepository
import javax.inject.Inject

/**
 * Use case: Get hydration entries from repository.
 *
 * Business logic:
 * - Fetches entries from cloud (Supabase)
 * - Falls back to local entries if cloud fetch fails
 * - Validates profileId before fetching
 *
 * Single Responsibility: Coordinate hydration entry fetching
 */
class GetHydrationEntriesUseCase @Inject constructor(
    private val hydrationRepository: HydrationRepository
) {

    /**
     * Fetch hydration entries for a specific profile.
     *
     * @param profileId Health profile ID
     * @return ResultWrapper with list of HydrationEntry or error
     */
    suspend operator fun invoke(profileId: String): ResultWrapper<List<HydrationEntry>> {
        // Validation
        if (profileId.isBlank()) {
            return ResultWrapper.Error(
                com.swastricare.health.core.result.AppException.ValidationException.Custom(
                    "Profile ID cannot be empty"
                )
            )
        }

        // Try to fetch from cloud
        return try {
            when (val cloudResult = hydrationRepository.fetchFromCloud(profileId)) {
                is ResultWrapper.Success -> {
                    val entries = cloudResult.data
                    ResultWrapper.Success(entries)
                }
                else -> {
                    // Fallback to local entries if cloud fetch fails
                    val localEntries = hydrationRepository.loadLocalEntries()
                    ResultWrapper.Success(localEntries)
                }
            }
        } catch (e: Exception) {
            // On any error, return local entries as fallback
            val localEntries = hydrationRepository.loadLocalEntries()
            if (localEntries.isNotEmpty()) {
                ResultWrapper.Success(localEntries)
            } else {
                ResultWrapper.Error(
                    com.swastricare.health.core.result.AppException.UnknownException(
                        "Failed to fetch hydration entries",
                        e
                    )
                )
            }
        }
    }
}
