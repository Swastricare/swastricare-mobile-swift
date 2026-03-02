package com.swasthicare.mobile.ui.screens.heartrate

import androidx.camera.view.PreviewView
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.swasthicare.mobile.data.services.*
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.*

private val HeartRed = Color(0xFFFF2D55)
private val HeartRedDark = Color(0xFFCC1840)

// ------------------------------------
// MARK: - Heart Rate Screen
// ------------------------------------

@Composable
fun HeartRateScreen(
    onNavigateBack: () -> Unit,
    onNavigateToResult: () -> Unit
) {
    val vm = remember { AppContainer.heartRateViewModel }
    val uiState by vm.uiState.collectAsState()
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    // Camera preview reference
    var previewView by remember { mutableStateOf<PreviewView?>(null) }

    // When measurement completes, navigate to result
    LaunchedEffect(uiState.state) {
        if (uiState.state == MeasurementState.RESULT) {
            onNavigateToResult()
        }
    }

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
                IconButton(onClick = {
                    vm.stopMeasurement()
                    onNavigateBack()
                }) {
                    Icon(Icons.Default.ArrowBack, "Back", tint = MaterialTheme.colorScheme.onSurface)
                }
                Text(
                    "Heart Rate",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f).padding(start = 4.dp)
                )
            }

            // Disclaimer dialog
            if (uiState.showDisclaimer) {
                DisclaimerDialog(
                    onAccept = { vm.acceptDisclaimer() },
                    onDismiss = { onNavigateBack() }
                )
            }

            when (uiState.state) {
                MeasurementState.IDLE -> {
                    IdleContent(
                        onStart = {
                            previewView?.let { pv ->
                                vm.startMeasurement(pv, lifecycleOwner)
                            }
                        },
                        previewViewProvider = { pv -> previewView = pv }
                    )
                }
                MeasurementState.PREPARING,
                MeasurementState.CALIBRATING,
                MeasurementState.MEASURING,
                MeasurementState.COMPLETING -> {
                    MeasuringContent(
                        uiState = uiState,
                        onStop = { vm.stopMeasurement() },
                        previewViewProvider = { pv -> previewView = pv }
                    )
                }
                MeasurementState.ERROR -> {
                    ErrorContent(
                        onRetry = { vm.retake() },
                        onBack = onNavigateBack
                    )
                }
                else -> {} // RESULT handled by navigation
            }
        }
    }
}

// ------------------------------------
// MARK: - Idle Content
// ------------------------------------

@Composable
private fun IdleContent(
    onStart: () -> Unit,
    previewViewProvider: (PreviewView) -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Spacer(Modifier.height(40.dp))

        // Camera Preview (small)
        Box(
            modifier = Modifier
                .size(160.dp)
                .clip(CircleShape)
                .background(Color.Black),
            contentAlignment = Alignment.Center
        ) {
            AndroidView(
                factory = { ctx ->
                    PreviewView(ctx).also { previewViewProvider(it) }
                },
                modifier = Modifier.fillMaxSize()
            )

            // Overlay circle
            Box(
                modifier = Modifier
                    .size(160.dp)
                    .background(
                        Brush.radialGradient(
                            colors = listOf(Color.Transparent, HeartRed.copy(alpha = 0.3f))
                        ),
                        CircleShape
                    )
            )
        }

        // Pulsing heart icon
        val infiniteTransition = rememberInfiniteTransition(label = "heartPulse")
        val heartScale by infiniteTransition.animateFloat(
            initialValue = 0.8f,
            targetValue = 1.2f,
            animationSpec = infiniteRepeatable(
                animation = tween(800, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse
            ),
            label = "heartScale"
        )

        Icon(
            Icons.Default.Favorite,
            null,
            tint = HeartRed,
            modifier = Modifier.size(64.dp).scale(heartScale)
        )

        Text(
            "Place your finger over the\ncamera and flashlight",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center
        )

        Text(
            "Cover the entire lens firmly with your fingertip. Keep still during measurement.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 16.dp)
        )

        Spacer(Modifier.weight(1f))

        Button(
            onClick = onStart,
            colors = ButtonDefaults.buttonColors(containerColor = HeartRed),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth().height(56.dp)
        ) {
            Icon(Icons.Default.Favorite, null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text("Start Measurement", fontWeight = FontWeight.Bold, fontSize = 16.sp)
        }

        Spacer(Modifier.height(40.dp))
    }
}

// ------------------------------------
// MARK: - Measuring Content
// ------------------------------------

@Composable
private fun MeasuringContent(
    uiState: HeartRateUiState,
    onStop: () -> Unit,
    previewViewProvider: (PreviewView) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Camera Preview
        Box(
            modifier = Modifier
                .size(120.dp)
                .clip(CircleShape)
                .background(Color.Black),
            contentAlignment = Alignment.Center
        ) {
            AndroidView(
                factory = { ctx ->
                    PreviewView(ctx).also { previewViewProvider(it) }
                },
                modifier = Modifier.fillMaxSize()
            )
        }

        // Phase Label
        Text(
            uiState.phase.displayName,
            style = MaterialTheme.typography.titleMedium,
            color = HeartRed,
            fontWeight = FontWeight.SemiBold
        )

        // Live BPM Display
        if (uiState.currentBPM > 0) {
            val infiniteTransition = rememberInfiniteTransition(label = "bpmPulse")
            val pulseScale by infiniteTransition.animateFloat(
                initialValue = 0.95f,
                targetValue = 1.05f,
                animationSpec = infiniteRepeatable(
                    animation = tween(600, easing = FastOutSlowInEasing),
                    repeatMode = RepeatMode.Reverse
                ),
                label = "bpmScale"
            )

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.scale(pulseScale)
            ) {
                Text(
                    "${uiState.currentBPM}",
                    style = MaterialTheme.typography.displayLarge,
                    fontWeight = FontWeight.Bold,
                    color = HeartRed
                )
                Text(
                    "BPM",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "--",
                    style = MaterialTheme.typography.displayLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    "BPM",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // Waveform
        if (uiState.waveformData.isNotEmpty()) {
            WaveformView(
                data = uiState.waveformData,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(80.dp)
                    .glass(cornerRadius = 12.dp)
                    .padding(8.dp)
            )
        }

        // Signal Quality
        SignalQualityBar(quality = uiState.signalQuality)

        // Progress
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            LinearProgressIndicator(
                progress = { uiState.progress },
                modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
                color = HeartRed,
                trackColor = HeartRed.copy(alpha = 0.2f)
            )
            Text(
                "${(uiState.progress * 30).toInt()}s / 30s",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Instructions
        Text(
            "Keep your finger steady on the camera",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.weight(1f))

        // Stop Button
        OutlinedButton(
            onClick = onStop,
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(Icons.Default.Stop, null, tint = HeartRed)
            Spacer(Modifier.width(8.dp))
            Text("Stop", color = HeartRed)
        }
    }
}

// ------------------------------------
// MARK: - Waveform View
// ------------------------------------

@Composable
private fun WaveformView(
    data: List<Float>,
    modifier: Modifier = Modifier
) {
    Canvas(modifier = modifier) {
        if (data.isEmpty()) return@Canvas

        val width = size.width
        val height = size.height
        val midY = height / 2

        val maxVal = data.maxOfOrNull { kotlin.math.abs(it) }?.coerceAtLeast(1f) ?: 1f
        val stepX = width / (data.size - 1).coerceAtLeast(1)

        val path = Path()
        data.forEachIndexed { index, value ->
            val x = index * stepX
            val y = midY - (value / maxVal) * (height * 0.4f)
            if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }

        drawPath(
            path = path,
            color = Color(0xFFFF2D55),
            style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
        )
    }
}

// ------------------------------------
// MARK: - Signal Quality Bar
// ------------------------------------

@Composable
private fun SignalQualityBar(quality: SignalQuality) {
    val qualityColor = when (quality) {
        SignalQuality.EXCELLENT -> Color(0xFF30D158)
        SignalQuality.GOOD -> Color(0xFF0A84FF)
        SignalQuality.FAIR -> Color(0xFFFF9F0A)
        SignalQuality.POOR -> Color(0xFFFF375F)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 12.dp)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .background(qualityColor, CircleShape)
        )
        Text(
            "Signal: ${quality.displayName}",
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium
        )
        Spacer(Modifier.weight(1f))

        // Quality bars
        Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            val levels = when (quality) {
                SignalQuality.EXCELLENT -> 4
                SignalQuality.GOOD -> 3
                SignalQuality.FAIR -> 2
                SignalQuality.POOR -> 1
            }
            repeat(4) { i ->
                Box(
                    modifier = Modifier
                        .width(6.dp)
                        .height(((i + 1) * 4 + 4).dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(
                            if (i < levels) qualityColor else qualityColor.copy(alpha = 0.2f)
                        )
                )
            }
        }
    }
}

// ------------------------------------
// MARK: - Error Content
// ------------------------------------

@Composable
private fun ErrorContent(
    onRetry: () -> Unit,
    onBack: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Default.ErrorOutline,
            null,
            tint = HeartRed,
            modifier = Modifier.size(64.dp)
        )
        Spacer(Modifier.height(16.dp))
        Text(
            "Measurement Failed",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Make sure your finger covers the entire camera lens and try again.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(24.dp))

        Button(
            onClick = onRetry,
            colors = ButtonDefaults.buttonColors(containerColor = HeartRed),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Try Again", fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(8.dp))
        TextButton(onClick = onBack) {
            Text("Go Back")
        }
    }
}

// ------------------------------------
// MARK: - Disclaimer Dialog
// ------------------------------------

@Composable
private fun DisclaimerDialog(
    onAccept: () -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = {
            Icon(
                Icons.Default.MedicalServices,
                null,
                tint = HeartRed,
                modifier = Modifier.size(40.dp)
            )
        },
        title = {
            Text("Medical Disclaimer", fontWeight = FontWeight.Bold)
        },
        text = {
            Text(
                "This feature uses your phone's camera for an approximate heart rate reading. " +
                "It is NOT a medical device and should NOT be used for medical diagnosis. " +
                "Results may vary based on device, lighting, and skin tone. " +
                "Always consult a healthcare professional for accurate heart rate measurements.",
                style = MaterialTheme.typography.bodyMedium
            )
        },
        confirmButton = {
            Button(
                onClick = onAccept,
                colors = ButtonDefaults.buttonColors(containerColor = HeartRed)
            ) {
                Text("I Understand")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

// ------------------------------------
// MARK: - Heart Rate Result Screen
// ------------------------------------

@Composable
fun HeartRateResultScreen(
    onNavigateBack: () -> Unit,
    onRetake: () -> Unit
) {
    val vm = remember { AppContainer.heartRateViewModel }
    val uiState by vm.uiState.collectAsState()
    val result = uiState.result

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
                IconButton(onClick = {
                    vm.retake()
                    onNavigateBack()
                }) {
                    Icon(Icons.Default.ArrowBack, "Back", tint = MaterialTheme.colorScheme.onSurface)
                }
                Text(
                    "Result",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f).padding(start = 4.dp)
                )
            }

            if (result == null) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text("No result available")
                }
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    Spacer(Modifier.height(20.dp))

                    // BPM Large Display
                    val categoryColor = Color(result.category.colorHex)

                    val infiniteTransition = rememberInfiniteTransition(label = "resultPulse")
                    val pulseScale by infiniteTransition.animateFloat(
                        initialValue = 0.95f,
                        targetValue = 1.05f,
                        animationSpec = infiniteRepeatable(
                            animation = tween(800, easing = FastOutSlowInEasing),
                            repeatMode = RepeatMode.Reverse
                        ),
                        label = "resultScale"
                    )

                    Box(
                        modifier = Modifier
                            .size(200.dp)
                            .scale(pulseScale)
                            .background(
                                Brush.radialGradient(
                                    colors = listOf(
                                        categoryColor.copy(alpha = 0.3f),
                                        categoryColor.copy(alpha = 0.05f)
                                    )
                                ),
                                CircleShape
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                Icons.Default.Favorite,
                                null,
                                tint = HeartRed,
                                modifier = Modifier.size(32.dp)
                            )
                            Text(
                                "${result.bpm}",
                                style = MaterialTheme.typography.displayLarge,
                                fontWeight = FontWeight.Bold,
                                color = HeartRed,
                                fontSize = 56.sp
                            )
                            Text(
                                "BPM",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }

                    // Category Badge
                    Box(
                        modifier = Modifier
                            .background(categoryColor.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
                            .padding(horizontal = 16.dp, vertical = 8.dp)
                    ) {
                        Text(
                            result.category.displayName,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = categoryColor
                        )
                    }

                    // Details Card
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .glass(cornerRadius = 20.dp)
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        ResultDetailRow(
                            label = "Confidence",
                            value = "${(result.confidence * 100).toInt()}%"
                        )
                        ResultDetailRow(
                            label = "Error Margin",
                            value = "+/- ${result.errorMargin} BPM"
                        )
                        ResultDetailRow(
                            label = "Signal Quality",
                            value = result.quality.displayName
                        )
                    }

                    Spacer(Modifier.weight(1f))

                    // Save Button
                    Button(
                        onClick = { vm.saveResult() },
                        enabled = !uiState.saved && !uiState.isSaving,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (uiState.saved) Color(0xFF30D158) else HeartRed
                        ),
                        shape = RoundedCornerShape(16.dp),
                        modifier = Modifier.fillMaxWidth().height(56.dp)
                    ) {
                        if (uiState.isSaving) {
                            CircularProgressIndicator(
                                color = Color.White,
                                modifier = Modifier.size(20.dp)
                            )
                        } else {
                            Icon(
                                if (uiState.saved) Icons.Default.Check else Icons.Default.Save,
                                null,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(
                                if (uiState.saved) "Saved" else "Save to Health Record",
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp
                            )
                        }
                    }

                    // Retake Button
                    OutlinedButton(
                        onClick = {
                            vm.retake()
                            onRetake()
                        },
                        shape = RoundedCornerShape(16.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Default.Refresh, null, tint = HeartRed)
                        Spacer(Modifier.width(8.dp))
                        Text("Measure Again", color = HeartRed)
                    }

                    Spacer(Modifier.height(20.dp))
                }
            }
        }
    }
}

@Composable
private fun ResultDetailRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold
        )
    }
}
