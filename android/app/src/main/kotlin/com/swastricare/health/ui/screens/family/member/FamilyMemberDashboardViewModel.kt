package com.swastricare.health.ui.screens.family.member

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.repository.HeartRateRepositoryImpl
import com.swastricare.health.domain.model.FamilyMember
import com.swastricare.health.domain.model.FamilyRole
import com.swastricare.health.domain.model.MedicationDoseSummary
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.repository.DietRepository
import com.swastricare.health.domain.repository.FamilyRepository
import com.swastricare.health.domain.repository.HydrationRepository
import com.swastricare.health.domain.repository.MedicationRepository
import com.swastricare.health.domain.repository.SleepRepository
import com.swastricare.health.domain.repository.VaultRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

/**
 * UI state for the family-member dashboard screen.
 *
 * Field-level nulls (`latestHeartRateBpm`, `sleepHours`, `heartRateMeasuredAt`) are
 * meaningful — they signal "no data yet", which the screen renders as a "—" placeholder
 * rather than a crash. Counted fields default to 0.
 */
data class FamilyMemberDashboardState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val member: FamilyMember? = null,
    val canEdit: Boolean = false,

    // Vitals
    val latestHeartRateBpm: Int? = null,
    val heartRateMeasuredAt: String? = null,
    val sleepHours: Double? = null,

    // Today's medications
    val doses: List<MedicationDoseSummary> = emptyList(),
    val adherencePercent: Int = 0,

    // Today's other
    val hydrationMl: Int = 0,
    val hydrationGoalMl: Int = 2500,
    val caloriesToday: Int = 0,

    // Vault
    val vaultDocCount: Int = 0,
    val vaultDocs: List<com.swastricare.health.domain.model.VaultDocSummary> = emptyList(),
)

@HiltViewModel
class FamilyMemberDashboardViewModel @Inject constructor(
    private val familyRepository: FamilyRepository,
    private val medicationRepository: MedicationRepository,
    private val hydrationRepository: HydrationRepository,
    private val heartRateRepository: HeartRateRepositoryImpl,
    private val sleepRepository: SleepRepository,
    private val vaultRepository: VaultRepository,
    private val dietRepository: DietRepository,
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(FamilyMemberDashboardState())
    val state: StateFlow<FamilyMemberDashboardState> = _state.asStateFlow()

    /**
     * Load (or reload) the dashboard for the given health profile.
     * Safe to call repeatedly; emits a fresh loading state each invocation.
     */
    fun load(targetHealthProfileId: String) {
        _state.value = _state.value.copy(isLoading = true, error = null)
        viewModelScope.launch {
            runCatching {
                val today = LocalDate.now()

                val callerUserId = authRepository.getCurrentUser()?.id
                    ?: throw IllegalStateException("Not signed in")

                val group = familyRepository.getMyFamilyGroup(callerUserId).getOrNull()
                    ?: throw IllegalStateException("Not in any family group")

                val members = familyRepository.getMembers(group.id).getOrNull().orEmpty()

                val targetMember = members.firstOrNull { it.healthProfileId == targetHealthProfileId }
                    ?: throw IllegalStateException("Member not found in family")

                val callerMember = members.firstOrNull { it.userId == callerUserId }
                val canEdit = callerMember?.let {
                    it.role == FamilyRole.OWNER || it.role == FamilyRole.ADMIN
                } ?: false

                // Fetch sequentially — small N of calls, simpler error handling than awaitAll.
                val hr = heartRateRepository.getLatestForProfile(targetHealthProfileId).getOrNull()
                val sleep = sleepRepository.getNightSleepHours(targetHealthProfileId, today).getOrNull()
                val hydration = hydrationRepository.getTodayTotalMl(targetHealthProfileId, today).getOrNull() ?: 0
                val doses = medicationRepository.getDosesForDay(targetHealthProfileId, today).getOrNull().orEmpty()
                val calories = dietRepository.getDayCalories(targetHealthProfileId, today).getOrNull() ?: 0
                val vault = vaultRepository.listForProfile(targetHealthProfileId).getOrNull().orEmpty()

                val adherence = if (doses.isEmpty()) 0
                else doses.count { it.status == "taken" } * 100 / doses.size

                _state.value = FamilyMemberDashboardState(
                    isLoading = false,
                    member = targetMember,
                    canEdit = canEdit,
                    latestHeartRateBpm = hr?.bpm,
                    heartRateMeasuredAt = hr?.measuredAt,
                    sleepHours = sleep,
                    doses = doses,
                    adherencePercent = adherence,
                    hydrationMl = hydration,
                    caloriesToday = calories,
                    vaultDocCount = vault.size,
                    vaultDocs = vault,
                )
            }.onFailure { e ->
                _state.value = _state.value.copy(
                    isLoading = false,
                    error = e.message ?: "Unknown error"
                )
            }
        }
    }

    /**
     * Resolve a viewer URL for a vault document and invoke [onResolved] with
     * the result on the main thread. [path] is the storage path stored in
     * `medical_documents.file_url`. Errors are surfaced via [onError].
     */
    fun resolveVaultDocUrl(
        path: String,
        onResolved: (String) -> Unit,
        onError: (String) -> Unit,
    ) {
        viewModelScope.launch {
            when (val r = vaultRepository.getSignedUrl(path)) {
                is ResultWrapper.Success -> onResolved(r.data)
                is ResultWrapper.Error -> onError(r.exception.message ?: "Could not open document")
                else -> Unit
            }
        }
    }
}

/**
 * Extension to bridge stdlib [Result] (used by [MedicationRepository] and
 * [HeartRateRepositoryImpl]) and project [ResultWrapper] in a uniform `getOrNull`
 * call site. Kotlin's stdlib already has `Result.getOrNull()` — this just
 * documents the convention.
 */
private fun <T> ResultWrapper<T>.successOrNull(): T? = getOrNull()
