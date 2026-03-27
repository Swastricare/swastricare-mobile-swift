package com.swastricare.health.ui.screens.main

import androidx.lifecycle.ViewModel
import com.swastricare.health.data.services.AnalyticsService
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.data.services.NetworkMonitorService
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class MainScreenViewModel @Inject constructor(
    private val firebaseAnalyticsService: AnalyticsService,
    private val appAnalyticsService: AppAnalyticsService,
    val networkMonitor: NetworkMonitorService
) : ViewModel() {

    fun trackScreenView(screenName: String) {
        firebaseAnalyticsService.logScreenView(screenName)
        appAnalyticsService.trackScreenView(screenName)
    }
}
