package com.swastricare.health.ui.screens.onboarding

import androidx.lifecycle.ViewModel
import com.swastricare.health.data.repository.ProfileRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class HealthProfileViewModel @Inject constructor(
    val profileRepository: ProfileRepository
) : ViewModel()
