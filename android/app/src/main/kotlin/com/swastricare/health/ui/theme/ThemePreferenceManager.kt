package com.swastricare.health.ui.theme

import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Calendar
import javax.inject.Inject
import javax.inject.Singleton

enum class ThemeMode(val value: String, val displayName: String, val description: String) {
    LIGHT("light", "Light", "Always light"),
    DARK("dark", "Dark", "Always dark"),
    SYSTEM("system", "System", "Follow device"),
    AUTO("auto", "Auto", "Light 6AM–6PM");

    companion object {
        fun fromValue(value: String): ThemeMode =
            entries.find { it.value == value } ?: SYSTEM
    }
}

@Singleton
class ThemePreferenceManager @Inject constructor(
    private val prefs: SharedPreferences
) {
    private val key = "app_theme_preference"

    private val _themeMode = MutableStateFlow(
        ThemeMode.fromValue(prefs.getString(key, "system") ?: "system")
    )
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    fun setTheme(mode: ThemeMode) {
        prefs.edit().putString(key, mode.value).apply()
        _themeMode.value = mode
    }

    fun isDarkTheme(isSystemDark: Boolean): Boolean {
        return when (_themeMode.value) {
            ThemeMode.LIGHT -> false
            ThemeMode.DARK -> true
            ThemeMode.SYSTEM -> isSystemDark
            ThemeMode.AUTO -> {
                val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
                !(hour in 6..17)
            }
        }
    }
}
