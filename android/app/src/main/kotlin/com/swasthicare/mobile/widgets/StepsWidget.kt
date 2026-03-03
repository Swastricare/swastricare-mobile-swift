package com.swasthicare.mobile.widgets

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.*
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider
import com.swasthicare.mobile.MainActivity

/**
 * Steps Widget using Jetpack Glance.
 * Shows: current step count, daily goal, distance, calories.
 * Tap opens app to Steps/Vitals tab.
 */
class StepsWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            StepsContent(context)
        }
    }
}

@Composable
private fun StepsContent(context: Context) {
    val steps = WidgetDataManager.getStepsCurrent(context)
    val goal = WidgetDataManager.getStepsGoal(context)
    val distance = WidgetDataManager.getStepsDistance(context)
    val calories = WidgetDataManager.getStepsCalories(context)
    val progressPercent = if (goal > 0) (steps * 100 / goal) else 0

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
                text = "\uD83D\uDEB6", // Walking emoji
                style = TextStyle(fontSize = 20.sp)
            )
            Spacer(modifier = GlanceModifier.width(6.dp))
            Text(
                text = "Steps",
                style = TextStyle(
                    color = GlanceTheme.colors.onBackground,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp
                )
            )
        }

        Spacer(modifier = GlanceModifier.height(8.dp))

        // Step Count
        Text(
            text = "%,d".format(steps),
            style = TextStyle(
                color = ColorProvider(Color(0xFF32D74B)),
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp
            )
        )
        Text(
            text = "of %,d ($progressPercent%)".format(goal),
            style = TextStyle(
                color = GlanceTheme.colors.onBackground,
                fontSize = 12.sp
            )
        )

        Spacer(modifier = GlanceModifier.defaultWeight())

        // Secondary metrics
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            horizontalAlignment = Alignment.Start
        ) {
            Column {
                Text(
                    text = "%.1f km".format(distance),
                    style = TextStyle(
                        color = GlanceTheme.colors.onBackground,
                        fontWeight = FontWeight.Medium,
                        fontSize = 12.sp
                    )
                )
                Text(
                    text = "Distance",
                    style = TextStyle(
                        color = GlanceTheme.colors.onBackground,
                        fontSize = 10.sp
                    )
                )
            }
            Spacer(modifier = GlanceModifier.width(16.dp))
            Column {
                Text(
                    text = "$calories",
                    style = TextStyle(
                        color = GlanceTheme.colors.onBackground,
                        fontWeight = FontWeight.Medium,
                        fontSize = 12.sp
                    )
                )
                Text(
                    text = "Calories",
                    style = TextStyle(
                        color = GlanceTheme.colors.onBackground,
                        fontSize = 10.sp
                    )
                )
            }
        }
    }
}

class StepsWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = StepsWidget()
}
