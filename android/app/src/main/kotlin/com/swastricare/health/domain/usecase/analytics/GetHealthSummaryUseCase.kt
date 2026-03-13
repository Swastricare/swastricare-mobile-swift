package com.swastricare.health.domain.usecase.analytics

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.analytics.HealthSummary
import com.swastricare.health.domain.repository.AnalyticsRepository
import java.time.LocalDate
import javax.inject.Inject

/**
 * Use case: Get health summary for a specific date or today.
 * Aggregates health metrics from multiple sources.
 */
class GetHealthSummaryUseCase @Inject constructor(
    private val repository: AnalyticsRepository
) {
    /**
     * Get health summary for today.
     *
     * @return Health summary with all metrics
     */
    suspend operator fun invoke(): ResultWrapper<HealthSummary> {
        return repository.getTodaySummary()
    }

    /**
     * Get health summary for a specific date.
     *
     * @param date The date to get summary for
     * @return Health summary for that date
     */
    suspend fun forDate(date: LocalDate): ResultWrapper<HealthSummary> {
        return repository.getSummaryForDate(date)
    }
}
