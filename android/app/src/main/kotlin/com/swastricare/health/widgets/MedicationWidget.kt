package com.swastricare.health.widgets

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.*
import androidx.glance.appwidget.action.actionSendBroadcast
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider
import com.swastricare.health.MainActivity

/**
 * Medication Widget using Jetpack Glance.
 * Shows: next upcoming dose (name, time, dosage).
 * Quick action: "Mark as Taken" button.
 */
class MedicationWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            MedicationContent(context)
        }
    }
}

@Composable
private fun MedicationContent(context: Context) {
    val nextName = WidgetDataManager.getMedicationNextName(context)
    val nextTime = WidgetDataManager.getMedicationNextTime(context)
    val nextDosage = WidgetDataManager.getMedicationNextDosage(context)

    val prefs = WidgetDataManager.getPrefs(context)
    val medicationId = prefs.getString(WidgetDataManager.KEY_MEDICATION_NEXT_ID, "") ?: ""
    val scheduleId = prefs.getString(WidgetDataManager.KEY_MEDICATION_NEXT_SCHEDULE_ID, "") ?: ""

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(GlanceTheme.colors.background)
            .cornerRadius(16.dp)
            .padding(12.dp)
            .clickable(actionStartActivity<MainActivity>()),
        verticalAlignment = Alignment.Top,
        horizontalAlignment = Alignment.Start
    ) {
        // Header
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "\uD83D\uDC8A", // Pill emoji
                style = TextStyle(fontSize = 20.sp)
            )
            Spacer(modifier = GlanceModifier.width(6.dp))
            Text(
                text = "Medication",
                style = TextStyle(
                    color = GlanceTheme.colors.onBackground,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp
                )
            )
        }

        Spacer(modifier = GlanceModifier.height(8.dp))

        // Next Dose Info
        Text(
            text = nextName,
            style = TextStyle(
                color = GlanceTheme.colors.onBackground,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp
            ),
            maxLines = 1
        )

        if (nextTime.isNotBlank()) {
            Text(
                text = nextTime,
                style = TextStyle(
                    color = ColorProvider(Color(0xFF4F46E5)),
                    fontWeight = FontWeight.Medium,
                    fontSize = 14.sp
                )
            )
        }

        if (nextDosage.isNotBlank()) {
            Text(
                text = nextDosage,
                style = TextStyle(
                    color = GlanceTheme.colors.onBackground,
                    fontSize = 12.sp
                )
            )
        }

        Spacer(modifier = GlanceModifier.defaultWeight())

        // Mark as Taken button
        if (medicationId.isNotBlank()) {
            val markTakenIntent = Intent(context, WidgetActionReceiver::class.java).apply {
                action = WidgetActionReceiver.ACTION_MARK_MEDICATION_TAKEN
                putExtra(WidgetActionReceiver.EXTRA_MEDICATION_ID, medicationId)
                putExtra(WidgetActionReceiver.EXTRA_SCHEDULE_ID, scheduleId)
            }

            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .cornerRadius(8.dp)
                    .background(ColorProvider(Color(0x1A22C55E)))
                    .clickable(actionSendBroadcast(markTakenIntent))
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Mark as Taken",
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF22C55E)),
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp
                    )
                )
            }
        }
    }
}

class MedicationWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = MedicationWidget()
}
