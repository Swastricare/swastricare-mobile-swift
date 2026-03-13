package com.swastricare.health.domain.usecase.menstrualcycle

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.menstrualcycle.CycleRecord
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import javax.inject.Inject

/**
 * Use case for retrieving cycle history.
 * Returns cycles sorted by start date (most recent first).
 */
class GetCycleHistoryUseCase @Inject constructor(
    private val repository: MenstrualCycleRepository
) {
    /**
     * Retrieves all cycle records, sorted by start date descending.
     */
    suspend operator fun invoke(): ResultWrapper<List<CycleRecord>> {
        return repository.getCycles().map { cycles ->
            cycles.sortedByDescending { it.startDate }
        }
    }

    /**
     * Retrieves the most recent N cycles.
     */
    suspend fun getRecent(count: Int): ResultWrapper<List<CycleRecord>> {
        return repository.getCycles().map { cycles ->
            cycles.sortedByDescending { it.startDate }.take(count)
        }
    }

    /**
     * Retrieves the currently active cycle (if any).
     */
    suspend fun getActiveCycle(): ResultWrapper<CycleRecord?> {
        return repository.getCycles().map { cycles ->
            cycles.firstOrNull { it.isActive }
        }
    }
}
