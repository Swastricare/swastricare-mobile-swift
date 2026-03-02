package com.swasthicare.mobile.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.updateAll
import com.swasthicare.mobile.data.models.DrinkType
import com.swasthicare.mobile.data.models.HydrationEntry
import com.swasthicare.mobile.di.AppContainer
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
        const val ACTION_LOG_WATER = "com.swasthicare.widget.LOG_WATER"
        const val ACTION_MARK_MEDICATION_TAKEN = "com.swasthicare.widget.MARK_MEDICATION_TAKEN"
        const val EXTRA_WATER_AMOUNT = "water_amount_ml"
        const val EXTRA_MEDICATION_ID = "medication_id"
        const val EXTRA_SCHEDULE_ID = "schedule_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_LOG_WATER -> handleLogWater(context, intent)
            ACTION_MARK_MEDICATION_TAKEN -> handleMarkMedicationTaken(context, intent)
        }
    }

    private fun handleLogWater(context: Context, intent: Intent) {
        val amountMl = intent.getIntExtra(EXTRA_WATER_AMOUNT, 250)

        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Initialize AppContainer if needed
                AppContainer.initialize(context)

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
                AppContainer.hydrationRepository.addLocalEntry(entry)

                // Update widget data
                val entries = AppContainer.hydrationRepository.loadLocalEntries()
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
    }

    private fun handleMarkMedicationTaken(context: Context, intent: Intent) {
        val medicationId = intent.getStringExtra(EXTRA_MEDICATION_ID) ?: return
        val scheduleId = intent.getStringExtra(EXTRA_SCHEDULE_ID) ?: return

        CoroutineScope(Dispatchers.IO).launch {
            try {
                AppContainer.initialize(context)

                AppContainer.medicationRepository.markAsTaken(
                    medicationId = medicationId,
                    scheduleId = scheduleId,
                    profileId = "demo-profile-id",
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
}
