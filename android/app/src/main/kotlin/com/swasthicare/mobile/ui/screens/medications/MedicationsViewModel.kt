package com.swasthicare.mobile.ui.screens.medications

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.data.repository.MedicationRepository
import com.swasthicare.mobile.data.repository.ProfileRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.UUID

// ─────────────────────────────────────
// MARK: - UI State
// ─────────────────────────────────────

data class MedicationsUiState(
    val medicationsWithDoses: List<MedicationWithDoses> = emptyList(),
    val statistics: AdherenceStatistics = AdherenceStatistics.Empty,
    val selectedDate: LocalDate = LocalDate.now(),
    val isLoading: Boolean = false,
    val error: String? = null
) {
    /** All doses for selectedDate, flattened and sorted by time */
    val allDosesToday: List<MedicationDose> get() =
        medicationsWithDoses.flatMap { it.todayDoses }
            .sortedBy { it.scheduledTime }

    /** Doses grouped by time period for timeline display */
    val dosesByPeriod: Map<TimePeriod, List<MedicationDose>> get() =
        allDosesToday.groupBy { it.timePeriod }
}

// ─────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────

class MedicationsViewModel(
    private val repository: MedicationRepository,
    private val profileRepository: ProfileRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(MedicationsUiState(isLoading = true))
    val uiState: StateFlow<MedicationsUiState> = _uiState.asStateFlow()

    // Hardcoded for demo; in production, fetch from auth + profileRepository
    private val demoProfileId = "demo-profile-id"

    init {
        // Load from cache immediately for instant display
        val cached = repository.getCachedMedications()
        if (cached.isNotEmpty()) {
            _uiState.value = _uiState.value.copy(isLoading = false)
        }
        loadMedications()
    }

    fun loadMedications(date: LocalDate = _uiState.value.selectedDate) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val profileId = resolveProfileId()
                val medications = repository.fetchMedications(profileId)
                val schedules = repository.fetchSchedules(profileId)
                val logs = repository.fetchTodayLogs(profileId, date)

                repository.cacheMedications(medications)

                val withDoses = buildMedicationsWithDoses(medications, schedules, logs, date)
                val stats = computeStats(withDoses)

                _uiState.value = _uiState.value.copy(
                    medicationsWithDoses = withDoses,
                    statistics = stats,
                    selectedDate = date,
                    isLoading = false
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to load medications"
                )
            }
        }
    }

    fun selectDate(date: LocalDate) {
        loadMedications(date)
    }

    fun markAsTaken(dose: MedicationDose) {
        viewModelScope.launch {
            // Optimistic update
            updateDoseStatus(dose, AdherenceStatus.TAKEN)

            val profileId = resolveProfileId()
            val result = repository.markAsTaken(
                medicationId = dose.medicationId,
                scheduleId = dose.scheduleId,
                profileId = profileId,
                scheduledTime = dose.scheduledTime,
                logId = dose.logId
            )
            if (result.isFailure) {
                // Revert optimistic update on failure
                updateDoseStatus(dose, dose.status)
                _uiState.value = _uiState.value.copy(error = "Failed to mark as taken")
            } else {
                // Update logId with returned DB id
                result.getOrNull()?.let { newLogId ->
                    updateDoseLogId(dose, newLogId)
                }
            }
        }
    }

    fun markAsSkipped(dose: MedicationDose, reason: String? = null) {
        viewModelScope.launch {
            updateDoseStatus(dose, AdherenceStatus.SKIPPED)

            val profileId = resolveProfileId()
            val result = repository.markAsSkipped(
                medicationId = dose.medicationId,
                scheduleId = dose.scheduleId,
                profileId = profileId,
                scheduledTime = dose.scheduledTime,
                logId = dose.logId,
                reason = reason
            )
            if (result.isFailure) {
                updateDoseStatus(dose, dose.status)
                _uiState.value = _uiState.value.copy(error = "Failed to mark as skipped")
            }
        }
    }

    fun addMedication(
        name: String,
        dosage: String,
        dosageUnit: String,
        type: MedicationType,
        scheduleType: ScheduleType,
        scheduleTimes: List<String>,
        startDate: LocalDate,
        endDate: LocalDate?,
        isOngoing: Boolean,
        notes: String?
    ) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            val profileId = resolveProfileId()
            val medicationDto = MedicationDto(
                id = UUID.randomUUID().toString(),
                healthProfileId = profileId,
                name = name,
                dosage = dosage,
                dosageUnit = dosageUnit,
                form = type.dbForm,
                startDate = startDate.toString(),
                endDate = endDate?.toString(),
                isOngoing = isOngoing,
                notes = notes,
                status = "active"
            )
            val result = repository.upsertMedication(medicationDto)
            if (result.isSuccess) {
                val savedMed = result.getOrThrow()
                val schedules = buildSchedules(savedMed.id, profileId, scheduleType, scheduleTimes)
                repository.upsertSchedules(schedules)
                loadMedications()
            } else {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Failed to save medication"
                )
            }
        }
    }

    fun deleteMedication(medicationId: String) {
        viewModelScope.launch {
            val result = repository.deleteMedication(medicationId)
            if (result.isSuccess) {
                loadMedications()
            } else {
                _uiState.value = _uiState.value.copy(error = "Failed to delete medication")
            }
        }
    }

    fun updateMedication(
        medicationId: String,
        name: String,
        dosage: String,
        notes: String?,
        isOngoing: Boolean
    ) {
        viewModelScope.launch {
            val current = _uiState.value.medicationsWithDoses
                .firstOrNull { it.medication.id == medicationId }?.medication ?: return@launch
            val updated = current.copy(
                name = name,
                dosage = dosage,
                notes = notes,
                isOngoing = isOngoing
            )
            val result = repository.upsertMedication(updated)
            if (result.isSuccess) {
                loadMedications()
            } else {
                _uiState.value = _uiState.value.copy(error = "Failed to update medication")
            }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    // ─────────────────────────────────────
    // MARK: - Private Helpers
    // ─────────────────────────────────────

    private suspend fun resolveProfileId(): String {
        return try {
            // Try to get from profileRepository; fall back to demo id for now
            profileRepository.getHealthProfile(demoProfileId)?.userId ?: demoProfileId
        } catch (e: Exception) {
            demoProfileId
        }
    }

    private fun buildMedicationsWithDoses(
        medications: List<MedicationDto>,
        schedules: List<MedicationScheduleDto>,
        logs: List<MedicationLogDto>,
        date: LocalDate
    ): List<MedicationWithDoses> {
        return medications.map { med ->
            val medSchedules = schedules.filter { it.medicationId == med.id }
            val medLogs = logs.filter { it.medicationId == med.id }
            val doses = medSchedules.flatMap { schedule ->
                schedule.buildDosesForDate(med, date, medLogs)
            }.sortedBy { it.scheduledTime }
            MedicationWithDoses(
                medication = med,
                schedules = medSchedules,
                todayDoses = doses
            )
        }
    }

    private fun computeStats(items: List<MedicationWithDoses>): AdherenceStatistics {
        val all = items.flatMap { it.todayDoses }
        val taken = all.count { it.status == AdherenceStatus.TAKEN }
        val missed = all.count { it.status == AdherenceStatus.MISSED }
        val pending = all.count { it.status == AdherenceStatus.PENDING }
        val total = all.size
        return AdherenceStatistics(
            totalDoses = total,
            takenDoses = taken,
            missedDoses = missed,
            pendingDoses = pending,
            adherenceRate = if (total > 0) taken.toFloat() / total else 0f
        )
    }

    private fun buildSchedules(
        medicationId: String,
        profileId: String,
        scheduleType: ScheduleType,
        times: List<String>
    ): List<MedicationScheduleDto> {
        val count = if (scheduleType == ScheduleType.CUSTOM) times.size else scheduleType.dosesPerDay
        val effectiveTimes = if (times.isNotEmpty()) times else listOf("08:00:00")
        return effectiveTimes.take(count.coerceAtLeast(1)).map { time ->
            MedicationScheduleDto(
                id = UUID.randomUUID().toString(),
                medicationId = medicationId,
                healthProfileId = profileId,
                scheduleType = "daily",
                timeOfDay = time.padEnd(8, ':').take(8).let {
                    if (it.length == 5) "$it:00" else it
                },
                frequencyPerDay = count
            )
        }
    }

    /** Optimistic in-memory dose status update */
    private fun updateDoseStatus(dose: MedicationDose, newStatus: AdherenceStatus) {
        val current = _uiState.value
        val updated = current.medicationsWithDoses.map { mwd ->
            if (mwd.medication.id != dose.medicationId) return@map mwd
            val updatedDoses = mwd.todayDoses.map { d ->
                if (d.scheduleId == dose.scheduleId &&
                    d.scheduledTime == dose.scheduledTime
                ) d.copy(status = newStatus) else d
            }
            mwd.copy(todayDoses = updatedDoses)
        }
        _uiState.value = current.copy(
            medicationsWithDoses = updated,
            statistics = computeStats(updated)
        )
    }

    private fun updateDoseLogId(dose: MedicationDose, logId: String) {
        val current = _uiState.value
        val updated = current.medicationsWithDoses.map { mwd ->
            if (mwd.medication.id != dose.medicationId) return@map mwd
            val updatedDoses = mwd.todayDoses.map { d ->
                if (d.scheduleId == dose.scheduleId &&
                    d.scheduledTime == dose.scheduledTime
                ) d.copy(logId = logId) else d
            }
            mwd.copy(todayDoses = updatedDoses)
        }
        _uiState.value = current.copy(medicationsWithDoses = updated)
    }
}
