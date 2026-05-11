package com.swastricare.health.ui.navigation

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.lifecycle.ViewModel
import com.swastricare.health.BuildConfig
import com.swastricare.health.data.services.AppUpdateCheckResult
import com.swastricare.health.data.services.AppVersionService
import com.swastricare.health.data.services.SessionManager
import com.swastricare.health.di.CONSENT_ACCEPTED_KEY
import com.swastricare.health.di.ONBOARDING_COMPLETE_KEY
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class AppNavigationViewModel @Inject constructor(
    private val appVersionService: AppVersionService,
    val sessionManager: SessionManager,
    private val dataStore: DataStore<Preferences>
) : ViewModel() {

    val currentVersionName: String = BuildConfig.VERSION_NAME
    val currentVersionCode: Int = BuildConfig.VERSION_CODE

    suspend fun checkForUpdate(): AppUpdateCheckResult? {
        return try {
            // Always hit the server — check every time the app launches/resumes
            appVersionService.checkForUpdate(currentVersionName, currentVersionCode, forceRefresh = true)
        } catch (_: Exception) {
            null
        }
    }

    fun shouldShowOptionalUpdate(): Boolean = appVersionService.shouldShowOptionalUpdate()

    fun dismissOptionalUpdate() = appVersionService.dismissOptionalUpdate()

    suspend fun markOnboardingComplete() {
        dataStore.edit {
            it[CONSENT_ACCEPTED_KEY] = true
            it[ONBOARDING_COMPLETE_KEY] = true
        }
    }
}
