package com.swastricare.health.ui.screens.onboarding

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.repository.SupabaseAuthRepository
import com.swastricare.health.di.HEALTH_PROFILE_COMPLETE_KEY
import com.swastricare.health.domain.model.profile.HealthProfile
import com.swastricare.health.domain.repository.ProfileRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.UUID
import javax.inject.Inject

enum class SubmitState { IDLE, SUBMITTING, SUCCESS, ERROR }

data class OnboardingUiState(
    val step: Int = 0,
    val form: OnboardingFormState = OnboardingFormState(),
    val submitState: SubmitState = SubmitState.IDLE,
    val errorMessage: String? = null
)

@HiltViewModel
class OneQuestionOnboardingViewModel @Inject constructor(
    private val authRepository: SupabaseAuthRepository,
    private val profileRepository: ProfileRepository,
    private val dataStore: DataStore<Preferences>,
    private val logger: Logger
) : ViewModel() {

    val totalSteps = 8

    private val _state = MutableStateFlow(OnboardingUiState())
    val state: StateFlow<OnboardingUiState> = _state.asStateFlow()

    fun update(transform: OnboardingFormState.() -> OnboardingFormState) {
        _state.update { it.copy(form = it.form.transform()) }
    }

    fun next() {
        val current = _state.value
        if (!isStepValid(current.step, current.form)) return
        if (current.step < totalSteps - 1) {
            _state.update { it.copy(step = it.step + 1) }
        } else {
            submit()
        }
    }

    fun back() {
        _state.update { current ->
            if (current.step > 0) current.copy(step = current.step - 1) else current
        }
    }

    fun isStepValid(
        step: Int = _state.value.step,
        form: OnboardingFormState = _state.value.form
    ): Boolean {
        return when (step) {
            0 -> form.fullName.isNotBlank()
            1 -> form.gender != null
            2 -> {
                val dob = form.dateOfBirth ?: return false
                val today = LocalDate.now()
                val earliest = today.minusYears(120)
                !dob.isAfter(today) && !dob.isBefore(earliest)
            }
            3 -> form.heightCm in 100..250
            4 -> form.weightKg in 20..250
            5 -> form.primaryGoal != null
            6 -> form.activityLevel != null
            7 -> form.waterIntake != null
            else -> false
        }
    }

    fun retry() {
        _state.update { it.copy(submitState = SubmitState.IDLE, errorMessage = null) }
        submit()
    }

    private fun submit() {
        viewModelScope.launch {
            val userId = authRepository.currentUser?.id
            if (userId == null) {
                _state.update { it.copy(submitState = SubmitState.ERROR, errorMessage = "Not signed in") }
                return@launch
            }

            _state.update { it.copy(submitState = SubmitState.SUBMITTING, errorMessage = null) }

            val form = _state.value.form
            val profile = HealthProfile(
                id = UUID.randomUUID().toString(),
                userId = userId,
                fullName = form.fullName,
                gender = form.gender!!,
                dateOfBirth = form.dateOfBirth!!,
                heightCm = form.heightCm.toDouble(),
                weightKg = form.weightKg.toDouble(),
                bloodType = null
            )

            val result = profileRepository.createHealthProfile(profile)
            if (result is ResultWrapper.Error) {
                val message = result.exception.getUserMessage()
                logger.e("OneQuestionOnboardingViewModel", "createHealthProfile failed: $message")
                _state.update { it.copy(submitState = SubmitState.ERROR, errorMessage = message) }
                return@launch
            }

            // Best-effort: mark onboarding complete in the users table
            runCatching {
                profileRepository.markUserOnboardingComplete(userId, form.fullName)
            }

            // Mark health-profile complete in DataStore
            dataStore.edit { it[HEALTH_PROFILE_COMPLETE_KEY] = true }

            _state.update { it.copy(submitState = SubmitState.SUCCESS) }
        }
    }
}
