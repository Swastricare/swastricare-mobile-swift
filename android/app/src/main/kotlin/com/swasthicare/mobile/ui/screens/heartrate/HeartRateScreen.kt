package com.swasthicare.mobile.ui.screens.heartrate

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.HeartRateColor
import com.swasthicare.mobile.ui.theme.PremiumColor
import kotlinx.coroutines.delay

// Zone colors
private val ZoneNormal = Color(0xFF4CAF50)
private val ZoneElevated = Color(0xFFFFC107)
private val ZoneHigh = Color(0xFFF44336)
private val ZoneLow = Color(0xFF2196F3)

// ─────────────────────────────────────
// MARK: - HeartRateScreen (Measurement)
// ─────────────────────────────────────

@Composable
fun HeartRateScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToAnalytics: () -> Unit = {},
    onNavigateToAI: () -> Unit = {}
) {
    val viewModel = remember { HeartRateViewModel() }
    val uiState by viewModel.uiState.collectAsState()

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            // Top Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        Icons.Default.ArrowBack, "Back",
                        tint = MaterialTheme.colorScheme.onSurface
                    )
                }
                Text(
                    "Heart Rate",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f).padding(start = 4.dp)
                )
                IconButton(onClick = onNavigateToAnalytics) {
                    Icon(
                        Icons.Default.BarChart, "Analytics",
                        tint = HeartRateColor
                    )
                }
            }

            when {
                uiState.showResult -> HeartRateResultScreen(
                    bpm = uiState.lastBpm,
                    confidence = uiState.confidence,
                    source = uiState.source,
                    onNavigateToAnalytics = onNavigateToAnalytics,
                    onNavigateToAI = onNavigateToAI,
                    onMeasureAgain = { viewModel.startMeasurement() },
                    onDismiss = onNavigateBack
                )
                uiState.isMeasuring -> HeartRateMeasuringView(
                    progress = uiState.measurementProgress,
                    currentBpm = uiState.currentBpm,
                    onCancel = { viewModel.cancelMeasurement() }
                )
                else -> HeartRateIdleView(
                    lastBpm = uiState.lastBpm,
                    onStartMeasurement = { viewModel.startMeasurement() }
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Idle View
// ─────────────────────────────────────

@Composable
private fun HeartRateIdleView(
    lastBpm: Int,
    onStartMeasurement: () -> Unit
) {
    val infiniteTransition = rememberInfiniteTransition(label = "heartPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "scale"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Pulsing heart icon
        Box(
            modifier = Modifier
                .size(120.dp)
                .scale(pulseScale)
                .background(HeartRateColor.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Favorite,
                contentDescription = null,
                tint = HeartRateColor,
                modifier = Modifier.size(56.dp)
            )
        }

        Spacer(Modifier.height(32.dp))

        if (lastBpm > 0) {
            Text(
                text = "Last Reading",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = "$lastBpm",
                    style = MaterialTheme.typography.displayMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = " BPM",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 8.dp)
                )
            }
            Spacer(Modifier.height(24.dp))
        }

        Text(
            text = "Place your fingertip over the camera\nand flashlight to measure your heart rate",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(32.dp))

        Button(
            onClick = onStartMeasurement,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(containerColor = HeartRateColor)
        ) {
            Icon(Icons.Default.CameraAlt, null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text("Start Measurement", fontWeight = FontWeight.SemiBold)
        }
    }
}

// ─────────────────────────────────────
// MARK: - Measuring View
// ─────────────────────────────────────

@Composable
private fun HeartRateMeasuringView(
    progress: Float,
    currentBpm: Int,
    onCancel: () -> Unit
) {
    val infiniteTransition = rememberInfiniteTransition(label = "measuring")
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseAlpha"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Circular progress with heart
        Box(contentAlignment = Alignment.Center) {
            CircularProgressIndicator(
                progress = { progress },
                modifier = Modifier.size(160.dp),
                color = HeartRateColor,
                trackColor = HeartRateColor.copy(alpha = 0.15f),
                strokeWidth = 8.dp
            )
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = Icons.Default.Favorite,
                    contentDescription = null,
                    tint = HeartRateColor.copy(alpha = pulseAlpha),
                    modifier = Modifier.size(40.dp)
                )
                if (currentBpm > 0) {
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "$currentBpm",
                        style = MaterialTheme.typography.headlineLarge,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "BPM",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        Spacer(Modifier.height(32.dp))

        Text(
            text = "Measuring...",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = "Keep your finger steady on the camera",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(Modifier.height(32.dp))

        OutlinedButton(
            onClick = onCancel,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            shape = RoundedCornerShape(12.dp)
        ) {
            Text("Cancel")
        }
    }
}

// ─────────────────────────────────────
// MARK: - Result Screen
// ─────────────────────────────────────

@Composable
fun HeartRateResultScreen(
    bpm: Int,
    confidence: Float,
    source: String,
    onNavigateToAnalytics: () -> Unit,
    onNavigateToAI: () -> Unit,
    onMeasureAgain: () -> Unit,
    onDismiss: () -> Unit
) {
    // Staggered entry animation
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(100)
        isVisible = true
    }

    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(600, easing = FastOutSlowInEasing),
        label = "resultAlpha"
    )

    val zone = getHeartRateZone(bpm)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .graphicsLayer { alpha = animatedAlpha },
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(24.dp))

        // BPM display with zone color ring
        Box(
            modifier = Modifier
                .size(160.dp)
                .background(zone.color.copy(alpha = 0.1f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            // Outer ring
            Canvas(modifier = Modifier.size(160.dp)) {
                drawCircle(
                    color = zone.color.copy(alpha = 0.3f),
                    radius = size.minDimension / 2,
                    style = androidx.compose.ui.graphics.drawscope.Stroke(width = 6.dp.toPx())
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    Icons.Default.Favorite, null,
                    tint = zone.color,
                    modifier = Modifier.size(28.dp)
                )
                Text(
                    text = "$bpm",
                    style = MaterialTheme.typography.displayMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = "BPM",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Spacer(Modifier.height(16.dp))

        // Zone label
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .background(zone.color.copy(alpha = 0.15f))
                .padding(horizontal = 16.dp, vertical = 6.dp)
        ) {
            Text(
                text = zone.label,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = zone.color
            )
        }

        Spacer(Modifier.height(24.dp))

        // Health Zone Bar (visual gradient bar with indicator)
        HeartRateZoneBar(bpm = bpm)

        Spacer(Modifier.height(24.dp))

        // Info cards row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Confidence card
            InfoCard(
                label = "Confidence",
                value = "${(confidence * 100).toInt()}%",
                icon = Icons.Default.Verified,
                color = ZoneNormal,
                modifier = Modifier.weight(1f)
            )
            // Source card
            InfoCard(
                label = "Source",
                value = source,
                icon = if (source == "Camera") Icons.Default.CameraAlt else Icons.Default.Favorite,
                color = PremiumColor.RoyalBlueStart,
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(Modifier.height(20.dp))

        // Zone description
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 16.dp)
                .padding(16.dp)
        ) {
            Text(
                text = zone.description,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Spacer(Modifier.height(20.dp))

        // Ask Swastri AI button
        Button(
            onClick = onNavigateToAI,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = PremiumColor.RoyalBlueStart
            )
        ) {
            Icon(Icons.Default.AutoAwesome, null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text(
                "Ask Swastri AI about this",
                fontWeight = FontWeight.SemiBold
            )
        }

        Spacer(Modifier.height(12.dp))

        // Action buttons row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OutlinedButton(
                onClick = onMeasureAgain,
                modifier = Modifier.weight(1f).height(48.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.Refresh, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("Measure Again")
            }

            Button(
                onClick = onNavigateToAnalytics,
                modifier = Modifier.weight(1f).height(48.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = HeartRateColor)
            ) {
                Icon(Icons.Default.BarChart, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("Analytics")
            }
        }

        Spacer(Modifier.height(120.dp))
    }
}

// ─────────────────────────────────────
// MARK: - Heart Rate Zone Bar
// ─────────────────────────────────────

@Composable
private fun HeartRateZoneBar(bpm: Int) {
    val minBpm = 40f
    val maxBpm = 180f
    val clampedBpm = bpm.toFloat().coerceIn(minBpm, maxBpm)
    val position = (clampedBpm - minBpm) / (maxBpm - minBpm)

    // Animate the indicator position
    val animatedPosition by animateFloatAsState(
        targetValue = position,
        animationSpec = tween(800, easing = FastOutSlowInEasing),
        label = "zoneBarPos"
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 16.dp)
            .padding(16.dp)
    ) {
        Text(
            text = "Heart Rate Zone",
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface
        )

        Spacer(Modifier.height(12.dp))

        // Zone labels row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text("Low", style = MaterialTheme.typography.labelSmall, color = ZoneLow)
            Text("Normal", style = MaterialTheme.typography.labelSmall, color = ZoneNormal)
            Text("Elevated", style = MaterialTheme.typography.labelSmall, color = ZoneElevated)
            Text("High", style = MaterialTheme.typography.labelSmall, color = ZoneHigh)
        }

        Spacer(Modifier.height(6.dp))

        // Gradient bar with indicator
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(24.dp)
        ) {
            // Gradient bar
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(12.dp)
                    .align(Alignment.Center)
                    .clip(RoundedCornerShape(6.dp))
            ) {
                drawRoundRect(
                    brush = Brush.horizontalGradient(
                        colorStops = arrayOf(
                            0.0f to ZoneLow,
                            0.14f to ZoneLow,
                            0.14f to ZoneNormal,
                            0.43f to ZoneNormal,
                            0.43f to ZoneElevated,
                            0.57f to ZoneElevated,
                            0.57f to ZoneHigh,
                            1.0f to ZoneHigh
                        )
                    ),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(6.dp.toPx())
                )
            }

            // Indicator marker
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(24.dp)
            ) {
                Canvas(
                    modifier = Modifier
                        .fillMaxSize()
                ) {
                    val markerX = animatedPosition * size.width
                    // White triangle marker
                    drawCircle(
                        color = Color.White,
                        radius = 8.dp.toPx(),
                        center = Offset(markerX, size.height / 2),
                        style = androidx.compose.ui.graphics.drawscope.Fill
                    )
                    drawCircle(
                        color = Color.Black.copy(alpha = 0.3f),
                        radius = 8.dp.toPx(),
                        center = Offset(markerX, size.height / 2),
                        style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2.dp.toPx())
                    )
                    // Inner dot matching zone color
                    val zoneColor = when {
                        animatedPosition < 0.14f -> ZoneLow
                        animatedPosition < 0.43f -> ZoneNormal
                        animatedPosition < 0.57f -> ZoneElevated
                        else -> ZoneHigh
                    }
                    drawCircle(
                        color = zoneColor,
                        radius = 4.dp.toPx(),
                        center = Offset(markerX, size.height / 2)
                    )
                }
            }
        }

        Spacer(Modifier.height(6.dp))

        // BPM range labels
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text("40", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("60", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("100", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("120", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("180", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

// ─────────────────────────────────────
// MARK: - Info Card
// ─────────────────────────────────────

@Composable
private fun InfoCard(
    label: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .glass(cornerRadius = 16.dp)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .background(color.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(16.dp))
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

// ─────────────────────────────────────
// MARK: - Zone Data Model
// ─────────────────────────────────────

data class HeartRateZone(
    val label: String,
    val color: Color,
    val description: String
)

fun getHeartRateZone(bpm: Int): HeartRateZone = when {
    bpm < 60 -> HeartRateZone(
        label = "Low",
        color = ZoneLow,
        description = "Your heart rate is below the normal resting range. This can be normal for athletes or during deep relaxation. If you feel dizzy or faint, consult a doctor."
    )
    bpm in 60..100 -> HeartRateZone(
        label = "Normal",
        color = ZoneNormal,
        description = "Your heart rate is within the normal resting range (60-100 BPM). This indicates healthy cardiovascular function at rest."
    )
    bpm in 101..120 -> HeartRateZone(
        label = "Elevated",
        color = ZoneElevated,
        description = "Your heart rate is slightly elevated. This can be caused by recent physical activity, stress, caffeine, or dehydration. Try resting for a few minutes."
    )
    else -> HeartRateZone(
        label = "High",
        color = ZoneHigh,
        description = "Your heart rate is high for a resting measurement. If you haven't been exercising, consider monitoring it. Seek medical advice if this persists."
    )
}
