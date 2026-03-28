package com.swastricare.health.ui.screens.notifications

import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.data.services.NotificationService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import javax.inject.Inject

data class NotificationSettingsState(
    val hydrationEnabled: Boolean = true,
    val medicationEnabled: Boolean = true,
    val dietEnabled: Boolean = true,
    val cycleEnabled: Boolean = false,
    val appointmentEnabled: Boolean = true,
    val activityEnabled: Boolean = true,
    val aiNudgeEnabled: Boolean = true,
    val hydrationIntervalMinutes: Int = 60,
    val quietStart: Int = 22,
    val quietEnd: Int = 7,
    val breakfastHour: Int = 8,
    val breakfastMinute: Int = 0,
    val lunchHour: Int = 12,
    val lunchMinute: Int = 30,
    val dinnerHour: Int = 19,
    val dinnerMinute: Int = 30,
    // Medication detailed settings
    val medicationReminderBeforeMinutes: Int = 15,
    val missedDoseFollowUp: Boolean = true,
    val medicationSnoozeMinutes: Int = 15,
    // Menstrual detailed settings
    val periodPredictionEnabled: Boolean = true,
    val periodPredictionDaysBefore: Int = 2,
    val dailySymptomCheckIn: Boolean = true,
    val ovulationAlertEnabled: Boolean = true,
    val cycleSummaryEnabled: Boolean = true,
    // AI Nudge detailed settings
    val aiNudgeFrequencyPerDay: Int = 2
)

@HiltViewModel
class NotificationSettingsViewModel @Inject constructor(
    private val notifService: NotificationService,
    private val prefs: SharedPreferences,
    private val analyticsService: AppAnalyticsService
) : ViewModel() {

    private val _uiState = MutableStateFlow(loadFromService())
    val uiState: StateFlow<NotificationSettingsState> = _uiState.asStateFlow()

    private fun loadFromService(): NotificationSettingsState {
        return NotificationSettingsState(
            hydrationEnabled = notifService.hydrationEnabled,
            medicationEnabled = notifService.medicationEnabled,
            dietEnabled = notifService.dietEnabled,
            cycleEnabled = notifService.cycleEnabled,
            appointmentEnabled = notifService.appointmentEnabled,
            activityEnabled = notifService.activityEnabled,
            aiNudgeEnabled = notifService.aiNudgeEnabled,
            hydrationIntervalMinutes = notifService.hydrationIntervalMinutes,
            quietStart = notifService.quietHoursStart,
            quietEnd = notifService.quietHoursEnd,
            breakfastHour = notifService.breakfastHour,
            breakfastMinute = notifService.breakfastMinute,
            lunchHour = notifService.lunchHour,
            lunchMinute = notifService.lunchMinute,
            dinnerHour = notifService.dinnerHour,
            dinnerMinute = notifService.dinnerMinute,
            // Medication detailed
            medicationReminderBeforeMinutes = prefs.getInt("medication_before_minutes", 15),
            missedDoseFollowUp = prefs.getBoolean("missed_dose_followup", true),
            medicationSnoozeMinutes = prefs.getInt("medication_snooze_minutes", 15),
            // Menstrual detailed
            periodPredictionEnabled = prefs.getBoolean("period_prediction_enabled", true),
            periodPredictionDaysBefore = prefs.getInt("period_prediction_days", 2),
            dailySymptomCheckIn = prefs.getBoolean("daily_symptom_checkin", true),
            ovulationAlertEnabled = prefs.getBoolean("ovulation_alert_enabled", true),
            cycleSummaryEnabled = prefs.getBoolean("cycle_summary_enabled", true),
            // AI Nudge detailed
            aiNudgeFrequencyPerDay = prefs.getInt("ai_nudge_frequency", 2)
        )
    }

    fun setHydrationEnabled(enabled: Boolean) {
        notifService.hydrationEnabled = enabled
        _uiState.update { it.copy(hydrationEnabled = enabled) }
        if (enabled) notifService.scheduleHydrationReminders() else notifService.cancelHydrationReminders()
        analyticsService.trackNotificationToggled("hydration", enabled)
    }

    fun setMedicationEnabled(enabled: Boolean) {
        notifService.medicationEnabled = enabled
        _uiState.update { it.copy(medicationEnabled = enabled) }
        analyticsService.trackNotificationToggled("medication", enabled)
    }

    fun setDietEnabled(enabled: Boolean) {
        notifService.dietEnabled = enabled
        _uiState.update { it.copy(dietEnabled = enabled) }
        if (enabled) notifService.scheduleDietReminders() else notifService.cancelDietReminders()
        analyticsService.trackNotificationToggled("diet", enabled)
    }

    fun setCycleEnabled(enabled: Boolean) {
        notifService.cycleEnabled = enabled
        _uiState.update { it.copy(cycleEnabled = enabled) }
        analyticsService.trackNotificationToggled("cycle", enabled)
    }

    fun setAppointmentEnabled(enabled: Boolean) {
        notifService.appointmentEnabled = enabled
        _uiState.update { it.copy(appointmentEnabled = enabled) }
        analyticsService.trackNotificationToggled("appointment", enabled)
    }

    fun setActivityEnabled(enabled: Boolean) {
        notifService.activityEnabled = enabled
        _uiState.update { it.copy(activityEnabled = enabled) }
        analyticsService.trackNotificationToggled("activity", enabled)
    }

    fun setAiNudgeEnabled(enabled: Boolean) {
        notifService.aiNudgeEnabled = enabled
        _uiState.update { it.copy(aiNudgeEnabled = enabled) }
        analyticsService.trackNotificationToggled("ai_nudge", enabled)
    }

    fun setHydrationInterval(minutes: Int) {
        notifService.hydrationIntervalMinutes = minutes
        _uiState.update { it.copy(hydrationIntervalMinutes = minutes) }
        notifService.scheduleHydrationReminders()
    }

    fun setQuietStart(hour: Int) {
        notifService.quietHoursStart = hour
        _uiState.update { it.copy(quietStart = hour) }
        notifService.scheduleHydrationReminders()
    }

    fun setQuietEnd(hour: Int) {
        notifService.quietHoursEnd = hour
        _uiState.update { it.copy(quietEnd = hour) }
        notifService.scheduleHydrationReminders()
    }

    fun setBreakfastTime(hour: Int, minute: Int) {
        notifService.breakfastHour = hour
        notifService.breakfastMinute = minute
        _uiState.update { it.copy(breakfastHour = hour, breakfastMinute = minute) }
        notifService.scheduleDietReminders()
    }

    fun setLunchTime(hour: Int, minute: Int) {
        notifService.lunchHour = hour
        notifService.lunchMinute = minute
        _uiState.update { it.copy(lunchHour = hour, lunchMinute = minute) }
        notifService.scheduleDietReminders()
    }

    fun setDinnerTime(hour: Int, minute: Int) {
        notifService.dinnerHour = hour
        notifService.dinnerMinute = minute
        _uiState.update { it.copy(dinnerHour = hour, dinnerMinute = minute) }
        notifService.scheduleDietReminders()
    }

    // ── Medication detailed setters ──

    fun setMedicationReminderBefore(minutes: Int) {
        prefs.edit().putInt("medication_before_minutes", minutes).apply()
        _uiState.update { it.copy(medicationReminderBeforeMinutes = minutes) }
    }

    fun setMissedDoseFollowUp(enabled: Boolean) {
        prefs.edit().putBoolean("missed_dose_followup", enabled).apply()
        _uiState.update { it.copy(missedDoseFollowUp = enabled) }
    }

    fun setMedicationSnoozeMinutes(minutes: Int) {
        prefs.edit().putInt("medication_snooze_minutes", minutes).apply()
        _uiState.update { it.copy(medicationSnoozeMinutes = minutes) }
    }

    // ── Menstrual detailed setters ──

    fun setPeriodPredictionEnabled(enabled: Boolean) {
        prefs.edit().putBoolean("period_prediction_enabled", enabled).apply()
        _uiState.update { it.copy(periodPredictionEnabled = enabled) }
    }

    fun setPeriodPredictionDaysBefore(days: Int) {
        prefs.edit().putInt("period_prediction_days", days).apply()
        _uiState.update { it.copy(periodPredictionDaysBefore = days) }
    }

    fun setDailySymptomCheckIn(enabled: Boolean) {
        prefs.edit().putBoolean("daily_symptom_checkin", enabled).apply()
        _uiState.update { it.copy(dailySymptomCheckIn = enabled) }
    }

    fun setOvulationAlertEnabled(enabled: Boolean) {
        prefs.edit().putBoolean("ovulation_alert_enabled", enabled).apply()
        _uiState.update { it.copy(ovulationAlertEnabled = enabled) }
    }

    fun setCycleSummaryEnabled(enabled: Boolean) {
        prefs.edit().putBoolean("cycle_summary_enabled", enabled).apply()
        _uiState.update { it.copy(cycleSummaryEnabled = enabled) }
    }

    // ── AI Nudge detailed setters ──

    fun setAiNudgeFrequencyPerDay(frequency: Int) {
        prefs.edit().putInt("ai_nudge_frequency", frequency).apply()
        _uiState.update { it.copy(aiNudgeFrequencyPerDay = frequency) }
    }

    // Test notifications
    fun testHydration() = notifService.showTestNotification(NotificationService.CHANNEL_HYDRATION)
    fun testMedication() = notifService.showTestNotification(NotificationService.CHANNEL_MEDICATION)
    fun testDiet() = notifService.showTestNotification(NotificationService.CHANNEL_DIET)
    fun testCycle() = notifService.showTestNotification(NotificationService.CHANNEL_CYCLE)
    fun testAppointment() = notifService.showTestNotification(NotificationService.CHANNEL_APPOINTMENT)
    fun testActivity() = notifService.showTestNotification(NotificationService.CHANNEL_ACTIVITY)
    fun testAiNudge() = notifService.showTestNotification(NotificationService.CHANNEL_AI_NUDGE)
}
