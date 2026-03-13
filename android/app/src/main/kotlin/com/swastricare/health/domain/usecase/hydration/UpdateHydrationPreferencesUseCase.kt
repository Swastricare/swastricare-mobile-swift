package com.swastricare.health.domain.usecase.hydration

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.hydration.HydrationPreferences
import com.swastricare.health.domain.repository.HydrationRepository
import javax.inject.Inject

/**
 * Use case: Update hydration preferences.
 */
class UpdateHydrationPreferencesUseCase @Inject constructor(
    private val repository: HydrationRepository
) {
    /**
     * Update user's hydration preferences.
     *
     * @param preferences New preferences to save
     * @return Result indicating success or failure
     */
    suspend operator fun invoke(preferences: HydrationPreferences): ResultWrapper<Unit> {
        // Validation
        preferences.weightKg?.let { weight ->
            if (weight <= 0 || weight > 500) {
                return ResultWrapper.Error(
                    AppException.ValidationException.Custom("Weight must be between 0 and 500 kg")
                )
            }
        }

        preferences.customGoalMl?.let { goal ->
            if (goal < 500 || goal > 10000) {
                return ResultWrapper.Error(
                    AppException.ValidationException.Custom("Custom goal must be between 500ml and 10000ml")
                )
            }
        }

        return repository.savePreferences(preferences)
    }
}
