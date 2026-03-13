package com.swastricare.health.domain.usecase.medication

import com.swastricare.health.domain.repository.MedicationRepository
import javax.inject.Inject

/**
 * Use case for deleting a medication.
 * Performs soft-delete to maintain data integrity.
 */
class DeleteMedicationUseCase @Inject constructor(
    private val repository: MedicationRepository
) {
    /**
     * Executes the use case to delete a medication.
     *
     * @param medicationId The ID of the medication to delete
     * @return Result indicating success or error
     */
    suspend operator fun invoke(medicationId: String): Result<Unit> {
        // Validate medication ID
        if (medicationId.isBlank()) {
            return Result.failure(IllegalArgumentException("Medication ID cannot be empty"))
        }

        // Delete medication (soft-delete in repository)
        return repository.deleteMedication(medicationId)
    }
}
