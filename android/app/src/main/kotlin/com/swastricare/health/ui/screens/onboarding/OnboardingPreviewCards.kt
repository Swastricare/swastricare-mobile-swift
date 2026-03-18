package com.swastricare.health.ui.screens.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.theme.PrimaryColor
import kotlinx.coroutines.delay

// ---------------------------------------------------------------------------
// Shared card chrome
// ---------------------------------------------------------------------------

@Composable
fun Modifier.onboardingCard(): Modifier {
    val isDark = isSystemInDarkTheme()
    return this
        .clip(RoundedCornerShape(20.dp))
        .background(
            if (isDark) Color.White.copy(alpha = 0.08f) else Color.White
        )
        .padding(16.dp)
}

// ---------------------------------------------------------------------------
// Page 1 — AI Preview Card
// ---------------------------------------------------------------------------

@Composable
fun AIPreviewCard(isActive: Boolean) {
    val purple = Color(0xFF7C3AED)
    val fullQuestion = "My sugar is 180 after food. Normal?"
    val aiResponse = "180 mg/dL post-meal is slightly high. Normal is below 140. Consult your doctor if this persists."

    var typedText by remember { mutableStateOf("") }
    var showResponse by remember { mutableStateOf(false) }
    var showPills by remember { mutableStateOf(false) }

    val infiniteTransition = rememberInfiniteTransition(label = "cursor")
    val cursorAlpha by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 0f,
        animationSpec = infiniteRepeatable(
            animation = tween(500, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "cursorBlink"
    )

    val aiIconRotation = remember { Animatable(0f) }
    LaunchedEffect(showResponse) {
        if (showResponse) {
            aiIconRotation.animateTo(360f, animationSpec = tween(600, easing = FastOutSlowInEasing))
        } else {
            aiIconRotation.snapTo(0f)
        }
    }

    LaunchedEffect(isActive) {
        typedText = ""
        showResponse = false
        showPills = false
        if (!isActive) return@LaunchedEffect
        delay(300)
        for (char in fullQuestion) {
            typedText += char
            delay(45)
        }
        delay(500)
        showResponse = true
        delay(600)
        showPills = true
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .onboardingCard(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // User bubble — right-aligned with typewriter text
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            Row(
                modifier = Modifier
                    .clip(
                        RoundedCornerShape(
                            topStart = 16.dp,
                            topEnd = 16.dp,
                            bottomStart = 16.dp,
                            bottomEnd = 4.dp
                        )
                    )
                    .background(PrimaryColor)
                    .padding(12.dp)
            ) {
                Text(typedText, fontSize = 12.sp, color = Color.White)
                if (!showResponse) {
                    Text(
                        "|",
                        fontSize = 12.sp,
                        color = Color.White.copy(alpha = cursorAlpha),
                        fontWeight = FontWeight.Light
                    )
                }
            }
        }

        // AI response bubble
        AnimatedVisibility(
            visible = showResponse,
            enter = fadeIn() + slideInVertically { it / 2 }
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.Top
            ) {
                Box(
                    modifier = Modifier
                        .size(24.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Brush.linearGradient(listOf(purple, PrimaryColor))),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "✦",
                        fontSize = 12.sp,
                        color = Color.White,
                        modifier = Modifier.rotate(aiIconRotation.value)
                    )
                }

                Column(
                    modifier = Modifier
                        .clip(RoundedCornerShape(16.dp))
                        .background(Color.Black.copy(alpha = 0.03f))
                        .padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(aiResponse, fontSize = 12.sp, lineHeight = 18.sp)
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Swastri AI", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = purple)
                        Text("✦", fontSize = 8.sp, color = purple)
                    }
                }
            }
        }

        // Suggestion pills
        AnimatedVisibility(
            visible = showPills,
            enter = fadeIn() + slideInVertically { it / 2 }
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("Sugar control tips", "Diet for diabetes").forEach { label ->
                    Text(
                        label,
                        fontSize = 10.sp,
                        color = purple,
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(purple.copy(alpha = 0.08f))
                            .border(1.dp, purple.copy(alpha = 0.15f), CircleShape)
                            .padding(horizontal = 10.dp, vertical = 6.dp)
                    )
                }
            }
        }
    }
}
