package com.swastricare.health.presentation.feature.medication

import com.swastricare.health.domain.model.AdherenceStatistics
import com.swastricare.health.domain.model.MedicationDose
import com.swastricare.health.domain.model.MedicationWithDoses
import com.swastricare.health.domain.model.TimePeriod
import java.time.LocalDate

/**
 * UI state for the Medications screen.
 * Represents all data needed to render the medication view.
 */
data class MedicationUiState(
    val medicationsWithDoses: List<MedicationWithDoses> = emptyList(),
    val statistics: AdherenceStatistics = AdherenceStatistics.Empty,
    val selectedDate: LocalDate = LocalDate.now(),
    val isLoading: Boolean = false,
    val error: String? = null
) {
    /**
     * All doses for the selected date, flattened and sorted by time.
     */
    val allDosesToday: List<MedicationDose>
        get() = medicationsWithDoses
            .flatMap { it.todayDoses }
            .sortedBy { it.scheduledTime }

    /**
     * Doses grouped by time period for timeline display.
     */
    val dosesByPeriod: Map<TimePeriod, List<MedicationDose>>
        get() = allDosesToday.groupBy { it.timePeriod }

    /**
     * Whether there are any medications.
     */
    val hasMedications: Boolean
        get() = medicationsWithDoses.isNotEmpty()

    /**
     * Whether the screen is in an error state.
     */
    val hasError: Boolean
        get() = error != null

    /**
     * Whether the screen is showing data (not loading and not empty).
     */
    val isShowingData: Boolean
        get() = !isLoading && hasMedications
}

/**
 * UI events for medication interactions.
 */
sealed class MedicationEvent {
    data class MarkDoseTaken(val dose: MedicationDose) : MedicationEvent()
    data class MarkDoseSkipped(val dose: MedicationDose, val reason: String?) : MedicationEvent()
    data class SelectDate(val date: LocalDate) : MedicationEvent()
    data class DeleteMedication(val medicationId: String) : MedicationEvent()
    data object Refresh : MedicationEvent()
    data object ClearError : MedicationEvent()
}

/**
 * UI actions for adding/editing medications.
 */
sealed class MedicationAction {
    data class AddMedication(
        val name: String,
        val dosage: String,
        val dosageUnit: String,
        val form: com.swastricare.health.domain.model.MedicationForm,
        val scheduleType: com.swastricare.health.domain.model.ScheduleType,
        val scheduleTimes: List<String>,
        val startDate: LocalDate,
        val endDate: LocalDate?,
        val isOngoing: Boolean,
        val notes: String?
    ) : MedicationAction()

    data class UpdateMedication(
        val medicationId: String,
        val name: String,
        val dosage: String,
        val notes: String?,
        val isOngoing: Boolean
    ) : MedicationAction()
}
