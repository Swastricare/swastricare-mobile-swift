# Android Full Notification System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete Android notification system covering hydration, medication, diet, cycle, appointments, activity, and AI-generated nudges — with runtime permission handling, WorkManager resilience, and history tracking.

**Architecture:** Hybrid — AlarmManager for time-critical local notifications (medication, hydration, diet, cycle, appointments, activity), WorkManager for resilient polling of AI nudges from Supabase and daily activity checks. All shown notifications are saved to SharedPrefs history.

**Tech Stack:** Kotlin, AlarmManager, WorkManager (androidx.work:work-runtime-ktx:2.9.0), Supabase Kotlin client, Jetpack Compose, Material3

---

## Task 1: Add WorkManager dependency + 3 new notification channels

**Files:**
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/NotificationService.kt`

**Step 1: Add WorkManager to build.gradle.kts**

In the `dependencies` block, after the DataStore line, add:
```kotlin
// WorkManager — resilient background scheduling for AI nudges + activity checks
implementation("androidx.work:work-runtime-ktx:2.9.0")
```

**Step 2: Add 3 new channels + constants to NotificationService.kt**

Add to the `companion object`:
```kotlin
// New channels
const val CHANNEL_APPOINTMENT = "appointment_reminders"
const val CHANNEL_ACTIVITY = "activity_reminders"
const val CHANNEL_AI_NUDGE = "ai_nudges"

// New notification IDs
const val NOTIF_APPOINTMENT_DAY_BASE = 5000   // +appointmentId.hashCode()
const val NOTIF_APPOINTMENT_HOUR_BASE = 5500  // +appointmentId.hashCode()
const val NOTIF_ACTIVITY_DAILY = 6001
const val NOTIF_AI_NUDGE_BASE = 7000

// New actions
const val ACTION_APPOINTMENT_DISMISS = "com.swasthicare.ACTION_APPOINTMENT_DISMISS"
const val ACTION_ACTIVITY_START = "com.swasthicare.ACTION_ACTIVITY_START"
const val ACTION_NUDGE_DISMISS = "com.swasthicare.ACTION_NUDGE_DISMISS"

// New pref keys
const val PREF_APPOINTMENT_ENABLED = "notif_appointment_enabled"
const val PREF_ACTIVITY_ENABLED = "notif_activity_enabled"
const val PREF_AI_NUDGE_ENABLED = "notif_ai_nudge_enabled"
const val PREF_ACTIVITY_GOAL_STEPS = "notif_activity_goal_steps"
```

Add to `createNotificationChannels()` inside the existing `channels` list:
```kotlin
NotificationChannel(
    CHANNEL_APPOINTMENT,
    "Appointment Reminders",
    NotificationManager.IMPORTANCE_HIGH
).apply { description = "Reminders for upcoming doctor appointments" },

NotificationChannel(
    CHANNEL_ACTIVITY,
    "Activity Reminders",
    NotificationManager.IMPORTANCE_DEFAULT
).apply { description = "Daily activity and step count reminders" },

NotificationChannel(
    CHANNEL_AI_NUDGE,
    "AI Health Coach",
    NotificationManager.IMPORTANCE_DEFAULT
).apply { description = "Personalized AI health nudges" },
```

Add new prefs properties to NotificationService:
```kotlin
var appointmentEnabled: Boolean
    get() = prefs.getBoolean(PREF_APPOINTMENT_ENABLED, true)
    set(value) { prefs.edit().putBoolean(PREF_APPOINTMENT_ENABLED, value).apply() }

var activityEnabled: Boolean
    get() = prefs.getBoolean(PREF_ACTIVITY_ENABLED, true)
    set(value) { prefs.edit().putBoolean(PREF_ACTIVITY_ENABLED, value).apply() }

var aiNudgeEnabled: Boolean
    get() = prefs.getBoolean(PREF_AI_NUDGE_ENABLED, true)
    set(value) { prefs.edit().putBoolean(PREF_AI_NUDGE_ENABLED, value).apply() }

var activityGoalSteps: Int
    get() = prefs.getInt(PREF_ACTIVITY_GOAL_STEPS, 8000)
    set(value) { prefs.edit().putInt(PREF_ACTIVITY_GOAL_STEPS, value).apply() }
```

**Step 3: Verify build**
```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```
Expected: `BUILD SUCCESSFUL`

---

## Task 2: Fix showNotification() to persist to history

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/NotificationService.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/notifications/NotificationHistoryScreen.kt`

**Step 1: Map channel ID to NotificationCategory**

In `NotificationService.kt`, add a private helper inside the class (not companion):
```kotlin
private fun channelToCategory(channelId: String): com.swasthicare.mobile.ui.screens.notifications.NotificationCategory {
    return when (channelId) {
        CHANNEL_HYDRATION -> com.swasthicare.mobile.ui.screens.notifications.NotificationCategory.HYDRATION
        CHANNEL_MEDICATION -> com.swasthicare.mobile.ui.screens.notifications.NotificationCategory.MEDICATION
        CHANNEL_DIET -> com.swasthicare.mobile.ui.screens.notifications.NotificationCategory.DIET
        CHANNEL_CYCLE -> com.swasthicare.mobile.ui.screens.notifications.NotificationCategory.CYCLE
        CHANNEL_APPOINTMENT -> com.swasthicare.mobile.ui.screens.notifications.NotificationCategory.APPOINTMENT
        CHANNEL_ACTIVITY -> com.swasthicare.mobile.ui.screens.notifications.NotificationCategory.ACTIVITY
        CHANNEL_AI_NUDGE -> com.swasthicare.mobile.ui.screens.notifications.NotificationCategory.AI_NUDGE
        else -> com.swasthicare.mobile.ui.screens.notifications.NotificationCategory.GENERAL
    }
}
```

**Step 2: Add history save call at the top of showNotification()**

At the beginning of `showNotification()`, before the builder, add:
```kotlin
// Persist to notification history
com.swasthicare.mobile.ui.screens.notifications.NotificationHistoryViewModel.saveNotification(
    prefs, title, body, channelToCategory(channelId)
)
```

**Step 3: Add new categories to NotificationCategory enum**

In `NotificationHistoryScreen.kt`, update the `NotificationCategory` enum:
```kotlin
@Serializable
enum class NotificationCategory(val displayName: String, val icon: String, val colorHex: Long) {
    HYDRATION("Hydration", "💧", 0xFF00BCD4),
    MEDICATION("Medication", "💊", 0xFF4CAF50),
    DIET("Diet", "🥗", 0xFFFF9800),
    CYCLE("Cycle", "🌸", 0xFFE91E63),
    APPOINTMENT("Appointment", "🏥", 0xFF9C27B0),
    ACTIVITY("Activity", "🏃", 0xFF2196F3),
    AI_NUDGE("AI Coach", "🤖", 0xFF00BCD4),
    GENERAL("General", "🔔", 0xFF607D8B);
}
```

**Step 4: Build and verify no errors**
```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

---

## Task 3: NotificationPermissionManager

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/NotificationPermissionManager.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/MainActivity.kt`

**Step 1: Create NotificationPermissionManager.kt**

```kotlin
package com.swasthicare.mobile.data.services

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.activity.result.ActivityResultLauncher
import androidx.core.net.toUri

/**
 * Handles runtime permission requests for notifications and exact alarms.
 * Call requestIfNeeded() from MainActivity after login.
 */
object NotificationPermissionManager {

    /** Returns true if POST_NOTIFICATIONS is granted (always true below API 33). */
    fun hasNotificationPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    /** Returns true if exact alarms can be scheduled. */
    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    /** Opens system notification settings for this app. */
    fun openNotificationSettings(context: Context) {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    /** Opens exact alarm permission settings (Android 12+). */
    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = "package:${context.packageName}".toUri()
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        }
    }
}
```

**Step 2: Add permission request to MainActivity**

In `MainActivity.kt`, find the `onCreate` method and add after `setContent`:
```kotlin
// Request POST_NOTIFICATIONS at runtime for Android 13+
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
    if (!NotificationPermissionManager.hasNotificationPermission(this)) {
        requestPermissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
    }
}
```

Add the launcher as a class property (before onCreate):
```kotlin
private val requestPermissionLauncher = registerForActivityResult(
    androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
) { granted ->
    if (granted) {
        // Permission granted — schedule all notifications now
        CoroutineScope(Dispatchers.Default).launch {
            AppContainer.notificationService.scheduleAllNotifications()
        }
    }
}
```

Add required imports: `import kotlinx.coroutines.CoroutineScope`, `import kotlinx.coroutines.Dispatchers`, `import kotlinx.coroutines.launch`, `import com.swasthicare.mobile.data.services.NotificationPermissionManager`, `import android.os.Build`

**Step 3: Build verify**
```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

---

## Task 4: MedicationAlarmScheduler

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/MedicationAlarmScheduler.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/NotificationReceiver.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/NotificationService.kt`

**Step 1: Create MedicationAlarmScheduler.kt**

```kotlin
package com.swasthicare.mobile.data.services

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import com.swasthicare.mobile.data.models.MedicationDto
import com.swasthicare.mobile.data.models.MedicationScheduleDto
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

/**
 * Schedules/cancels AlarmManager alarms for medication schedules.
 * One alarm per active MedicationSchedule, fires at the schedule's time_of_day.
 * The receiver re-schedules the next occurrence after each fire.
 */
class MedicationAlarmScheduler(private val context: Context) {

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    companion object {
        private const val TAG = "MedAlarmScheduler"
        const val ACTION_MEDICATION_REMINDER = "MEDICATION_REMINDER"
        const val EXTRA_SCHEDULE_ID = "schedule_id"
        const val EXTRA_MEDICATION_ID = "medication_id"
        const val EXTRA_MEDICATION_NAME = "medication_name"
        const val EXTRA_DOSAGE = "dosage"
        // Base request code for medication alarms (must not overlap other alarm IDs)
        private const val MED_ALARM_REQUEST_BASE = 10000
    }

    /** Schedule alarms for all active schedules. */
    fun scheduleAll(schedules: List<MedicationScheduleDto>, medications: List<MedicationDto>) {
        val medMap = medications.associateBy { it.id }
        schedules.filter { it.isActive && it.reminderEnabled }.forEach { schedule ->
            val med = medMap[schedule.medicationId] ?: return@forEach
            scheduleNext(schedule, med.name, med.dosage ?: "")
        }
        Log.d(TAG, "Scheduled ${schedules.size} medication alarms")
    }

    /** Schedule the next occurrence of a single medication schedule. */
    fun scheduleNext(schedule: MedicationScheduleDto, medName: String, dosage: String) {
        val requestCode = MED_ALARM_REQUEST_BASE + schedule.id.hashCode()

        val triggerMs = nextTriggerMs(schedule) ?: run {
            Log.d(TAG, "No next trigger for schedule ${schedule.id}")
            return
        }

        val intent = Intent(context, NotificationReceiver::class.java).apply {
            action = ACTION_MEDICATION_REMINDER
            putExtra(EXTRA_SCHEDULE_ID, schedule.id)
            putExtra(EXTRA_MEDICATION_ID, schedule.medicationId)
            putExtra(EXTRA_MEDICATION_NAME, medName)
            putExtra(EXTRA_DOSAGE, dosage)
        }

        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
            Log.d(TAG, "Medication alarm set for $medName at ${java.util.Date(triggerMs)}")
        } catch (e: SecurityException) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
        }
    }

    /** Cancel alarm for a specific schedule. */
    fun cancel(scheduleId: String) {
        val requestCode = MED_ALARM_REQUEST_BASE + scheduleId.hashCode()
        val intent = Intent(context, NotificationReceiver::class.java).apply {
            action = ACTION_MEDICATION_REMINDER
        }
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pi)
    }

    /** Cancel all medication alarms (used when med notifications disabled). */
    fun cancelAll(schedules: List<MedicationScheduleDto>) {
        schedules.forEach { cancel(it.id) }
    }

    // Returns next trigger time in millis, or null if schedule has no future occurrence
    private fun nextTriggerMs(schedule: MedicationScheduleDto): Long? {
        val now = LocalDateTime.now()
        val timeOfDay = try {
            LocalTime.parse(schedule.timeOfDay.take(5)) // "HH:mm" from "HH:mm:ss"
        } catch (e: Exception) {
            Log.w(TAG, "Invalid timeOfDay for schedule ${schedule.id}: ${schedule.timeOfDay}")
            return null
        }

        // Start from today at the scheduled time
        var candidate = LocalDateTime.of(LocalDate.now(), timeOfDay)
        if (!candidate.isAfter(now)) {
            candidate = candidate.plusDays(1)
        }

        // For weekly schedules, find the next matching day
        if (schedule.scheduleType == "weekly" && schedule.daysOfWeek != null) {
            for (i in 0..6) {
                val dayOfWeek = candidate.dayOfWeek.value % 7 // 0=Sunday
                if (schedule.daysOfWeek.contains(dayOfWeek)) break
                candidate = candidate.plusDays(1)
            }
        }

        return candidate.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
    }
}
```

**Step 2: Add MedicationScheduleDto fields needed**

Check `android/app/src/main/kotlin/com/swasthicare/mobile/data/models/` for `MedicationScheduleDto`. Ensure it has:
```kotlin
@SerialName("is_active") val isActive: Boolean = true,
@SerialName("reminder_enabled") val reminderEnabled: Boolean = true,
@SerialName("time_of_day") val timeOfDay: String,
@SerialName("schedule_type") val scheduleType: String = "daily",
@SerialName("days_of_week") val daysOfWeek: List<Int>? = null,
@SerialName("medication_id") val medicationId: String,
```
Add any missing fields with `ignoreUnknownKeys = true` already set in the repo JSON config.

**Step 3: Add MEDICATION_REMINDER handling to NotificationReceiver**

In `NotificationReceiver.kt`, inside the `when (intent.action)` block, add after the CYCLE_REMINDER case:

```kotlin
MedicationAlarmScheduler.ACTION_MEDICATION_REMINDER -> {
    val scheduleId = intent.getStringExtra(MedicationAlarmScheduler.EXTRA_SCHEDULE_ID) ?: return
    val medicationId = intent.getStringExtra(MedicationAlarmScheduler.EXTRA_MEDICATION_ID) ?: ""
    val medName = intent.getStringExtra(MedicationAlarmScheduler.EXTRA_MEDICATION_NAME) ?: "Medication"
    val dosage = intent.getStringExtra(MedicationAlarmScheduler.EXTRA_DOSAGE) ?: ""
    Log.d(TAG, "Medication reminder: $medName ($dosage)")

    val markTakenIntent = Intent(context, NotificationReceiver::class.java).apply {
        action = NotificationService.ACTION_MARK_MED_TAKEN
        putExtra("medication_id", medicationId)
        putExtra("schedule_id", scheduleId)
    }
    val markTakenPI = PendingIntent.getBroadcast(
        context,
        scheduleId.hashCode(),
        markTakenIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val tapIntent = Intent(context, com.swasthicare.mobile.MainActivity::class.java).apply {
        data = android.net.Uri.parse("swastricare://medications")
        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
    }
    val tapPI = PendingIntent.getActivity(
        context, scheduleId.hashCode() + 1, tapIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    notificationService.showNotification(
        channelId = NotificationService.CHANNEL_MEDICATION,
        notificationId = NotificationService.NOTIF_HYDRATION_BASE + scheduleId.hashCode(),
        title = "Time for $medName",
        body = if (dosage.isNotBlank()) "Take $dosage now" else "It's time to take your medication",
        actionLabel = "Mark Taken",
        actionIntent = markTakenPI,
        contentIntent = tapPI
    )
}
```

**Step 4: Implement ACTION_MARK_MED_TAKEN in receiver**

Replace the existing stub in NotificationReceiver with:
```kotlin
NotificationService.ACTION_MARK_MED_TAKEN -> {
    val medicationId = intent.getStringExtra("medication_id") ?: return
    val scheduleId = intent.getStringExtra("schedule_id") ?: return
    Log.d(TAG, "Quick action: mark medication $medicationId taken")
    kotlinx.coroutines.GlobalScope.launch {
        try {
            AppContainer.medicationRepository.markAsTaken(
                medicationId = medicationId,
                scheduleId = scheduleId,
                profileId = AppContainer.sharedPreferences.getString("current_profile_id", "") ?: "",
                scheduledTime = java.time.LocalDateTime.now(),
                logId = null
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to mark med taken: ${e.message}")
        }
    }
}
```

**Step 5: Add contentIntent parameter to showNotification()**

In `NotificationService.kt`, update the `showNotification` signature to accept an optional `contentIntent`:
```kotlin
fun showNotification(
    channelId: String,
    notificationId: Int,
    title: String,
    body: String,
    actionLabel: String? = null,
    actionIntent: PendingIntent? = null,
    contentIntent: PendingIntent? = null  // ADD THIS
) {
```

And inside the builder add:
```kotlin
if (contentIntent != null) {
    builder.setContentIntent(contentIntent)
}
```

**Step 6: Build verify**
```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

---

## Task 5: AppointmentAlarmScheduler

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/AppointmentAlarmScheduler.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/NotificationReceiver.kt`

**Step 1: Create AppointmentAlarmScheduler.kt**

```kotlin
package com.swasthicare.mobile.data.services

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter

/**
 * Schedules 2 alarms per upcoming appointment: 24h before and 1h before.
 * Called after vault/appointment sync and on boot.
 */
class AppointmentAlarmScheduler(private val context: Context) {

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    companion object {
        private const val TAG = "ApptAlarmScheduler"
        const val ACTION_APPOINTMENT_REMINDER = "APPOINTMENT_REMINDER"
        const val EXTRA_APPOINTMENT_ID = "appointment_id"
        const val EXTRA_DOCTOR_NAME = "doctor_name"
        const val EXTRA_LOCATION = "location"
        const val EXTRA_IS_DAY_BEFORE = "is_day_before"
        private const val APPT_DAY_BASE = 5000
        private const val APPT_HOUR_BASE = 5500
    }

    data class AppointmentInfo(
        val id: String,
        val scheduledAtIso: String,   // ISO-8601 string from Supabase
        val doctorName: String,
        val location: String = ""
    )

    fun scheduleAll(appointments: List<AppointmentInfo>) {
        appointments.forEach { schedule(it) }
        Log.d(TAG, "Scheduled reminders for ${appointments.size} appointments")
    }

    fun schedule(appt: AppointmentInfo) {
        val apptTime = try {
            ZonedDateTime.parse(appt.scheduledAtIso)
        } catch (e: Exception) {
            Log.w(TAG, "Invalid appointment time: ${appt.scheduledAtIso}")
            return
        }

        val now = ZonedDateTime.now()
        val dayBefore = apptTime.minusHours(24)
        val hourBefore = apptTime.minusHours(1)

        if (dayBefore.isAfter(now)) {
            setAlarm(appt, dayBefore.toInstant().toEpochMilli(), isDayBefore = true)
        }
        if (hourBefore.isAfter(now)) {
            setAlarm(appt, hourBefore.toInstant().toEpochMilli(), isDayBefore = false)
        }
    }

    fun cancel(appointmentId: String) {
        cancelAlarm(appointmentId, isDayBefore = true)
        cancelAlarm(appointmentId, isDayBefore = false)
    }

    private fun setAlarm(appt: AppointmentInfo, triggerMs: Long, isDayBefore: Boolean) {
        val requestCode = (if (isDayBefore) APPT_DAY_BASE else APPT_HOUR_BASE) + appt.id.hashCode()
        val intent = buildIntent(appt, isDayBefore)
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
        } catch (e: SecurityException) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
        }
    }

    private fun cancelAlarm(appointmentId: String, isDayBefore: Boolean) {
        val requestCode = (if (isDayBefore) APPT_DAY_BASE else APPT_HOUR_BASE) + appointmentId.hashCode()
        val intent = Intent(context, NotificationReceiver::class.java).apply {
            action = ACTION_APPOINTMENT_REMINDER
        }
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pi)
    }

    private fun buildIntent(appt: AppointmentInfo, isDayBefore: Boolean): Intent {
        return Intent(context, NotificationReceiver::class.java).apply {
            action = ACTION_APPOINTMENT_REMINDER
            putExtra(EXTRA_APPOINTMENT_ID, appt.id)
            putExtra(EXTRA_DOCTOR_NAME, appt.doctorName)
            putExtra(EXTRA_LOCATION, appt.location)
            putExtra(EXTRA_IS_DAY_BEFORE, isDayBefore)
        }
    }
}
```

**Step 2: Handle APPOINTMENT_REMINDER in NotificationReceiver**

Add to the `when` block:
```kotlin
AppointmentAlarmScheduler.ACTION_APPOINTMENT_REMINDER -> {
    val apptId = intent.getStringExtra(AppointmentAlarmScheduler.EXTRA_APPOINTMENT_ID) ?: return
    val doctorName = intent.getStringExtra(AppointmentAlarmScheduler.EXTRA_DOCTOR_NAME) ?: "Doctor"
    val location = intent.getStringExtra(AppointmentAlarmScheduler.EXTRA_LOCATION) ?: ""
    val isDayBefore = intent.getBooleanExtra(AppointmentAlarmScheduler.EXTRA_IS_DAY_BEFORE, false)

    val tapIntent = Intent(context, com.swasthicare.mobile.MainActivity::class.java).apply {
        data = android.net.Uri.parse("swastricare://vault")
        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
    }
    val tapPI = PendingIntent.getActivity(
        context, apptId.hashCode(), tapIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val title = if (isDayBefore) "Appointment Tomorrow" else "Appointment in 1 Hour"
    val body = buildString {
        append("Dr. $doctorName")
        if (location.isNotBlank()) append(" • $location")
    }
    val notifId = (if (isDayBefore) NotificationService.NOTIF_APPOINTMENT_DAY_BASE
                   else NotificationService.NOTIF_APPOINTMENT_HOUR_BASE) + apptId.hashCode()

    notificationService.showNotification(
        channelId = NotificationService.CHANNEL_APPOINTMENT,
        notificationId = notifId,
        title = title,
        body = body,
        contentIntent = tapPI
    )
}
```

**Step 3: Build verify**
```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

---

## Task 6: CycleNotificationScheduler

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/CycleNotificationScheduler.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/NotificationReceiver.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/NotificationService.kt`

**Step 1: Create CycleNotificationScheduler.kt**

```kotlin
package com.swasthicare.mobile.data.services

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

/**
 * Schedules cycle-related alarms based on predicted dates.
 * Called by MenstrualCycleRepository after data save/sync.
 */
class CycleNotificationScheduler(private val context: Context) {

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    companion object {
        private const val TAG = "CycleScheduler"
    }

    /**
     * Schedule all cycle reminders given prediction data.
     * @param predictedPeriodStart predicted start of next period
     * @param predictedOvulation predicted ovulation date (can be null)
     * @param dailyLogEnabled whether to schedule 9pm daily log reminders
     */
    fun scheduleFromPredictions(
        predictedPeriodStart: LocalDate?,
        predictedOvulation: LocalDate?,
        dailyLogEnabled: Boolean
    ) {
        val notifService = NotificationService(context, AppContainer.sharedPreferences)
        if (!notifService.cycleEnabled) return

        predictedPeriodStart?.let { date ->
            val reminderDate = date.minusDays(2)
            if (!reminderDate.isBefore(LocalDate.now())) {
                scheduleCycleAlarm(
                    type = "period",
                    triggerDate = reminderDate,
                    triggerHour = 9,
                    title = "Period Coming Soon",
                    body = "Your period is expected to start in 2 days. Be prepared!"
                )
            }
        }

        predictedOvulation?.let { date ->
            if (!date.isBefore(LocalDate.now())) {
                scheduleCycleAlarm(
                    type = "ovulation",
                    triggerDate = date,
                    triggerHour = 9,
                    title = "Ovulation Day",
                    body = "Today is your predicted ovulation day. Log your symptoms!"
                )
            }
        }

        if (dailyLogEnabled) {
            scheduleDailyLogReminder()
        }

        Log.d(TAG, "Cycle notifications scheduled")
    }

    private fun scheduleCycleAlarm(
        type: String,
        triggerDate: LocalDate,
        triggerHour: Int,
        title: String,
        body: String
    ) {
        val id = when (type) {
            "period" -> NotificationService.NOTIF_CYCLE_PERIOD
            "ovulation" -> NotificationService.NOTIF_CYCLE_OVULATION
            else -> NotificationService.NOTIF_CYCLE_LOG
        }

        val triggerMs = LocalDateTime.of(triggerDate, LocalTime.of(triggerHour, 0))
            .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()

        val intent = Intent(context, NotificationReceiver::class.java).apply {
            action = "CYCLE_REMINDER"
            putExtra("notif_id", id)
            putExtra("title", title)
            putExtra("body", body)
        }
        val pi = PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
        } catch (e: SecurityException) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
        }
    }

    private fun scheduleDailyLogReminder() {
        val notifService = NotificationService(context, AppContainer.sharedPreferences)
        notifService.scheduleCycleReminder(
            type = "log",
            triggerTime = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, 21)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                if (before(java.util.Calendar.getInstance())) add(java.util.Calendar.DAY_OF_MONTH, 1)
            },
            title = "Log Today's Cycle",
            body = "Don't forget to log your cycle symptoms and mood for today."
        )
    }
}
```

**Step 2: Add CYCLE_REMINDER deep link tap to NotificationReceiver**

Update the existing `CYCLE_REMINDER` case in NotificationReceiver to add a `contentIntent`:
```kotlin
"CYCLE_REMINDER" -> {
    val notifId = intent.getIntExtra("notif_id", 0)
    val title = intent.getStringExtra("title") ?: "Cycle Reminder"
    val body = intent.getStringExtra("body") ?: "Cycle tracking reminder"

    val tapIntent = Intent(context, com.swasthicare.mobile.MainActivity::class.java).apply {
        data = android.net.Uri.parse("swastricare://cycle")
        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
    }
    val tapPI = PendingIntent.getActivity(
        context, notifId + 100, tapIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    notificationService.showNotification(
        channelId = NotificationService.CHANNEL_CYCLE,
        notificationId = notifId,
        title = title,
        body = body,
        contentIntent = tapPI
    )
}
```

**Step 3: Build verify**
```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

---

## Task 7: AiNudgeWorker + ActivityReminderWorker

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/workers/AiNudgeWorker.kt`
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/workers/ActivityReminderWorker.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/SwasthiCareApplication.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Step 1: Create AiNudgeWorker.kt**

```kotlin
package com.swasthicare.mobile.data.workers

import android.content.Context
import android.util.Log
import androidx.work.*
import com.swasthicare.mobile.data.services.NotificationService
import com.swasthicare.mobile.di.AppContainer
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker that polls the ai_nudges Supabase table every 30 minutes
 * and shows undelivered nudges as local notifications.
 */
class AiNudgeWorker(appContext: Context, params: WorkerParameters) :
    CoroutineWorker(appContext, params) {

    private val json = Json { ignoreUnknownKeys = true }

    @Serializable
    data class AiNudgeRow(
        val id: String,
        val title: String,
        val message: String,
        val priority: String = "medium",
        val action_deeplink: String? = null,
        val nudge_type: String = "general"
    )

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            AppContainer.initialize(applicationContext)
            val notifService = AppContainer.notificationService
            if (!notifService.aiNudgeEnabled) return@withContext Result.success()

            val profileId = AppContainer.sharedPreferences.getString("current_profile_id", null)
                ?: return@withContext Result.success()
            val userId = AppContainer.sharedPreferences.getString("current_user_id", null)
                ?: return@withContext Result.success()

            val nudges = AppContainer.supabaseClient
                .from("ai_nudges")
                .select {
                    filter {
                        eq("user_id", userId)
                        eq("push_sent", false)
                        eq("is_dismissed", false)
                    }
                    order("created_at", Order.DESCENDING)
                    limit(5)
                }
                .decodeList<AiNudgeRow>()

            nudges.forEach { nudge ->
                val notifId = NotificationService.NOTIF_AI_NUDGE_BASE + nudge.id.hashCode()

                var tapPI: android.app.PendingIntent? = null
                nudge.action_deeplink?.let { deeplink ->
                    val tapIntent = android.content.Intent(
                        applicationContext, com.swasthicare.mobile.MainActivity::class.java
                    ).apply {
                        data = android.net.Uri.parse(deeplink)
                        flags = android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP
                    }
                    tapPI = android.app.PendingIntent.getActivity(
                        applicationContext, notifId, tapIntent,
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                    )
                }

                notifService.showNotification(
                    channelId = NotificationService.CHANNEL_AI_NUDGE,
                    notificationId = notifId,
                    title = nudge.title,
                    body = nudge.message,
                    contentIntent = tapPI
                )

                // Mark as push_sent in Supabase
                try {
                    AppContainer.supabaseClient.from("ai_nudges").update({
                        set("push_sent", true)
                    }) {
                        filter { eq("id", nudge.id) }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to mark nudge push_sent: ${e.message}")
                }
            }

            Log.d(TAG, "AiNudgeWorker: showed ${nudges.size} nudges")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "AiNudgeWorker failed: ${e.message}")
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "AiNudgeWorker"
        const val WORK_NAME = "ai_nudge_poll"

        fun enqueue(context: Context) {
            val request = PeriodicWorkRequestBuilder<AiNudgeWorker>(30, TimeUnit.MINUTES)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 5, TimeUnit.MINUTES)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
        }
    }
}
```

**Step 2: Create ActivityReminderWorker.kt**

```kotlin
package com.swasthicare.mobile.data.workers

import android.content.Context
import android.util.Log
import androidx.work.*
import com.swasthicare.mobile.data.services.NotificationService
import com.swasthicare.mobile.di.AppContainer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker that checks step count daily at ~6pm.
 * Shows an activity reminder if the user is behind on their step goal.
 */
class ActivityReminderWorker(appContext: Context, params: WorkerParameters) :
    CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            AppContainer.initialize(applicationContext)
            val notifService = AppContainer.notificationService
            if (!notifService.activityEnabled) return@withContext Result.success()

            val hour = java.time.LocalTime.now().hour
            // Only fire between 6pm-9pm
            if (hour < 18 || hour > 21) return@withContext Result.success()

            val profileId = AppContainer.sharedPreferences.getString("current_profile_id", null)
                ?: return@withContext Result.success()

            val today = LocalDate.now().toString()
            val steps = try {
                val row = AppContainer.supabaseClient
                    .from("daily_health_metrics")
                    .select {
                        filter {
                            eq("health_profile_id", profileId)
                            eq("date", today)
                        }
                        limit(1)
                    }
                    .decodeSingleOrNull<StepsRow>()
                row?.steps ?: 0
            } catch (e: Exception) {
                Log.w(TAG, "Could not fetch steps: ${e.message}")
                return@withContext Result.success()
            }

            val goal = notifService.activityGoalSteps
            if (steps < goal / 2) {
                notifService.showNotification(
                    channelId = NotificationService.CHANNEL_ACTIVITY,
                    notificationId = NotificationService.NOTIF_ACTIVITY_DAILY,
                    title = "Time to Move!",
                    body = "$steps steps so far. You need ${goal - steps} more to hit your goal today!"
                )
            } else if (steps in (goal * 8 / 10)..goal) {
                notifService.showNotification(
                    channelId = NotificationService.CHANNEL_ACTIVITY,
                    notificationId = NotificationService.NOTIF_ACTIVITY_DAILY,
                    title = "Almost There!",
                    body = "You're at $steps steps — just ${goal - steps} more to reach your goal!"
                )
            }

            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "ActivityReminderWorker failed: ${e.message}")
            Result.retry()
        }
    }

    @kotlinx.serialization.Serializable
    private data class StepsRow(val steps: Int = 0)

    companion object {
        private const val TAG = "ActivityReminderWorker"
        const val WORK_NAME = "activity_reminder"

        fun enqueue(context: Context) {
            val request = PeriodicWorkRequestBuilder<ActivityReminderWorker>(1, TimeUnit.HOURS)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
        }
    }
}
```

**Step 3: Enqueue workers in SwasthiCareApplication.kt**

In the `CoroutineScope(Dispatchers.Default).launch` block, after `scheduleAllNotifications()`, add:
```kotlin
// Enqueue WorkManager jobs
com.swasthicare.mobile.data.workers.AiNudgeWorker.enqueue(this@SwasthiCareApplication)
com.swasthicare.mobile.data.workers.ActivityReminderWorker.enqueue(this@SwasthiCareApplication)
```

**Step 4: Build verify**
```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

---

## Task 8: Fix NotificationSettingsScreen — new toggles + meal time picker

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/notifications/NotificationSettingsScreen.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/notifications/NotificationSettingsViewModel.kt`

**Step 1: Update NotificationSettingsState**

In the `data class NotificationSettingsState`, add:
```kotlin
val appointmentEnabled: Boolean = true,
val activityEnabled: Boolean = true,
val aiNudgeEnabled: Boolean = true,
val activityGoalSteps: Int = 8000,
```

**Step 2: Update loadFromService() in ViewModel**

Add to the return statement:
```kotlin
appointmentEnabled = notifService.appointmentEnabled,
activityEnabled = notifService.activityEnabled,
aiNudgeEnabled = notifService.aiNudgeEnabled,
activityGoalSteps = notifService.activityGoalSteps,
```

**Step 3: Add new setter methods to ViewModel**

```kotlin
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

fun testAppointment() = notifService.showTestNotification(NotificationService.CHANNEL_APPOINTMENT)
fun testActivity() = notifService.showTestNotification(NotificationService.CHANNEL_ACTIVITY)
fun testAiNudge() = notifService.showTestNotification(NotificationService.CHANNEL_AI_NUDGE)
```

**Step 4: Add test notifications to showTestNotification() in NotificationService**

Update the `when` block in `showTestNotification()`:
```kotlin
CHANNEL_APPOINTMENT -> "Test: Appointment" to "You have an appointment with Dr. Sharma tomorrow at 10am."
CHANNEL_ACTIVITY -> "Test: Activity" to "You've walked 3,200 steps today. Keep moving!"
CHANNEL_AI_NUDGE -> "Test: AI Coach" to "Great job staying hydrated today! Your streak is 5 days."
```

**Step 5: Fix MealTimeRow to show a time picker**

Replace the existing `MealTimeRow` composable in NotificationSettingsScreen.kt with:

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MealTimeRow(
    mealName: String,
    hour: Int,
    minute: Int,
    onTimeChange: (Int, Int) -> Unit
) {
    var showPicker by remember { mutableStateOf(false) }
    val timePickerState = rememberTimePickerState(initialHour = hour, initialMinute = minute)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { showPicker = true },
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(mealName, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
        Text(
            String.format("%02d:%02d", hour, minute),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = PrimaryColor
        )
        Icon(Icons.Default.Edit, contentDescription = "Edit time",
            modifier = Modifier.size(16.dp).padding(start = 4.dp),
            tint = PrimaryColor)
    }

    if (showPicker) {
        AlertDialog(
            onDismissRequest = { showPicker = false },
            title = { Text("$mealName Time") },
            text = { TimePicker(state = timePickerState) },
            confirmButton = {
                TextButton(onClick = {
                    onTimeChange(timePickerState.hour, timePickerState.minute)
                    showPicker = false
                }) { Text("Set") }
            },
            dismissButton = {
                TextButton(onClick = { showPicker = false }) { Text("Cancel") }
            }
        )
    }
}
```

Add `import androidx.compose.foundation.clickable` and `import androidx.compose.material3.TimePicker`, `import androidx.compose.material3.rememberTimePickerState` at the top of the file.

**Step 6: Add new sections to NotificationSettingsScreen**

After the Cycle section, add Appointment, Activity, and AI Nudge sections:

```kotlin
// ── Appointments ──
SectionContainer(title = "Appointment Reminders") {
    ToggleRow(
        icon = Icons.Default.CalendarMonth,
        label = "Enable Appointment Reminders",
        checked = uiState.appointmentEnabled,
        onCheckedChange = { viewModel.setAppointmentEnabled(it) }
    )
    if (uiState.appointmentEnabled) {
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        Text(
            "You'll be reminded 24 hours and 1 hour before each appointment.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        TestButton(onClick = { viewModel.testAppointment() })
    }
}

// ── Activity ──
SectionContainer(title = "Activity Reminders") {
    ToggleRow(
        icon = Icons.Default.DirectionsRun,
        label = "Enable Activity Reminders",
        checked = uiState.activityEnabled,
        onCheckedChange = { viewModel.setActivityEnabled(it) }
    )
    if (uiState.activityEnabled) {
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        Text(
            "Checked daily at 6pm if you're behind on your step goal.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        TestButton(onClick = { viewModel.testActivity() })
    }
}

// ── AI Health Coach ──
SectionContainer(title = "AI Health Coach") {
    ToggleRow(
        icon = Icons.Default.AutoAwesome,
        label = "Enable AI Nudges",
        checked = uiState.aiNudgeEnabled,
        onCheckedChange = { viewModel.setAiNudgeEnabled(it) }
    )
    if (uiState.aiNudgeEnabled) {
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        Text(
            "Personalized AI messages based on your health patterns.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        TestButton(onClick = { viewModel.testAiNudge() })
    }
}
```

**Step 7: Build verify**
```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

---

## Task 9: Wire schedulers into AppContainer + update Manifest + scheduleAllNotifications

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt`
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/NotificationService.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Step 1: Add schedulers to AppContainer.kt**

Add after the `notificationService` lazy property:
```kotlin
val medicationAlarmScheduler: MedicationAlarmScheduler by lazy {
    MedicationAlarmScheduler(context)
}

val appointmentAlarmScheduler: AppointmentAlarmScheduler by lazy {
    AppointmentAlarmScheduler(context)
}

val cycleNotificationScheduler: CycleNotificationScheduler by lazy {
    CycleNotificationScheduler(context)
}
```

Add imports:
```kotlin
import com.swasthicare.mobile.data.services.MedicationAlarmScheduler
import com.swasthicare.mobile.data.services.AppointmentAlarmScheduler
import com.swasthicare.mobile.data.services.CycleNotificationScheduler
```

**Step 2: Expand scheduleAllNotifications() in NotificationService.kt**

```kotlin
fun scheduleAllNotifications() {
    if (hydrationEnabled) scheduleHydrationReminders() else cancelHydrationReminders()
    if (dietEnabled) scheduleDietReminders() else cancelDietReminders()
    // Medication + Appointment + Cycle are scheduled by their respective schedulers
    // after data sync — they are re-triggered here only on boot/time-change via receiver
}
```

**Step 3: Trigger medication scheduling after MedicationsViewModel loads**

In `MedicationsViewModel.kt`, find the function that loads medications from the repository. After a successful load of both medications and schedules, add:
```kotlin
// Schedule medication alarms whenever schedules are loaded/refreshed
AppContainer.medicationAlarmScheduler.scheduleAll(schedules, medications)
```

**Step 4: Update AndroidManifest.xml**

Add new receiver actions to the existing `NotificationReceiver` intent-filter:
```xml
<action android:name="MEDICATION_REMINDER" />
<action android:name="APPOINTMENT_REMINDER" />
<action android:name="com.swasthicare.ACTION_APPOINTMENT_DISMISS" />
<action android:name="com.swasthicare.ACTION_ACTIVITY_START" />
<action android:name="com.swasthicare.ACTION_NUDGE_DISMISS" />
```

**Step 5: Final build**
```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```
Expected: `BUILD SUCCESSFUL`

---

## Task 10: Add hydration + diet + content intents, fix HYDRATION receiver deep link

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/NotificationReceiver.kt`

**Step 1: Add contentIntent to HYDRATION_REMINDER notification**

In the `HYDRATION_REMINDER` block, before `notificationService.showNotification(...)`, add:
```kotlin
val tapIntent = Intent(context, com.swasthicare.mobile.MainActivity::class.java).apply {
    data = android.net.Uri.parse("swastricare://hydration")
    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
}
val tapPI = PendingIntent.getActivity(
    context, 5010, tapIntent,
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
)
```

Update the `showNotification` call to include `contentIntent = tapPI`.

**Step 2: Add contentIntent to DIET_REMINDER notification**

Similarly add a tap intent pointing to `swastricare://diet` and pass it as `contentIntent`.

**Step 3: Final full build + verify**
```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```
Expected: `BUILD SUCCESSFUL`
