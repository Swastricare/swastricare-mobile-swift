package com.swastricare.health.ui.screens.medications

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.UserFriendlyError
import com.swastricare.health.data.models.*
import com.swastricare.health.data.repository.DrugSearchRepository
import com.swastricare.health.data.repository.DrugSearchResult
import com.swastricare.health.data.repository.DrugDetails
import com.swastricare.health.data.repository.SupabaseMedicationRepository
import com.swastricare.health.data.repository.SupabaseProfileRepository
import com.swastricare.health.data.services.AnalyticsService
import com.swastricare.health.data.services.MedicationAlarmScheduler
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.notifications.MedicationReminderScheduler
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.UUID
import javax.inject.Inject

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

@HiltViewModel
class MedicationsViewModel @Inject constructor(
    private val repository: SupabaseMedicationRepository,
    private val profileRepository: SupabaseProfileRepository,
    private val analyticsService: AnalyticsService,
    private val medicationAlarmScheduler: MedicationAlarmScheduler,
    private val authRepository: AuthRepository,
    private val drugSearchRepository: DrugSearchRepository,
    @ApplicationContext private val context: Context
) : ViewModel() {

    companion object {
        private const val TAG = "MedicationsVM"
    }

    private val _uiState = MutableStateFlow(MedicationsUiState(isLoading = true))
    val uiState: StateFlow<MedicationsUiState> = _uiState.asStateFlow()

    // ── Drug Search State ──
    private val _drugSuggestions = MutableStateFlow<List<DrugSearchResult>>(emptyList())
    val drugSuggestions: StateFlow<List<DrugSearchResult>> = _drugSuggestions.asStateFlow()

    private val _drugDetails = MutableStateFlow<DrugDetails?>(null)
    val drugDetails: StateFlow<DrugDetails?> = _drugDetails.asStateFlow()

    private val _isSearching = MutableStateFlow(false)
    val isSearching: StateFlow<Boolean> = _isSearching.asStateFlow()

    private val _addMedicationSuccess = MutableStateFlow<Boolean?>(null)
    val addMedicationSuccess: StateFlow<Boolean?> = _addMedicationSuccess.asStateFlow()

    private var searchJob: Job? = null

    // Resolved from authenticated user

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
            // Only show loading on first load (when no data yet)
            val isFirstLoad = _uiState.value.medicationsWithDoses.isEmpty() && _uiState.value.isLoading
            _uiState.value = _uiState.value.copy(isLoading = isFirstLoad, error = null, selectedDate = date)
            try {
                val profileId = resolveProfileId()
                Log.d(TAG, "loadMedications: profileId=$profileId, date=$date")
                val medications = repository.fetchMedications(profileId)
                val schedules = repository.fetchSchedules(profileId)
                val logs = repository.fetchTodayLogs(profileId, date)
                Log.d(TAG, "loadMedications: ${medications.size} meds, ${schedules.size} schedules, ${logs.size} logs")

                repository.cacheMedications(medications)
                medicationAlarmScheduler.scheduleAll(schedules, medications)

                val withDoses = buildMedicationsWithDoses(medications, schedules, logs, date)
                val stats = computeStats(withDoses)

                _uiState.value = _uiState.value.copy(
                    medicationsWithDoses = withDoses,
                    statistics = stats,
                    selectedDate = date,
                    isLoading = false
                )
            } catch (e: Exception) {
                Log.e(TAG, "loadMedications failed", e)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Unable to load medications. Please try again."
                )
            }
        }
    }

    fun selectDate(date: LocalDate) {
        loadMedications(date)
    }

    fun markAsTaken(dose: MedicationDose) {
        // Block marking future doses as taken
        if (dose.scheduledTime.isAfter(java.time.LocalDateTime.now())) return

        viewModelScope.launch {
            // Log analytics event
            val medName = _uiState.value.medicationsWithDoses
                .firstOrNull { it.medication.id == dose.medicationId }?.medication?.name ?: "unknown"
            analyticsService.logMedicationTaken(medName)

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
            // Log analytics event
            val medName = _uiState.value.medicationsWithDoses
                .firstOrNull { it.medication.id == dose.medicationId }?.medication?.name ?: "unknown"
            analyticsService.logMedicationSkipped(medName, reason)

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

    fun clearAddMedicationResult() {
        _addMedicationSuccess.value = null
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
            try {
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
                    Log.d(TAG, "addMedication: upserting ${schedules.size} schedules for med=${savedMed.id}")
                    val schedResult = repository.upsertSchedules(schedules)
                    if (schedResult.isFailure) {
                        Log.e(TAG, "addMedication: schedule upsert FAILED", schedResult.exceptionOrNull())
                    }

                    // Schedule reminders for each schedule — wrapped so a missing
                    // notification permission does not crash the save flow
                    try {
                        schedules.forEach { schedule ->
                            val parts = schedule.timeOfDay.split(":")
                            val hour = parts.getOrNull(0)?.toIntOrNull() ?: return@forEach
                            val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0
                            MedicationReminderScheduler.schedule(
                                context = context,
                                medId = savedMed.id,
                                scheduleId = schedule.id,
                                medName = savedMed.name,
                                timeHour = hour,
                                timeMinute = minute
                            )
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to schedule reminder: ${e.message}")
                    }

                    _addMedicationSuccess.value = true
                    loadMedications()
                } else {
                    Log.e(TAG, "addMedication: upsert failed", result.exceptionOrNull())
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = "Failed to save medication"
                    )
                    _addMedicationSuccess.value = false
                }
            } catch (e: IllegalStateException) {
                Log.e(TAG, "addMedication: profile resolution failed", e)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Unable to save: health profile not found. Please complete your profile setup."
                )
                _addMedicationSuccess.value = false
            } catch (e: Exception) {
                Log.e(TAG, "addMedication: unexpected error", e)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Failed to save medication. Please try again."
                )
                _addMedicationSuccess.value = false
            }
        }
    }

    fun deleteMedication(medicationId: String) {
        viewModelScope.launch {
            // Grab schedules before deletion so we can cancel their alarms
            val schedulesToCancel = _uiState.value.medicationsWithDoses
                .firstOrNull { it.medication.id == medicationId }
                ?.schedules.orEmpty()

            val result = repository.deleteMedication(medicationId)
            if (result.isSuccess) {
                // Cancel reminders for deleted medication's schedules
                schedulesToCancel.forEach { schedule ->
                    MedicationReminderScheduler.cancel(context, schedule.id)
                }
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
    // MARK: - Drug Search (OpenFDA)
    // ─────────────────────────────────────

    fun searchDrug(query: String) {
        if (query.length < 2) {
            _drugSuggestions.value = emptyList()
            _isSearching.value = false
            return
        }

        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(400) // debounce
            _isSearching.value = true
            drugSearchRepository.searchDrugs(query)
                .onSuccess { _drugSuggestions.value = it }
                .onFailure {
                    Log.d(TAG, "Drug search failed: ${it.message}")
                    _drugSuggestions.value = emptyList()
                }
            _isSearching.value = false
        }
    }

    fun selectDrug(drug: DrugSearchResult) {
        _drugSuggestions.value = emptyList()
        viewModelScope.launch {
            drugSearchRepository.getDrugDetails(drug.brandName)
                .onSuccess { _drugDetails.value = it }
                .onFailure { _drugDetails.value = null }
        }
    }

    fun clearDrugSearch() {
        searchJob?.cancel()
        _drugSuggestions.value = emptyList()
        _drugDetails.value = null
        _isSearching.value = false
    }

    // ─────────────────────────────────────
    // MARK: - Private Helpers
    // ─────────────────────────────────────

    private suspend fun resolveProfileId(): String {
        val userId = authRepository.getCurrentUser()?.id
            ?: throw IllegalStateException("No authenticated user")
        val healthProfile = profileRepository.getHealthProfile(userId)
            ?: throw IllegalStateException("No health profile found")
        return healthProfile.id
            ?: throw IllegalStateException("Health profile has no ID")
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
