package com.swastricare.health.ui.screens.runactivity.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import com.swastricare.health.ui.theme.SecondaryColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * COUNTDOWN phase component - 3-2-1 countdown with spring animation.
 */
@Composable
fun WorkoutPhaseCountdown(
    countdownValue: Int
) {
    val scale by animateFloatAsState(
        targetValue = 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "countdownScale"
    )

    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "$countdownValue",
            fontSize = 120.sp,
            fontWeight = FontWeight.Black,
            color = SecondaryColor,
            modifier = Modifier.scale(scale)
        )
    }
}
