package com.swastricare.health.presentation.feature.medication

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.qualifiers.ApplicationContext
import com.swastricare.health.domain.repository.ProfileRepository
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.data.services.AnalyticsService
import com.swastricare.health.domain.model.AdherenceStatus
import com.swastricare.health.domain.model.Medication
import com.swastricare.health.domain.model.MedicationDose
import com.swastricare.health.domain.model.MedicationForm
import com.swastricare.health.domain.model.MedicationSchedule
import com.swastricare.health.domain.model.MedicationStatus
import com.swastricare.health.domain.model.ScheduleType
import com.swastricare.health.domain.repository.MedicationRepository
import com.swastricare.health.domain.usecase.medication.AddMedicationUseCase
import com.swastricare.health.domain.usecase.medication.DeleteMedicationUseCase
import com.swastricare.health.domain.usecase.medication.GetAdherenceStatisticsUseCase
import com.swastricare.health.domain.usecase.medication.GetMedicationsUseCase
import com.swastricare.health.domain.usecase.medication.MarkDoseUseCase
import com.swastricare.health.domain.usecase.medication.UpdateMedicationUseCase
import com.swastricare.health.notifications.MedicationReminderScheduler
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.UUID
import javax.inject.Inject

/**
 * ViewModel for Medications feature.
 * Manages medication data, schedules, and adherence tracking using Clean Architecture.
 */
@HiltViewModel
class MedicationsViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val getMedicationsUseCase: GetMedicationsUseCase,
    private val addMedicationUseCase: AddMedicationUseCase,
    private val updateMedicationUseCase: UpdateMedicationUseCase,
    private val deleteMedicationUseCase: DeleteMedicationUseCase,
    private val markDoseUseCase: MarkDoseUseCase,
    private val getAdherenceStatisticsUseCase: GetAdherenceStatisticsUseCase,
    private val medicationRepository: MedicationRepository,
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val analyticsService: AnalyticsService,
    // MedicationReminderScheduler is an object singleton, accessed directly
) : ViewModel() {

    companion object {
        private const val TAG = "MedicationsVM"
    }

    private val _uiState = MutableStateFlow(MedicationUiState(isLoading = true))
    val uiState: StateFlow<MedicationUiState> = _uiState.asStateFlow()

    init {
        // Load from cache immediately for instant display
        val cached = medicationRepository.getCachedMedications()
        if (cached.isNotEmpty()) {
            _uiState.update { it.copy(isLoading = false) }
        }
        loadMedications()
    }

    // ─────────────────────────────────────
    // MARK: - Public API
    // ─────────────────────────────────────

    fun onEvent(event: MedicationEvent) {
        when (event) {
            is MedicationEvent.MarkDoseTaken -> markAsTaken(event.dose)
            is MedicationEvent.MarkDoseSkipped -> markAsSkipped(event.dose, event.reason)
            is MedicationEvent.SelectDate -> selectDate(event.date)
            is MedicationEvent.DeleteMedication -> deleteMedication(event.medicationId)
            is MedicationEvent.Refresh -> loadMedications()
            is MedicationEvent.ClearError -> clearError()
        }
    }

    fun onAction(action: MedicationAction) {
        when (action) {
            is MedicationAction.AddMedication -> addMedication(
                name = action.name,
                dosage = action.dosage,
                dosageUnit = action.dosageUnit,
                form = action.form,
                scheduleType = action.scheduleType,
                scheduleTimes = action.scheduleTimes,
                startDate = action.startDate,
                endDate = action.endDate,
                isOngoing = action.isOngoing,
                notes = action.notes
            )
            is MedicationAction.UpdateMedication -> updateMedication(
                medicationId = action.medicationId,
                name = action.name,
                dosage = action.dosage,
                notes = action.notes,
                isOngoing = action.isOngoing
            )
        }
    }

    // ─────────────────────────────────────
    // MARK: - Private Implementation
    // ─────────────────────────────────────

    private fun loadMedications(date: LocalDate = _uiState.value.selectedDate) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            try {
                val profileId = resolveProfileId()
                Log.d(TAG, "loadMedications: profileId=$profileId, date=$date")

                // Fetch medications with doses using use case
                val result = getMedicationsUseCase(profileId, date)

                if (result.isSuccess) {
                    val medicationsWithDoses = result.getOrThrow()
                    val statistics = getAdherenceStatisticsUseCase(medicationsWithDoses)

                    // Cache medications for offline access
                    val medications = medicationsWithDoses.map { it.medication }
                    medicationRepository.cacheMedications(medications)

                    // Schedule reminders
                    val allSchedules = medicationsWithDoses.flatMap { it.schedules }
                    scheduleReminders(allSchedules, medications)

                    _uiState.update {
                        it.copy(
                            medicationsWithDoses = medicationsWithDoses,
                            statistics = statistics,
                            selectedDate = date,
                            isLoading = false,
                            error = null
                        )
                    }

                    Log.d(TAG, "loadMedications: loaded ${medicationsWithDoses.size} medications")
                } else {
                    val error = result.exceptionOrNull()
                    Log.e(TAG, "loadMedications failed", error)
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = error?.message ?: "Failed to load medications"
                        )
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "loadMedications failed", e)
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = e.message ?: "Failed to load medications"
                    )
                }
            }
        }
    }

    private fun selectDate(date: LocalDate) {
        loadMedications(date)
    }

    private fun markAsTaken(dose: MedicationDose) {
        viewModelScope.launch {
            // Log analytics event
            analyticsService.logMedicationTaken(dose.medicationName)

            // Optimistic update
            updateDoseStatus(dose, AdherenceStatus.TAKEN)

            try {
                val profileId = resolveProfileId()
                val result = markDoseUseCase.markTaken(
                    medicationId = dose.medicationId,
                    scheduleId = dose.scheduleId,
                    profileId = profileId,
                    scheduledTime = dose.scheduledTime,
                    logId = dose.logId
                )

                if (result.isSuccess) {
                    // Update logId with returned DB id
                    val newLogId = result.getOrThrow()
                    updateDoseLogId(dose, newLogId)
                } else {
                    // Revert optimistic update on failure
                    updateDoseStatus(dose, dose.status)
                    _uiState.update { it.copy(error = "Failed to mark as taken") }
                }
            } catch (e: Exception) {
                Log.e(TAG, "markAsTaken failed", e)
                updateDoseStatus(dose, dose.status)
                _uiState.update { it.copy(error = "Failed to mark as taken") }
            }
        }
    }

    private fun markAsSkipped(dose: MedicationDose, reason: String?) {
        viewModelScope.launch {
            // Log analytics event
            analyticsService.logMedicationSkipped(dose.medicationName, reason)

            // Optimistic update
            updateDoseStatus(dose, AdherenceStatus.SKIPPED)

            try {
                val profileId = resolveProfileId()
                val result = markDoseUseCase.markSkipped(
                    medicationId = dose.medicationId,
                    scheduleId = dose.scheduleId,
                    profileId = profileId,
                    scheduledTime = dose.scheduledTime,
                    reason = reason,
                    logId = dose.logId
                )

                if (result.isFailure) {
                    // Revert optimistic update on failure
                    updateDoseStatus(dose, dose.status)
                    _uiState.update { it.copy(error = "Failed to mark as skipped") }
                }
            } catch (e: Exception) {
                Log.e(TAG, "markAsSkipped failed", e)
                updateDoseStatus(dose, dose.status)
                _uiState.update { it.copy(error = "Failed to mark as skipped") }
            }
        }
    }

    private fun addMedication(
        name: String,
        dosage: String,
        dosageUnit: String,
        form: MedicationForm,
        scheduleType: ScheduleType,
        scheduleTimes: List<String>,
        startDate: LocalDate,
        endDate: LocalDate?,
        isOngoing: Boolean,
        notes: String?
    ) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            try {
                val profileId = resolveProfileId()
                val medicationId = UUID.randomUUID().toString()

                // Create medication
                val medication = Medication(
                    id = medicationId,
                    healthProfileId = profileId,
                    name = name,
                    dosage = dosage,
                    dosageUnit = dosageUnit,
                    form = form,
                    startDate = startDate,
                    endDate = endDate,
                    isOngoing = isOngoing,
                    notes = notes,
                    status = MedicationStatus.ACTIVE,
                    createdAt = null
                )

                // Create schedules
                val schedules = buildSchedules(
                    medicationId = medicationId,
                    profileId = profileId,
                    scheduleType = scheduleType,
                    times = scheduleTimes
                )

                // Use AddMedicationUseCase
                val result = addMedicationUseCase(medication, schedules)

                if (result.isSuccess) {
                    Log.d(TAG, "addMedication: successfully added medication")

                    // Schedule reminders
                    scheduleReminders(schedules, listOf(medication))

                    // Reload medications
                    loadMedications()
                } else {
                    Log.e(TAG, "addMedication failed", result.exceptionOrNull())
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = "Failed to save medication"
                        )
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "addMedication failed", e)
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = "Failed to save medication"
                    )
                }
            }
        }
    }

    private fun updateMedication(
        medicationId: String,
        name: String,
        dosage: String,
        notes: String?,
        isOngoing: Boolean
    ) {
        viewModelScope.launch {
            try {
                val current = _uiState.value.medicationsWithDoses
                    .firstOrNull { it.medication.id == medicationId }?.medication
                    ?: return@launch

                val updated = current.copy(
                    name = name,
                    dosage = dosage,
                    notes = notes,
                    isOngoing = isOngoing
                )

                val result = updateMedicationUseCase(updated)

                if (result.isSuccess) {
                    loadMedications()
                } else {
                    _uiState.update { it.copy(error = "Failed to update medication") }
                }
            } catch (e: Exception) {
                Log.e(TAG, "updateMedication failed", e)
                _uiState.update { it.copy(error = "Failed to update medication") }
            }
        }
    }

    private fun deleteMedication(medicationId: String) {
        viewModelScope.launch {
            try {
                // Get schedules to cancel their reminders
                val schedulesToCancel = _uiState.value.medicationsWithDoses
                    .firstOrNull { it.medication.id == medicationId }
                    ?.schedules.orEmpty()

                val result = deleteMedicationUseCase(medicationId)

                if (result.isSuccess) {
                    // Cancel reminders
                    schedulesToCancel.forEach { schedule ->
                        MedicationReminderScheduler.cancel(context, schedule.id)
                    }
                    loadMedications()
                } else {
                    _uiState.update { it.copy(error = "Failed to delete medication") }
                }
            } catch (e: Exception) {
                Log.e(TAG, "deleteMedication failed", e)
                _uiState.update { it.copy(error = "Failed to delete medication") }
            }
        }
    }

    private fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    // ─────────────────────────────────────
    // MARK: - Helper Functions
    // ─────────────────────────────────────

    private suspend fun resolveProfileId(): String {
        val userId = authRepository.getCurrentUser()?.id
            ?: throw IllegalStateException("No authenticated user")
        val result = profileRepository.getHealthProfile(userId)
        val healthProfile = when (result) {
            is com.swastricare.health.core.result.ResultWrapper.Success -> result.data
                ?: throw IllegalStateException("No health profile found")
            else -> throw IllegalStateException("No health profile found")
        }
        return healthProfile.id.ifBlank { throw IllegalStateException("Health profile has no ID") }
    }

    private fun buildSchedules(
        medicationId: String,
        profileId: String,
        scheduleType: ScheduleType,
        times: List<String>
    ): List<MedicationSchedule> {
        val count = if (scheduleType == ScheduleType.CUSTOM) times.size else scheduleType.dosesPerDay
        val effectiveTimes = if (times.isNotEmpty()) times else listOf("08:00:00")

        return effectiveTimes.take(count.coerceAtLeast(1)).map { time ->
            MedicationSchedule(
                id = UUID.randomUUID().toString(),
                medicationId = medicationId,
                healthProfileId = profileId,
                scheduleType = scheduleType,
                timeOfDay = time.padEnd(8, ':').take(8).let {
                    if (it.length == 5) "$it:00" else it
                },
                frequencyPerDay = count,
                dosageAmount = 1.0,
                reminderEnabled = true,
                isActive = true,
                daysOfWeek = null
            )
        }
    }

    private fun scheduleReminders(schedules: List<MedicationSchedule>, medications: List<Medication>) {
        schedules.forEach { schedule ->
            val medication = medications.firstOrNull { it.id == schedule.medicationId }
            if (medication != null && schedule.reminderEnabled) {
                val parts = schedule.timeOfDay.split(":")
                val hour = parts.getOrNull(0)?.toIntOrNull() ?: return@forEach
                val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0

                MedicationReminderScheduler.schedule(
                    context = context,
                    medId = medication.id,
                    scheduleId = schedule.id,
                    medName = medication.name,
                    timeHour = hour,
                    timeMinute = minute
                )
            }
        }
    }

    private fun updateDoseStatus(dose: MedicationDose, newStatus: AdherenceStatus) {
        _uiState.update { current ->
            val updated = current.medicationsWithDoses.map { mwd ->
                if (mwd.medication.id != dose.medicationId) return@map mwd
                val updatedDoses = mwd.todayDoses.map { d ->
                    if (d.scheduleId == dose.scheduleId && d.scheduledTime == dose.scheduledTime) {
                        d.copy(status = newStatus)
                    } else {
                        d
                    }
                }
                mwd.copy(todayDoses = updatedDoses)
            }
            current.copy(
                medicationsWithDoses = updated,
                statistics = getAdherenceStatisticsUseCase(updated)
            )
        }
    }

    private fun updateDoseLogId(dose: MedicationDose, logId: String) {
        _uiState.update { current ->
            val updated = current.medicationsWithDoses.map { mwd ->
                if (mwd.medication.id != dose.medicationId) return@map mwd
                val updatedDoses = mwd.todayDoses.map { d ->
                    if (d.scheduleId == dose.scheduleId && d.scheduledTime == dose.scheduledTime) {
                        d.copy(logId = logId)
                    } else {
                        d
                    }
                }
                mwd.copy(todayDoses = updatedDoses)
            }
            current.copy(medicationsWithDoses = updated)
        }
    }
}
