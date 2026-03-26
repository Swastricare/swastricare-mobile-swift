package com.swastricare.health.ui.screens.ai

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.theme.ActivityColor
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.DistanceColor
import com.swastricare.health.ui.theme.HeartRateColor
import com.swastricare.health.ui.theme.SleepColor
import com.swastricare.health.ui.theme.StepsColor

/**
 * Represents a detected health metric from AI response text.
 */
data class DetectedMetric(
    val icon: ImageVector,
    val label: String,
    val value: String,
    val color: Color
)

/**
 * Detects health metrics from AI response text using regex patterns.
 * Matches iOS InlineHealthMetricCard detection logic.
 */
fun detectHealthMetrics(text: String): List<DetectedMetric> {
    val metrics = mutableListOf<DetectedMetric>()
    val lowerText = text.lowercase()

    // Steps: matches "10,000 steps" or "10000 steps"
    val stepsRegex = Regex("""([\d,]+)\s*steps""", RegexOption.IGNORE_CASE)
    stepsRegex.find(lowerText)?.let { match ->
        val value = match.groupValues[1].replace(",", "")
        metrics.add(
            DetectedMetric(
                icon = Icons.AutoMirrored.Filled.DirectionsWalk,
                label = "steps",
                value = value,
                color = StepsColor
            )
        )
    }

    // Heart rate: matches "72 bpm" or "72bpm"
    val bpmRegex = Regex("""(\d+)\s*bpm""", RegexOption.IGNORE_CASE)
    bpmRegex.find(lowerText)?.let { match ->
        val value = match.groupValues[1]
        metrics.add(
            DetectedMetric(
                icon = Icons.Default.Favorite,
                label = "bpm",
                value = value,
                color = HeartRateColor
            )
        )
    }

    // Calories: matches "250 calories", "250 kcal", "250 cal"
    val caloriesRegex = Regex("""(\d+)\s*(calories|kcal|cal)\b""", RegexOption.IGNORE_CASE)
    caloriesRegex.find(lowerText)?.let { match ->
        val value = match.groupValues[1]
        metrics.add(
            DetectedMetric(
                icon = Icons.Default.LocalFireDepartment,
                label = "cal",
                value = value,
                color = ActivityColor
            )
        )
    }

    // Sleep: matches "7.5 hours of sleep", "8 h sleep", "7 hours sleep"
    val sleepRegex = Regex(
        """(\d+\.?\d*)\s*(hours?\s*(?:of\s*)?sleep|h\s*sleep|hours?\s*sleep)""",
        RegexOption.IGNORE_CASE
    )
    sleepRegex.find(lowerText)?.let { match ->
        val value = match.groupValues[1]
        metrics.add(
            DetectedMetric(
                icon = Icons.Default.Bedtime,
                label = "hr",
                value = value,
                color = SleepColor
            )
        )
    }

    // Blood pressure: matches "120/80", "120/80 mmhg"
    val bpRegex = Regex("""(\d{2,3}/\d{2,3})\s*(?:mmhg)?""", RegexOption.IGNORE_CASE)
    bpRegex.find(lowerText)?.let { match ->
        val value = match.groupValues[1]
        metrics.add(
            DetectedMetric(
                icon = Icons.Default.MonitorHeart,
                label = "mmHg",
                value = value,
                color = HeartRateColor
            )
        )
    }

    // Weight: matches "70 kg", "70.5 kg"
    val weightRegex = Regex("""(\d+\.?\d*)\s*kg""", RegexOption.IGNORE_CASE)
    weightRegex.find(lowerText)?.let { match ->
        val value = match.groupValues[1]
        metrics.add(
            DetectedMetric(
                icon = Icons.Default.FitnessCenter,
                label = "kg",
                value = value,
                color = DistanceColor
            )
        )
    }

    return metrics
}

/**
 * Capsule-shaped badge displaying a detected health metric.
 * Matches iOS InlineHealthMetricCard design.
 */
@Composable
fun InlineHealthMetricCard(
    metric: DetectedMetric,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .background(
                color = metric.color.copy(alpha = 0.06f),
                shape = RoundedCornerShape(50) // Full capsule
            )
            .border(
                width = 0.5.dp,
                color = metric.color.copy(alpha = 0.1f),
                shape = RoundedCornerShape(50)
            )
            .padding(horizontal = 10.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Icon
        Icon(
            imageVector = metric.icon,
            contentDescription = null,
            modifier = Modifier.size(11.dp),
            tint = metric.color
        )

        // Value (bold)
        Text(
            text = metric.value,
            style = MaterialTheme.typography.labelSmall.copy(
                fontFamily = Poppins,
                fontWeight = FontWeight.Bold,
                fontSize = 11.sp
            ),
            color = AppColors.onBackground
        )

        // Label (lighter)
        Text(
            text = metric.label,
            style = MaterialTheme.typography.labelSmall.copy(
                fontFamily = Poppins,
                fontWeight = FontWeight.Normal,
                fontSize = 10.sp
            ),
            color = AppColors.onSurfaceVariant
        )
    }
}

/**
 * Horizontal row of detected health metric badges.
 * Only renders if metrics are detected in the content.
 */
@Composable
fun InlineHealthMetricsRow(
    content: String,
    modifier: Modifier = Modifier
) {
    val detectedMetrics = remember(content) { detectHealthMetrics(content) }

    if (detectedMetrics.isNotEmpty()) {
        AnimatedVisibility(
            visible = true,
            enter = fadeIn() + expandVertically(),
            modifier = modifier
        ) {
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                items(detectedMetrics) { metric ->
                    InlineHealthMetricCard(metric = metric)
                }
            }
        }
    }
}
