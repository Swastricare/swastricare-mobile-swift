package com.swastricare.health.domain.usecase.medication

import com.swastricare.health.domain.model.Medication
import com.swastricare.health.domain.repository.MedicationRepository
import javax.inject.Inject

/**
 * Use case for updating an existing medication.
 * Encapsulates the business logic for medication updates.
 */
class UpdateMedicationUseCase @Inject constructor(
    private val repository: MedicationRepository
) {
    /**
     * Executes the use case to update a medication.
     *
     * @param medication The updated medication
     * @return Result containing the updated medication or error
     */
    suspend operator fun invoke(medication: Medication): Result<Medication> {
        // Validate medication
        if (medication.id.isBlank()) {
            return Result.failure(IllegalArgumentException("Medication ID cannot be empty"))
        }

        if (medication.name.isBlank()) {
            return Result.failure(IllegalArgumentException("Medication name cannot be empty"))
        }

        // Update medication in repository
        return repository.updateMedication(medication)
    }
}
