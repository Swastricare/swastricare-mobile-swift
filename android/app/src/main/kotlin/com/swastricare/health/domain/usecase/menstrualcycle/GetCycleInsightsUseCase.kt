package com.swastricare.health.domain.usecase.menstrualcycle

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.menstrualcycle.CycleStatistics
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import javax.inject.Inject

/**
 * Use case for retrieving cycle insights and statistics.
 * Provides aggregate data like average cycle length, regularity, etc.
 */
class GetCycleInsightsUseCase @Inject constructor(
    private val repository: MenstrualCycleRepository
) {
    /**
     * Retrieves comprehensive cycle statistics including:
     * - Average cycle length
     * - Average period length
     * - Longest/shortest cycles
     * - Regularity assessment
     * - Total cycles tracked
     */
    suspend operator fun invoke(): ResultWrapper<CycleStatistics> {
        return repository.getStatistics()
    }
}
