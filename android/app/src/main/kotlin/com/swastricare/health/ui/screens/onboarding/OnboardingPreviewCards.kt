package com.swastricare.health.ui.screens.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInHorizontally
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
import androidx.compose.ui.graphics.lerp
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

// ---------------------------------------------------------------------------
// Page 2 — Vault Preview Card
// ---------------------------------------------------------------------------

@Composable
fun VaultPreviewCard(isActive: Boolean) {
    val skyBlue = Color(0xFF0EA5E9)
    val accentRed = Color(0xFFEF4444)
    val accentGreen = Color(0xFF22C55E)
    val purple = Color(0xFF7C3AED)

    data class DocRow(
        val iconText: String,
        val gradientColors: List<Color>,
        val title: String,
        val subtitle: String
    )

    val docs = listOf(
        DocRow("PDF", listOf(accentRed, Color(0xFFDC2626)), "Blood Report — SRL Diagnostics", "Mar 2026 · CBC, Lipid, Thyroid"),
        DocRow("🩻", listOf(skyBlue, Color(0xFF0284C7)), "X-Ray — Apollo Hospital", "Feb 2026 · Chest X-Ray"),
        DocRow("💊", listOf(accentGreen, Color(0xFF16A34A)), "Prescription — Dr. Sharma", "Jan 2026 · Diabetes Management"),
        DocRow("🧠", listOf(purple, Color(0xFF6D28D9)), "MRI — Manipal Hospital", "Dec 2025 · Brain Scan")
    )

    val docsVisible = remember { mutableStateListOf(false, false, false, false) }
    val lockRotations = remember { Array(4) { mutableFloatStateOf(0f) } }
    var shieldVisible by remember { mutableStateOf(false) }

    LaunchedEffect(isActive) {
        docsVisible.fill(false)
        shieldVisible = false
        lockRotations.forEach { it.floatValue = 0f }
        if (!isActive) return@LaunchedEffect
        for (i in 0..3) {
            delay(200L + i * 150L)
            docsVisible[i] = true
            lockRotations[i].floatValue = -15f
            delay(300)
            lockRotations[i].floatValue = 0f
        }
        delay(200)
        shieldVisible = true
    }

    Column(
        modifier = Modifier.fillMaxWidth().onboardingCard(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        docs.forEachIndexed { i, doc ->
            AnimatedVisibility(
                visible = docsVisible.getOrElse(i) { false },
                enter = fadeIn() + slideInHorizontally { it / 2 }
            ) {
                val lockAngle by animateFloatAsState(lockRotations[i].floatValue, label = "lock$i")
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.Black.copy(alpha = 0.03f))
                        .padding(10.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Brush.linearGradient(doc.gradientColors)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            doc.iconText,
                            fontSize = if (doc.iconText.length > 2) 11.sp else 16.sp,
                            fontWeight = if (doc.iconText.length > 2) FontWeight.Bold else FontWeight.Normal,
                            color = Color.White
                        )
                    }
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        Text(doc.title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
                        Text(doc.subtitle, fontSize = 10.sp, color = Color.Gray)
                    }
                    Text("🔒", fontSize = 12.sp, modifier = Modifier.rotate(lockAngle))
                }
            }
        }

        AnimatedVisibility(
            visible = shieldVisible,
            enter = fadeIn() + scaleIn(initialScale = 0.8f)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(
                        Brush.linearGradient(listOf(skyBlue.copy(alpha = 0.08f), PrimaryColor.copy(alpha = 0.08f)))
                    )
                    .border(1.dp, skyBlue.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
                    .padding(12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("🛡️", fontSize = 16.sp)
                Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text("End-to-End Encrypted", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                    Text("Only you and who you share with can access", fontSize = 9.sp, color = Color.Gray)
                }
            }
        }
    }
}
