package com.swastricare.health.ui.screens.notifications

import androidx.lifecycle.ViewModel
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
    val dinnerMinute: Int = 30
)

@HiltViewModel
class NotificationSettingsViewModel @Inject constructor(
    private val notifService: NotificationService
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
            dinnerMinute = notifService.dinnerMinute
        )
    }

    fun setHydrationEnabled(enabled: Boolean) {
        notifService.hydrationEnabled = enabled
        _uiState.update { it.copy(hydrationEnabled = enabled) }
        if (enabled) notifService.scheduleHydrationReminders() else notifService.cancelHydrationReminders()
    }

    fun setMedicationEnabled(enabled: Boolean) {
        notifService.medicationEnabled = enabled
        _uiState.update { it.copy(medicationEnabled = enabled) }
    }

    fun setDietEnabled(enabled: Boolean) {
        notifService.dietEnabled = enabled
        _uiState.update { it.copy(dietEnabled = enabled) }
        if (enabled) notifService.scheduleDietReminders() else notifService.cancelDietReminders()
    }

    fun setCycleEnabled(enabled: Boolean) {
        notifService.cycleEnabled = enabled
        _uiState.update { it.copy(cycleEnabled = enabled) }
    }

    fun setAppointmentEnabled(enabled: Boolean) {
        notifService.appointmentEnabled = enabled
        _uiState.update { it.copy(appointmentEnabled = enabled) }
    }

    fun setActivityEnabled(enabled: Boolean) {
        notifService.activityEnabled = enabled
        _uiState.update { it.copy(activityEnabled = enabled) }
    }

    fun setAiNudgeEnabled(enabled: Boolean) {
        notifService.aiNudgeEnabled = enabled
        _uiState.update { it.copy(aiNudgeEnabled = enabled) }
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

    // Test notifications
    fun testHydration() = notifService.showTestNotification(NotificationService.CHANNEL_HYDRATION)
    fun testMedication() = notifService.showTestNotification(NotificationService.CHANNEL_MEDICATION)
    fun testDiet() = notifService.showTestNotification(NotificationService.CHANNEL_DIET)
    fun testCycle() = notifService.showTestNotification(NotificationService.CHANNEL_CYCLE)
    fun testAppointment() = notifService.showTestNotification(NotificationService.CHANNEL_APPOINTMENT)
    fun testActivity() = notifService.showTestNotification(NotificationService.CHANNEL_ACTIVITY)
    fun testAiNudge() = notifService.showTestNotification(NotificationService.CHANNEL_AI_NUDGE)
}
