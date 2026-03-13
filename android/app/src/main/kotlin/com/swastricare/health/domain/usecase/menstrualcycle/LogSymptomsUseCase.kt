package com.swastricare.health.domain.usecase.menstrualcycle

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.menstrualcycle.DailyLog
import com.swastricare.health.domain.model.menstrualcycle.FlowLevel
import com.swastricare.health.domain.model.menstrualcycle.Mood
import com.swastricare.health.domain.model.menstrualcycle.Symptom
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import java.time.LocalDate
import javax.inject.Inject

/**
 * Use case for logging daily menstrual symptoms.
 * Validates input and creates/updates daily log entries.
 */
class LogSymptomsUseCase @Inject constructor(
    private val repository: MenstrualCycleRepository
) {
    /**
     * Logs daily symptoms, flow, mood, and pain level.
     * @param date The date for this log (defaults to today)
     * @param flowLevel Menstrual flow level
     * @param symptoms List of symptoms experienced
     * @param mood Current mood (optional)
     * @param notes Optional notes
     * @param painLevel Pain level on 0-10 scale
     */
    suspend operator fun invoke(
        date: LocalDate = LocalDate.now(),
        flowLevel: FlowLevel,
        symptoms: List<Symptom> = emptyList(),
        mood: Mood? = null,
        notes: String? = null,
        painLevel: Int = 0
    ): ResultWrapper<DailyLog> {
        // Validate pain level
        if (painLevel !in 0..10) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Pain level must be between 0 and 10")
            )
        }

        // Validate date is not in the future
        if (date.isAfter(LocalDate.now())) {
            return ResultWrapper.Error(
                AppException.ValidationException.Custom("Cannot log symptoms for future dates")
            )
        }

        return repository.logDailyData(
            date = date,
            flowLevel = flowLevel,
            symptoms = symptoms,
            mood = mood,
            notes = notes,
            painLevel = painLevel
        )
    }
}
