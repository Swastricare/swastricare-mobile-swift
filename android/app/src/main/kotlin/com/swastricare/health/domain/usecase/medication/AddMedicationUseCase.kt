package com.swastricare.health.domain.usecase.medication

import com.swastricare.health.domain.model.Medication
import com.swastricare.health.domain.model.MedicationSchedule
import com.swastricare.health.domain.repository.MedicationRepository
import javax.inject.Inject

/**
 * Use case for adding a new medication with schedules.
 * Encapsulates the business logic for creating a medication entry.
 */
class AddMedicationUseCase @Inject constructor(
    private val repository: MedicationRepository
) {
    /**
     * Executes the use case to add a medication.
     *
     * @param medication The medication to add
     * @param schedules The schedules for the medication
     * @return Result containing the added medication or error
     */
    suspend operator fun invoke(
        medication: Medication,
        schedules: List<MedicationSchedule>
    ): Result<Medication> {
        // Validate medication
        if (medication.name.isBlank()) {
            return Result.failure(IllegalArgumentException("Medication name cannot be empty"))
        }

        // Validate schedules
        if (schedules.isEmpty()) {
            return Result.failure(IllegalArgumentException("At least one schedule is required"))
        }

        // Validate that all schedules belong to the same medication
        if (schedules.any { it.medicationId != medication.id }) {
            return Result.failure(IllegalArgumentException("All schedules must belong to the medication"))
        }

        // Add medication to repository
        val medicationResult = repository.addMedication(medication)
        if (medicationResult.isFailure) {
            return medicationResult
        }

        // Add schedules
        val schedulesResult = repository.addSchedules(schedules)
        if (schedulesResult.isFailure) {
            return Result.failure(schedulesResult.exceptionOrNull() ?: Exception("Failed to add schedules"))
        }

        return medicationResult
    }
}
