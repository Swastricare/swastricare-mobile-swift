package com.swasthicare.mobile.widgets

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
import com.swasthicare.mobile.MainActivity

/**
 * Hydration Widget using Jetpack Glance.
 * Shows current intake, daily goal, progress percentage.
 * Quick actions: "Log 250ml" and "Log 500ml" buttons.
 */
class HydrationWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            HydrationContent(context)
        }
    }
}

@Composable
private fun HydrationContent(context: Context) {
    val currentMl = WidgetDataManager.getHydrationCurrent(context)
    val goalMl = WidgetDataManager.getHydrationGoal(context)
    val progressPercent = if (goalMl > 0) (currentMl * 100 / goalMl) else 0

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
                text = "\uD83D\uDCA7", // Water drop emoji
                style = TextStyle(fontSize = 20.sp)
            )
            Spacer(modifier = GlanceModifier.width(6.dp))
            Text(
                text = "Hydration",
                style = TextStyle(
                    color = GlanceTheme.colors.onBackground,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp
                )
            )
        }

        Spacer(modifier = GlanceModifier.height(8.dp))

        // Progress
        Text(
            text = "${currentMl}ml",
            style = TextStyle(
                color = ColorProvider(Color(0xFF64D2FF)),
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp
            )
        )
        Text(
            text = "of ${goalMl}ml ($progressPercent%)",
            style = TextStyle(
                color = GlanceTheme.colors.onBackground,
                fontSize = 12.sp
            )
        )

        Spacer(modifier = GlanceModifier.defaultWeight())

        // Quick Action Buttons
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            val log250Intent = Intent(context, WidgetActionReceiver::class.java).apply {
                action = WidgetActionReceiver.ACTION_LOG_WATER
                putExtra(WidgetActionReceiver.EXTRA_WATER_AMOUNT, 250)
            }
            val log500Intent = Intent(context, WidgetActionReceiver::class.java).apply {
                action = WidgetActionReceiver.ACTION_LOG_WATER
                putExtra(WidgetActionReceiver.EXTRA_WATER_AMOUNT, 500)
            }

            Box(
                modifier = GlanceModifier
                    .cornerRadius(8.dp)
                    .background(ColorProvider(Color(0x1A64D2FF)))
                    .clickable(actionSendBroadcast(log250Intent))
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "+250ml",
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF64D2FF)),
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp
                    )
                )
            }

            Spacer(modifier = GlanceModifier.width(8.dp))

            Box(
                modifier = GlanceModifier
                    .cornerRadius(8.dp)
                    .background(ColorProvider(Color(0x1A64D2FF)))
                    .clickable(actionSendBroadcast(log500Intent))
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "+500ml",
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF64D2FF)),
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp
                    )
                )
            }
        }
    }
}

class HydrationWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = HydrationWidget()
}
