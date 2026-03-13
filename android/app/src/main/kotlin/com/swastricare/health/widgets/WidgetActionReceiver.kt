package com.swastricare.health.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.updateAll
import com.swastricare.health.data.models.DrinkType
import com.swastricare.health.data.models.HydrationEntry
import dagger.hilt.android.EntryPointAccessors
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

/**
 * BroadcastReceiver that handles widget button action intents.
 * Actions include: log water, mark medication as taken, etc.
 */
class WidgetActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_LOG_WATER = "com.swastricare.widget.LOG_WATER"
        const val ACTION_MARK_MEDICATION_TAKEN = "com.swastricare.widget.MARK_MEDICATION_TAKEN"
        const val EXTRA_WATER_AMOUNT = "water_amount_ml"
        const val EXTRA_MEDICATION_ID = "medication_id"
        const val EXTRA_SCHEDULE_ID = "schedule_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                when (intent.action) {
                    ACTION_LOG_WATER -> handleLogWater(context, intent)
                    ACTION_MARK_MEDICATION_TAKEN -> handleMarkMedicationTaken(context, intent)
                }
            } finally {
                pendingResult.finish()
            }
        }
    }

    private suspend fun handleLogWater(context: Context, intent: Intent) {
        val amountMl = intent.getIntExtra(EXTRA_WATER_AMOUNT, 250)

        try {
            val entryPoint = EntryPointAccessors.fromApplication(
                context.applicationContext,
                WidgetEntryPoint::class.java
            )
            val hydrationRepository = entryPoint.hydrationRepository()

            val isoFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")
            val effectiveMl = (amountMl * DrinkType.WATER.hydrationMultiplier).toInt()
            val entry = HydrationEntry(
                id = UUID.randomUUID().toString(),
                drinkType = DrinkType.WATER.dbValue,
                amountMl = amountMl,
                effectiveMl = effectiveMl,
                consumedAt = LocalDateTime.now().format(isoFormatter),
                synced = false
            )
            hydrationRepository.addLocalEntry(entry)

            // Update widget data
            val entries = hydrationRepository.loadLocalEntries()
            val todayStr = java.time.LocalDate.now().toString()
            val todayTotal = entries
                .filter { it.consumedAt.startsWith(todayStr) }
                .sumOf { it.effectiveMl }
            val goal = WidgetDataManager.getHydrationGoal(context)
            WidgetDataManager.updateHydrationWidget(context, todayTotal, goal)

            // Refresh widget
            HydrationWidget().updateAll(context)
        } catch (_: Exception) { }
    }

    private suspend fun handleMarkMedicationTaken(context: Context, intent: Intent) {
        val medicationId = intent.getStringExtra(EXTRA_MEDICATION_ID) ?: return
        val scheduleId = intent.getStringExtra(EXTRA_SCHEDULE_ID) ?: return

        try {
            val entryPoint = EntryPointAccessors.fromApplication(
                context.applicationContext,
                WidgetEntryPoint::class.java
            )
            val authRepository = entryPoint.authRepository()
            val medicationRepository = entryPoint.medicationRepository()

            val profileId = authRepository.currentUser?.id ?: return
            medicationRepository.markAsTaken(
                medicationId = medicationId,
                scheduleId = scheduleId,
                profileId = profileId,
                scheduledTime = java.time.LocalDateTime.now(),
                logId = null
            )

            // Update widget data — clear next dose
            WidgetDataManager.updateMedicationWidget(
                context,
                nextName = "All done!",
                nextTime = "",
                nextDosage = ""
            )

            // Refresh widget
            MedicationWidget().updateAll(context)
        } catch (_: Exception) { }
    }
}
