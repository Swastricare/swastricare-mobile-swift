package com.swastricare.health.domain.model.profile

/**
 * Domain model for user settings and preferences.
 */
data class UserSettings(
    val notificationsEnabled: Boolean = true,
    val biometricLockEnabled: Boolean = false,
    val healthSyncEnabled: Boolean = true,
    val darkModeEnabled: Boolean = false,
    val reminderFrequency: ReminderFrequency = ReminderFrequency.MODERATE
) {
    /**
     * Business logic: Check if privacy mode is enabled.
     */
    fun isPrivacyModeEnabled(): Boolean {
        return biometricLockEnabled
    }

    /**
     * Business logic: Check if notifications should show.
     */
    fun shouldShowNotifications(): Boolean {
        return notificationsEnabled
    }

    companion object {
        val Default = UserSettings()
    }
}

/**
 * Reminder frequency preference.
 */
enum class ReminderFrequency(val displayName: String, val dbValue: String) {
    MINIMAL("Minimal", "minimal"),
    MODERATE("Moderate", "moderate"),
    FREQUENT("Frequent", "frequent");

    companion object {
        fun fromDb(value: String): ReminderFrequency {
            return values().find { it.dbValue == value } ?: MODERATE
        }
    }
}
