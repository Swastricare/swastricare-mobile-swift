package com.swastricare.health.domain.usecase.menstrualcycle

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.menstrualcycle.CycleRecord
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import java.time.LocalDate
import javax.inject.Inject

/**
 * Use case for ending a menstrual period.
 * Validates the end date and updates the cycle record.
 */
class EndPeriodUseCase @Inject constructor(
    private val repository: MenstrualCycleRepository
) {
    /**
     * Ends the active period.
     * @param cycleId The ID of the cycle to end
     * @param endDate The date the period ended (defaults to today)
     */
    suspend operator fun invoke(
        cycleId: String,
        endDate: LocalDate = LocalDate.now()
    ): ResultWrapper<CycleRecord> {
        // Validate end date is not in the future
        if (endDate.isAfter(LocalDate.now())) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("End date cannot be in the future"))
        }

        return repository.endCycle(cycleId, endDate)
    }
}
