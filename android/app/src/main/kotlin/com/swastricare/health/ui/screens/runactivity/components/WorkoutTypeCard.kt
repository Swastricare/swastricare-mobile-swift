package com.swastricare.health.ui.screens.runactivity.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.swastricare.health.ui.screens.runactivity.WorkoutType
import com.swastricare.health.ui.theme.*

/**
 * Clean Material 3 workout type selector card with animated selection state.
 * No borders, no glass effects - just background color changes.
 *
 * @param type The workout type to display
 * @param isSelected Whether this type is currently selected
 * @param onClick Callback when card is tapped
 * @param modifier Optional modifier
 */
@Composable
fun WorkoutTypeCard(
    type: WorkoutType,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()

    // Get activity-specific theme color
    val accentColor = when (type) {
        WorkoutType.RUN -> RunningCyan
        WorkoutType.WALK -> WalkingGreen
        WorkoutType.CYCLE -> CyclingYellow
        WorkoutType.HIKE -> HikingPurple
    }

    // Icon for the workout type
    val icon: ImageVector = when (type) {
        WorkoutType.RUN -> Icons.Default.DirectionsRun
        WorkoutType.WALK -> Icons.Default.DirectionsWalk
        WorkoutType.CYCLE -> Icons.Default.DirectionsBike
        WorkoutType.HIKE -> Icons.Default.Terrain
    }

    // Animated selection properties
    val scale by animateFloatAsState(
        targetValue = if (isSelected) 1.02f else 1.0f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "scaleAnimation"
    )

    Card(
        modifier = modifier
            .height(88.dp)
            .scale(scale)
            .clickable { onClick() },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = when {
                isSelected -> accentColor.copy(alpha = 0.2f)
                else -> AppColors.surfaceVariant
            }
        ),
        elevation = CardDefaults.cardElevation(
            defaultElevation = 0.dp
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 8.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Icon
            Icon(
                imageVector = icon,
                contentDescription = type.displayName,
                tint = if (isSelected) accentColor else AppColors.onSurface.copy(alpha = 0.6f),
                modifier = Modifier.size(28.dp)
            )

            Spacer(Modifier.height(6.dp))

            // Label
            Text(
                text = type.displayName,
                style = MaterialTheme.typography.labelSmall,
                color = if (isSelected) AppColors.onSurface else AppColors.onSurface.copy(alpha = 0.6f),
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                textAlign = TextAlign.Center,
                maxLines = 2
            )
        }
    }
}
