package com.swasthicare.mobile.widgets

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import android.content.ComponentName
import androidx.glance.appwidget.*
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider
import com.swasthicare.mobile.MainActivity

/**
 * Run/Activity Widget using Jetpack Glance.
 * Shows: last run date, distance (km), duration (mm:ss), average pace.
 * Includes a "Start Run" button that deep links to the live workout screen.
 * Tap opens app to Steps/Run tab.
 */
class RunWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            RunContent(context)
        }
    }
}

@Composable
private fun RunContent(context: Context) {
    val lastRun = WidgetDataManager.getLastRunData(context)

    // Deep-link intent that opens app to start a run
    val startRunIntent = Intent(Intent.ACTION_VIEW, Uri.parse("swastricare://startRun/run")).apply {
        setClass(context, MainActivity::class.java)
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }

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
                text = "\uD83C\uDFC3", // Runner emoji
                style = TextStyle(fontSize = 20.sp)
            )
            Spacer(modifier = GlanceModifier.width(6.dp))
            Text(
                text = "Last Run",
                style = TextStyle(
                    color = GlanceTheme.colors.onBackground,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp
                )
            )
        }

        Spacer(modifier = GlanceModifier.height(8.dp))

        if (lastRun.hasData) {
            // Distance — large, prominent
            Text(
                text = lastRun.formattedDistance,
                style = TextStyle(
                    color = ColorProvider(Color(0xFF22C55E)), // SecondaryColor green
                    fontWeight = FontWeight.Bold,
                    fontSize = 28.sp
                )
            )

            // Date of last run
            Text(
                text = lastRun.date,
                style = TextStyle(
                    color = GlanceTheme.colors.onBackground,
                    fontSize = 11.sp
                )
            )

            Spacer(modifier = GlanceModifier.height(6.dp))

            // Secondary metrics: Duration | Pace
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                horizontalAlignment = Alignment.Start
            ) {
                // Duration
                Column {
                    Text(
                        text = lastRun.formattedDuration,
                        style = TextStyle(
                            color = GlanceTheme.colors.onBackground,
                            fontWeight = FontWeight.Medium,
                            fontSize = 12.sp
                        )
                    )
                    Text(
                        text = "Duration",
                        style = TextStyle(
                            color = GlanceTheme.colors.onBackground,
                            fontSize = 10.sp
                        )
                    )
                }
                Spacer(modifier = GlanceModifier.width(16.dp))
                // Pace
                Column {
                    Text(
                        text = lastRun.pace,
                        style = TextStyle(
                            color = GlanceTheme.colors.onBackground,
                            fontWeight = FontWeight.Medium,
                            fontSize = 12.sp
                        )
                    )
                    Text(
                        text = "Avg Pace",
                        style = TextStyle(
                            color = GlanceTheme.colors.onBackground,
                            fontSize = 10.sp
                        )
                    )
                }
            }

            Spacer(modifier = GlanceModifier.defaultWeight())

            // Start Run button — deep links to live workout
            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .background(Color(0xFF22C55E))
                    .cornerRadius(10.dp)
                    .padding(vertical = 8.dp, horizontal = 12.dp)
                    .clickable(actionStartActivity(ComponentName(context, MainActivity::class.java))),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "\u25B6  Start Run",
                    style = TextStyle(
                        color = ColorProvider(Color.White),
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp
                    )
                )
            }
        } else {
            // Empty state — no run recorded yet
            Spacer(modifier = GlanceModifier.height(4.dp))

            Text(
                text = "No runs yet",
                style = TextStyle(
                    color = GlanceTheme.colors.onBackground,
                    fontWeight = FontWeight.Medium,
                    fontSize = 16.sp
                )
            )
            Text(
                text = "Start your first run!",
                style = TextStyle(
                    color = GlanceTheme.colors.onBackground,
                    fontSize = 12.sp
                )
            )

            Spacer(modifier = GlanceModifier.defaultWeight())

            // Start Run button — deep links to live workout
            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .background(Color(0xFF22C55E))
                    .cornerRadius(10.dp)
                    .padding(vertical = 8.dp, horizontal = 12.dp)
                    .clickable(actionStartActivity(ComponentName(context, MainActivity::class.java))),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "\u25B6  Start Run",
                    style = TextStyle(
                        color = ColorProvider(Color.White),
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp
                    )
                )
            }
        }
    }
}

class RunWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = RunWidget()
}
