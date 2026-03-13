package com.swastricare.health.domain.usecase.menstrualcycle

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.menstrualcycle.CalendarDayData
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import java.time.LocalDate
import javax.inject.Inject

/**
 * Use case for retrieving calendar data for the cycle tracker.
 * Combines actual logged data with predictions for display.
 */
class GetCalendarDataUseCase @Inject constructor(
    private val repository: MenstrualCycleRepository
) {
    /**
     * Gets calendar data for a specific month.
     * Includes logged periods, predictions, and phase information.
     * @param month The month to retrieve data for (defaults to current month)
     */
    suspend operator fun invoke(
        month: LocalDate = LocalDate.now().withDayOfMonth(1)
    ): ResultWrapper<List<CalendarDayData>> {
        return repository.getCalendarData(month)
    }
}
