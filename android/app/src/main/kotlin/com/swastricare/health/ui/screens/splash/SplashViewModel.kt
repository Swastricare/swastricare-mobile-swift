package com.swastricare.health.ui.screens.splash

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.lifecycle.ViewModel
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.repository.HomeDataPreloader
import com.swastricare.health.data.repository.SupabaseAuthRepository
import com.swastricare.health.di.HEALTH_PROFILE_COMPLETE_KEY
import com.swastricare.health.di.ONBOARDING_COMPLETE_KEY
import com.swastricare.health.domain.repository.ProfileRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.first
import javax.inject.Inject

@HiltViewModel
class SplashViewModel @Inject constructor(
    private val dataStore: DataStore<Preferences>,
    private val authRepository: SupabaseAuthRepository,
    private val homeDataPreloader: HomeDataPreloader,
    private val profileRepository: ProfileRepository
) : ViewModel() {

    suspend fun isOnboardingComplete(): Boolean {
        val prefs = dataStore.data.first()
        return prefs[ONBOARDING_COMPLETE_KEY] ?: false
    }

    fun isAuthenticated(): Boolean = authRepository.currentUser != null

    suspend fun isHealthProfileComplete(): Boolean {
        // Check the persisted flag FIRST, before any auth check.
        // On warm resume from recents, Supabase can still be in LoadingFromStorage
        // and currentUser is transiently null — we'd otherwise bounce a user with a
        // completed profile back into onboarding.
        val prefs = dataStore.data.first()
        if (prefs[HEALTH_PROFILE_COMPLETE_KEY] == true) return true
        val userId = authRepository.currentUser?.id ?: return false
        val result = profileRepository.getHealthProfile(userId)
        if (result is ResultWrapper.Success && result.data != null) {
            markHealthProfileComplete()
            return true
        }
        return false
    }

    suspend fun markHealthProfileComplete() {
        dataStore.edit { it[HEALTH_PROFILE_COMPLETE_KEY] = true }
    }

    /**
     * Kick off the home-data fetch so it overlaps with the intro video.
     * No-op when the user isn't authenticated (nothing to fetch).
     */
    suspend fun preloadHomeData() {
        if (isAuthenticated()) {
            homeDataPreloader.preload()
        }
    }
}
