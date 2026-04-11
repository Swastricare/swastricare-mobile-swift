package com.swastricare.health.ui.screens.runactivity.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * COUNTDOWN phase component - 3-2-1 countdown with animated black/white flash.
 */
@Composable
fun WorkoutPhaseCountdown(
    countdownValue: Int
) {
    // Punch-in scale: starts large, springs down to 1
    var targetScale by remember { mutableFloatStateOf(2.5f) }
    LaunchedEffect(countdownValue) {
        targetScale = 2.5f
        // Triggers recomposition so the animation runs from 2.5 → 1
        targetScale = 1f
    }
    val scale by animateFloatAsState(
        targetValue = targetScale,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "countdownScale"
    )

    // Animated background flash: toggles between black and white each tick
    val isDark = isSystemInDarkTheme()
    val bgTarget = if (countdownValue % 2 == 0) {
        if (isDark) Color(0xFF1A1A1A) else Color.White
    } else {
        if (isDark) Color.Black else Color(0xFFF0F0F0)
    }
    val animatedBg by animateColorAsState(
        targetValue = bgTarget,
        animationSpec = tween(300, easing = FastOutSlowInEasing),
        label = "countdownBg"
    )

    // Text color: inverse of background
    val textTarget = if (countdownValue % 2 == 0) Color.White else Color.Black
    val animatedText by animateColorAsState(
        targetValue = textTarget,
        animationSpec = tween(300, easing = FastOutSlowInEasing),
        label = "countdownText"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(animatedBg),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "$countdownValue",
            fontSize = 120.sp,
            fontWeight = FontWeight.Black,
            color = animatedText,
            modifier = Modifier.scale(scale)
        )
    }
}
