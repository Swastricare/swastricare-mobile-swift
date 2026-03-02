package com.swasthicare.mobile.widgets

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.*
import androidx.glance.background
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider
import com.swasthicare.mobile.MainActivity

/**
 * Diet Widget using Jetpack Glance.
 * Shows: calories consumed / goal, macro breakdown.
 * Quick action: "Log Meal" opens app to Diet screen.
 */
class DietWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    @Composable
    override fun Content() {
        val context = LocalContext.current

        val caloriesCurrent = WidgetDataManager.getDietCaloriesCurrent(context)
        val caloriesGoal = WidgetDataManager.getDietCaloriesGoal(context)
        val protein = WidgetDataManager.getDietProtein(context)
        val carbs = WidgetDataManager.getDietCarbs(context)
        val fat = WidgetDataManager.getDietFat(context)
        val progressPercent = if (caloriesGoal > 0) (caloriesCurrent * 100 / caloriesGoal) else 0

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
                    text = "\uD83D\uDD25", // Fire emoji
                    style = TextStyle(fontSize = 20.sp)
                )
                Spacer(modifier = GlanceModifier.width(6.dp))
                Text(
                    text = "Diet",
                    style = TextStyle(
                        color = GlanceTheme.colors.onBackground,
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                )
            }

            Spacer(modifier = GlanceModifier.height(8.dp))

            // Calories
            Text(
                text = "$caloriesCurrent cal",
                style = TextStyle(
                    color = ColorProvider(day = android.graphics.Color.parseColor("#FF9500"), night = android.graphics.Color.parseColor("#FF9F0A")),
                    fontWeight = FontWeight.Bold,
                    fontSize = 24.sp
                )
            )
            Text(
                text = "of $caloriesGoal cal ($progressPercent%)",
                style = TextStyle(
                    color = GlanceTheme.colors.onBackground,
                    fontSize = 12.sp
                )
            )

            Spacer(modifier = GlanceModifier.height(8.dp))

            // Macro mini breakdown
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                horizontalAlignment = Alignment.Start
            ) {
                MacroLabel("P", "${protein}g", android.graphics.Color.parseColor("#FF2D55"))
                Spacer(modifier = GlanceModifier.width(12.dp))
                MacroLabel("C", "${carbs}g", android.graphics.Color.parseColor("#FF9500"))
                Spacer(modifier = GlanceModifier.width(12.dp))
                MacroLabel("F", "${fat}g", android.graphics.Color.parseColor("#5E5CE6"))
            }

            Spacer(modifier = GlanceModifier.defaultWeight())

            // Log Meal button
            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .cornerRadius(8.dp)
                    .background(ColorProvider(day = android.graphics.Color.parseColor("#1AFF9500"), night = android.graphics.Color.parseColor("#33FF9F0A")))
                    .clickable(actionStartActivity<MainActivity>(
                        actionParameters = actionParametersOf()
                    ))
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Log Meal",
                    style = TextStyle(
                        color = ColorProvider(day = android.graphics.Color.parseColor("#FF9500"), night = android.graphics.Color.parseColor("#FF9F0A")),
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp
                    )
                )
            }
        }
    }
}

@Composable
private fun MacroLabel(label: String, value: String, color: Int) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = label,
            style = TextStyle(
                color = ColorProvider(day = color, night = color),
                fontWeight = FontWeight.Bold,
                fontSize = 11.sp
            )
        )
        Text(
            text = value,
            style = TextStyle(
                color = GlanceTheme.colors.onBackground,
                fontSize = 11.sp
            )
        )
    }
}

class DietWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DietWidget()
}
