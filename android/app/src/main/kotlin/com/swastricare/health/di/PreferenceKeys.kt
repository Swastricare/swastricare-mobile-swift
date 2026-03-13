package com.swastricare.health.di

import androidx.datastore.preferences.core.booleanPreferencesKey

/**
 * DataStore preference keys used across the app.
 */
object PreferenceKeys {
    val ONBOARDING_COMPLETE_KEY = booleanPreferencesKey("onboarding_complete")
    val CONSENT_ACCEPTED_KEY = booleanPreferencesKey("consent_accepted")
}
