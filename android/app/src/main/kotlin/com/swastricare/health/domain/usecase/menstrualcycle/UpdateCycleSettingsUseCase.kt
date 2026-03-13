package com.swastricare.health.domain.usecase.menstrualcycle

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.menstrualcycle.CycleSettings
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import javax.inject.Inject

/**
 * Use case for updating menstrual cycle settings.
 * Validates settings before saving.
 */
class UpdateCycleSettingsUseCase @Inject constructor(
    private val repository: MenstrualCycleRepository
) {
    /**
     * Updates cycle settings with validation.
     * @param settings The new settings to apply
     */
    suspend operator fun invoke(settings: CycleSettings): ResultWrapper<CycleSettings> {
        // Validate settings
        if (!settings.isValid()) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Invalid settings: cycle length must be 21-45 days, period length 2-10 days")
            )
        }

        return repository.updateSettings(settings)
    }
}
