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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.runtime.getValue
import androidx.compose.animation.core.animateIntAsState
import com.swastricare.health.ui.theme.PrimaryColor
import com.swastricare.health.ui.theme.SecondaryColor
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

    LaunchedEffect(isActive) {
        docsVisible.fill(false)
        lockRotations.forEach { it.floatValue = 0f }
        if (!isActive) return@LaunchedEffect
        for (i in 0..3) {
            delay(200L + i * 150L)
            docsVisible[i] = true
            lockRotations[i].floatValue = -15f
            delay(300)
            lockRotations[i].floatValue = 0f
        }
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

    }
}

// ---------------------------------------------------------------------------
// Page 3 — Activity Preview Card
// ---------------------------------------------------------------------------

@Composable
fun ActivityPreviewCard(isActive: Boolean) {
    val green = SecondaryColor // #22C55E
    val stepGoal = 10000
    val stepTarget = 6840
    val weekBars = listOf(0.45f, 0.72f, 0.58f, 0.91f, 0.64f, 0.48f, 0.684f)

    val stepProgress by animateFloatAsState(
        targetValue = if (isActive) stepTarget / stepGoal.toFloat() else 0f,
        animationSpec = tween(1200, easing = FastOutSlowInEasing),
        label = "stepProgress"
    )
    val stepCount by animateIntAsState(
        targetValue = if (isActive) stepTarget else 0,
        animationSpec = tween(1200, easing = FastOutSlowInEasing),
        label = "stepCount"
    )
    val distanceAnim by animateFloatAsState(
        targetValue = if (isActive) 4.2f else 0f,
        animationSpec = tween(1200, delayMillis = 200, easing = FastOutSlowInEasing),
        label = "distance"
    )
    val caloriesAnim by animateFloatAsState(
        targetValue = if (isActive) 312f else 0f,
        animationSpec = tween(1200, delayMillis = 200, easing = FastOutSlowInEasing),
        label = "calories"
    )
    val barHeights = weekBars.mapIndexed { i, target ->
        animateFloatAsState(
            targetValue = if (isActive) target else 0f,
            animationSpec = tween(800, delayMillis = 300 + i * 80, easing = FastOutSlowInEasing),
            label = "bar$i"
        ).value
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .onboardingCard(),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Circular progress ring
        Box(
            modifier = Modifier.size(120.dp),
            contentAlignment = Alignment.Center
        ) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val stroke = 10.dp.toPx()
                val inset = stroke / 2
                // Background track
                drawArc(
                    color = green.copy(alpha = 0.15f),
                    startAngle = -90f,
                    sweepAngle = 360f,
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = Size(size.width - stroke, size.height - stroke),
                    style = Stroke(width = stroke, cap = StrokeCap.Round)
                )
                // Progress arc
                drawArc(
                    brush = Brush.sweepGradient(listOf(green, green.copy(alpha = 0.6f))),
                    startAngle = -90f,
                    sweepAngle = 360f * stepProgress,
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = Size(size.width - stroke, size.height - stroke),
                    style = Stroke(width = stroke, cap = StrokeCap.Round)
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    stepCount.toString(),
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = green
                )
                Text("/ 10,000", fontSize = 10.sp, color = Color.Gray)
                Text("steps", fontSize = 10.sp, color = Color.Gray)
            }
        }

        // Weekly bar chart
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.Bottom
        ) {
            val days = listOf("M", "T", "W", "T", "F", "S", "S")
            days.forEachIndexed { i, day ->
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Bottom
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height((barHeights[i] * 36).dp)
                            .clip(RoundedCornerShape(topStart = 3.dp, topEnd = 3.dp))
                            .background(if (i == 6) green else green.copy(alpha = 0.4f))
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(day, fontSize = 8.sp, color = Color.Gray)
                }
            }
        }

        // Stats row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    String.format("%.1f km", distanceAnim),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = green
                )
                Text("Distance", fontSize = 10.sp, color = Color.Gray)
            }
            Box(
                modifier = Modifier
                    .width(1.dp)
                    .height(32.dp)
                    .background(Color.Gray.copy(alpha = 0.2f))
            )
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "${caloriesAnim.toInt()} kcal",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = green
                )
                Text("Calories", fontSize = 10.sp, color = Color.Gray)
            }
        }
    }
}
