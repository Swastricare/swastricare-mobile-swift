package com.swastricare.health.ui.screens.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.models.ActivityGoals
import com.swastricare.health.data.repository.ActivityGoalsRepository
import com.swastricare.health.data.repository.ProfileRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ActivityGoalsUiState(
    val goals: ActivityGoals = ActivityGoals(),
    val isLoading: Boolean = true,
    val isSaving: Boolean = false,
    val saveSuccess: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class ActivityGoalsViewModel @Inject constructor(
    private val repository: ActivityGoalsRepository,
    private val profileRepository: ProfileRepository,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(ActivityGoalsUiState())
    val uiState: StateFlow<ActivityGoalsUiState> = _uiState.asStateFlow()

    init {
        loadGoals()
    }

    fun loadGoals() {
        viewModelScope.launch {
            // Local first
            val cached = repository.loadLocalGoals()
            _uiState.value = _uiState.value.copy(goals = cached, isLoading = true)

            // Refresh from cloud
            try {
                val userId = supabaseClient.auth.currentUserOrNull()?.id
                val healthProfileId = if (userId != null) {
                    runCatching { profileRepository.getHealthProfile(userId)?.id }.getOrNull()
                } else null
                if (healthProfileId != null) {
                    val cloud = repository.fetchFromCloud(healthProfileId).getOrNull()
                    if (cloud != null) {
                        _uiState.value = _uiState.value.copy(goals = cloud)
                    }
                }
            } catch (_: Exception) { }
            _uiState.value = _uiState.value.copy(isLoading = false)
        }
    }

    fun updateSteps(value: Int) {
        _uiState.value = _uiState.value.copy(
            goals = _uiState.value.goals.copy(dailyStepsGoal = value.coerceIn(1_000, 50_000))
        )
    }

    fun updateDistanceKm(value: Double) {
        _uiState.value = _uiState.value.copy(
            goals = _uiState.value.goals.copy(
                dailyDistanceMeters = (value * 1000).toInt().coerceIn(500, 50_000)
            )
        )
    }

    fun updateCalories(value: Int) {
        _uiState.value = _uiState.value.copy(
            goals = _uiState.value.goals.copy(dailyCaloriesGoal = value.coerceIn(50, 3_000))
        )
    }

    fun updateActiveMinutes(value: Int) {
        _uiState.value = _uiState.value.copy(
            goals = _uiState.value.goals.copy(dailyActiveMinutes = value.coerceIn(5, 300))
        )
    }

    fun save() {
        val current = _uiState.value.goals
        // Save locally immediately so the activity screen reflects the new goals.
        repository.saveLocalGoals(current)
        _uiState.value = _uiState.value.copy(isSaving = true, saveSuccess = false)

        viewModelScope.launch {
            try {
                val userId = supabaseClient.auth.currentUserOrNull()?.id
                val healthProfileId = if (userId != null) {
                    runCatching { profileRepository.getHealthProfile(userId)?.id }.getOrNull()
                } else null
                if (healthProfileId != null) {
                    repository.upsertToCloud(healthProfileId, current)
                }
                _uiState.value = _uiState.value.copy(isSaving = false, saveSuccess = true)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isSaving = false,
                    error = e.message ?: "Failed to save goals"
                )
            }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    fun clearSaveSuccess() {
        _uiState.value = _uiState.value.copy(saveSuccess = false)
    }
}
