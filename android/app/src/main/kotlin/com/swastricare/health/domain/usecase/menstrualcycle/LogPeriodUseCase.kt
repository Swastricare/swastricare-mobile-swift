package com.swastricare.health.domain.usecase.menstrualcycle

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.menstrualcycle.CycleRecord
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import java.time.LocalDate
import javax.inject.Inject

/**
 * Use case for starting a new menstrual cycle.
 * Validates the start date and creates a new cycle record.
 */
class LogPeriodUseCase @Inject constructor(
    private val repository: MenstrualCycleRepository
) {
    /**
     * Starts a new period/cycle.
     * @param startDate The date the period began (defaults to today)
     * @param notes Optional notes about the cycle
     */
    suspend operator fun invoke(
        startDate: LocalDate = LocalDate.now(),
        notes: String? = null
    ): ResultWrapper<CycleRecord> {
        // Validate start date is not in the future
        if (startDate.isAfter(LocalDate.now())) {
            return ResultWrapper.Error(AppException.ValidationException.Custom("Start date cannot be in the future"))
        }

        return repository.startCycle(startDate, notes)
    }
}
