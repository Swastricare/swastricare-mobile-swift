package com.swastricare.health.ui.screens.splash

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.lifecycle.ViewModel
import com.swastricare.health.di.ONBOARDING_COMPLETE_KEY
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.first
import javax.inject.Inject

@HiltViewModel
class SplashViewModel @Inject constructor(
    private val dataStore: DataStore<Preferences>
) : ViewModel() {

    suspend fun isOnboardingComplete(): Boolean {
        val prefs = dataStore.data.first()
        return prefs[ONBOARDING_COMPLETE_KEY] ?: false
    }
}
