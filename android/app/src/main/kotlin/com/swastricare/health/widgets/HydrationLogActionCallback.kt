package com.swastricare.health.widgets

import android.content.Context
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.updateAll
import com.swastricare.health.data.models.DrinkType
import com.swastricare.health.data.models.HydrationEntry
import dagger.hilt.android.EntryPointAccessors
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

/**
 * Glance ActionCallback that logs a hydration entry when a quick-action button
 * (e.g. "+250ml" / "+500ml") on the [HydrationWidget] is tapped.
 *
 * Uses [actionRunCallback] under the hood, which is the recommended Glance
 * pattern for widget click handlers — Glance auto-registers its internal
 * broadcast receiver and delivers ActionParameters reliably, avoiding the
 * pitfalls of rolling our own BroadcastReceiver + Intent extras (PendingIntent
 * filterEquals collisions, FLAG_IMMUTABLE extras, manifest exported flags, etc).
 *
 * Must have a public no-arg constructor — Glance instantiates it via reflection.
 */
class HydrationLogActionCallback : ActionCallback {

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val amountMl = parameters[AMOUNT_KEY] ?: DEFAULT_AMOUNT_ML
        Log.d(TAG, "Hydration quick-log triggered: ${amountMl}ml")

        try {
            val entryPoint = EntryPointAccessors.fromApplication(
                context.applicationContext,
                WidgetEntryPoint::class.java
            )
            val hydrationRepository = entryPoint.hydrationRepository()

            val effectiveMl = (amountMl * DrinkType.WATER.hydrationMultiplier).toInt()
            val entry = HydrationEntry(
                id = UUID.randomUUID().toString(),
                drinkType = DrinkType.WATER.dbValue,
                amountMl = amountMl,
                effectiveMl = effectiveMl,
                consumedAt = LocalDateTime.now().format(ISO_FORMATTER),
                synced = false
            )
            hydrationRepository.addLocalEntry(entry)

            // Recompute today's total from the persisted entries and refresh the widget data.
            val entries = hydrationRepository.loadLocalEntries()
            val todayStr = LocalDate.now().toString()
            val todayTotal = entries
                .filter { it.consumedAt.startsWith(todayStr) }
                .sumOf { it.effectiveMl }
            val goal = WidgetDataManager.getHydrationGoal(context)
            WidgetDataManager.updateHydrationWidget(context, todayTotal, goal)

            HydrationWidget().updateAll(context)
            Log.d(TAG, "Hydration logged: total=${todayTotal}ml goal=${goal}ml")
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to log ${amountMl}ml from widget", t)
        }
    }

    companion object {
        private const val TAG = "HydrationWidgetCb"
        private const val DEFAULT_AMOUNT_ML = 250
        private val ISO_FORMATTER: DateTimeFormatter =
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")

        val AMOUNT_KEY: ActionParameters.Key<Int> =
            ActionParameters.Key("hydration_amount_ml")
    }
}
