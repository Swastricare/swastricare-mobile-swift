package com.swastricare.health.domain.usecase.medication

import com.swastricare.health.domain.model.AdherenceStatistics
import com.swastricare.health.domain.model.AdherenceStatus
import com.swastricare.health.domain.model.MedicationWithDoses
import javax.inject.Inject

/**
 * Use case for calculating medication adherence statistics.
 * Provides insights into medication compliance.
 */
class GetAdherenceStatisticsUseCase @Inject constructor() {
    /**
     * Calculates adherence statistics from medications with doses.
     *
     * @param medicationsWithDoses List of medications with their doses
     * @return Adherence statistics
     */
    operator fun invoke(medicationsWithDoses: List<MedicationWithDoses>): AdherenceStatistics {
        val allDoses = medicationsWithDoses.flatMap { it.todayDoses }

        if (allDoses.isEmpty()) {
            return AdherenceStatistics.Empty
        }

        val takenCount = allDoses.count { it.status == AdherenceStatus.TAKEN }
        val missedCount = allDoses.count { it.status == AdherenceStatus.MISSED }
        val pendingCount = allDoses.count { it.status == AdherenceStatus.PENDING }
        val totalCount = allDoses.size

        val adherenceRate = if (totalCount > 0) {
            takenCount.toFloat() / totalCount
        } else {
            0f
        }

        return AdherenceStatistics(
            totalDoses = totalCount,
            takenDoses = takenCount,
            missedDoses = missedCount,
            pendingDoses = pendingCount,
            adherenceRate = adherenceRate
        )
    }
}
