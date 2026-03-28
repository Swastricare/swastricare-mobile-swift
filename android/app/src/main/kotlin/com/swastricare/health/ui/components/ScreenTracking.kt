package com.swastricare.health.ui.components

import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import com.swastricare.health.data.services.AppAnalyticsService
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent

/**
 * Hilt entry point for accessing AppAnalyticsService from composables.
 */
@EntryPoint
@InstallIn(SingletonComponent::class)
interface ScreenTrackingEntryPoint {
    fun analyticsService(): AppAnalyticsService
}

/**
 * Emits a screen_view event with dwell time when the composable leaves composition.
 * Place at the top of each full-screen composable.
 *
 * Usage: TrackScreen("Hydration")
 */
@Composable
fun TrackScreen(name: String) {
    val context = LocalContext.current
    val analyticsService = remember {
        EntryPointAccessors.fromApplication(
            context.applicationContext,
            ScreenTrackingEntryPoint::class.java
        ).analyticsService()
    }
    val enteredAt = remember { System.currentTimeMillis() }
    DisposableEffect(name) {
        onDispose {
            val durationSeconds = ((System.currentTimeMillis() - enteredAt) / 1000).toInt()
            analyticsService.trackScreen(name, durationSeconds)
        }
    }
}
