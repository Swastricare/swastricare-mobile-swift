package com.swastricare.health.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.glance.appwidget.updateAll
import dagger.hilt.android.EntryPointAccessors
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * BroadcastReceiver that handles widget button action intents.
 *
 * Currently used for: marking medications as taken from the [MedicationWidget].
 *
 * NOTE: Hydration quick-log buttons no longer use this receiver — they use
 * Glance's [androidx.glance.appwidget.action.actionRunCallback] via
 * [HydrationLogActionCallback], which is the more reliable Glance pattern.
 */
class WidgetActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "WidgetActionReceiver"
        const val ACTION_MARK_MEDICATION_TAKEN = "com.swastricare.widget.MARK_MEDICATION_TAKEN"
        const val EXTRA_MEDICATION_ID = "medication_id"
        const val EXTRA_SCHEDULE_ID = "schedule_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive action=${intent.action}")
        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                when (intent.action) {
                    ACTION_MARK_MEDICATION_TAKEN -> handleMarkMedicationTaken(context, intent)
                    else -> Log.w(TAG, "Unhandled action: ${intent.action}")
                }
            } catch (t: Throwable) {
                Log.e(TAG, "Failed handling ${intent.action}", t)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private suspend fun handleMarkMedicationTaken(context: Context, intent: Intent) {
        val medicationId = intent.getStringExtra(EXTRA_MEDICATION_ID) ?: run {
            Log.w(TAG, "MARK_MEDICATION_TAKEN missing medication_id")
            return
        }
        val scheduleId = intent.getStringExtra(EXTRA_SCHEDULE_ID) ?: run {
            Log.w(TAG, "MARK_MEDICATION_TAKEN missing schedule_id")
            return
        }

        val entryPoint = EntryPointAccessors.fromApplication(
            context.applicationContext,
            WidgetEntryPoint::class.java
        )
        val authRepository = entryPoint.authRepository()
        val medicationRepository = entryPoint.medicationRepository()

        val profileId = authRepository.currentUser?.id ?: run {
            Log.w(TAG, "MARK_MEDICATION_TAKEN: no signed-in user")
            return
        }
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
        Log.d(TAG, "Medication $medicationId marked as taken from widget")
    }
}
