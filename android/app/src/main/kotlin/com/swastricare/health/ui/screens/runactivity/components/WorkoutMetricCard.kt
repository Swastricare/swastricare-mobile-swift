package com.swastricare.health.ui.screens.runactivity.components

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.swastricare.health.ui.theme.AppColors

/**
 * Clean Material 3 metric card for workout statistics.
 * No borders, no glass effects - just clean background colors.
 *
 * @param label The metric label (e.g., "Distance", "Pace")
 * @param value The metric value (e.g., "5.2", "4:30")
 * @param unit The metric unit (e.g., "km", "min/km")
 * @param color Theme color for the label
 * @param modifier Optional modifier
 */
@Composable
fun WorkoutMetricCard(
    label: String,
    value: String,
    unit: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()

    Card(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isDark) AppColors.surfaceVariant else AppColors.surfaceVariant
        ),
        elevation = CardDefaults.cardElevation(
            defaultElevation = 0.dp
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            // Label with themed color
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = color.copy(alpha = 0.8f),
                fontWeight = FontWeight.Medium
            )

            // Value and unit row
            Row(
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = value,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )
                Text(
                    text = unit,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurface.copy(alpha = 0.5f),
                    modifier = Modifier.padding(bottom = 4.dp)
                )
            }
        }
    }
}
