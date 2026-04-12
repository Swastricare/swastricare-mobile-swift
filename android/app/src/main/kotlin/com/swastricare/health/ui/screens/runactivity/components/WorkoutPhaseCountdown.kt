package com.swastricare.health.ui.screens.runactivity.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.theme.SecondaryColor

/**
 * COUNTDOWN phase — 3-2-1-GO! with punch-in scale animation and haptic feedback.
 */
@Composable
fun WorkoutPhaseCountdown(countdownValue: Int) {
    val haptic = LocalHapticFeedback.current
    val isDark = isSystemInDarkTheme()

    // Animatable so we can snap to large scale then spring down — avoids the
    // "set high then immediately set low in one block" bug where the high value
    // is never rendered.
    val scale = remember { Animatable(1.4f) }

    LaunchedEffect(countdownValue) {
        // Snap to punch-in size instantly
        scale.snapTo(1.4f)
        // Haptic on each tick
        if (countdownValue > 0) {
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
        } else {
            // "GO!" — double pulse
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
            kotlinx.coroutines.delay(80)
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
        }
        // Spring down to resting size
        scale.animateTo(
            targetValue = 1f,
            animationSpec = spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessMedium
            )
        )
    }

    // Background: pure black / pure white; green tint on GO
    val bgColor by animateColorAsState(
        targetValue = when {
            countdownValue == 0 -> if (isDark) Color(0xFF0A1F0D) else Color(0xFFECFDF5)
            isDark -> Color.Black
            else -> Color.White
        },
        animationSpec = tween(250),
        label = "bg"
    )

    // Number color: pure white (dark) / pure black (light); green for GO
    val textColor by animateColorAsState(
        targetValue = if (countdownValue == 0) SecondaryColor else if (isDark) Color.White else Color.Black,
        animationSpec = tween(200),
        label = "textColor"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(bgColor),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = if (countdownValue > 0) "$countdownValue" else "GO!",
                fontSize = if (countdownValue > 0) 140.sp else 96.sp,
                fontWeight = FontWeight.Black,
                color = textColor,
                modifier = Modifier.scale(scale.value)
            )
        }
    }
}
