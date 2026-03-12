package com.swastricare.health.ui.screens.ar

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.PointF
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swastricare.health.data.services.BodyScanResult
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.HeartRateColor
import com.swastricare.health.ui.theme.HydrationColor
import com.swastricare.health.ui.theme.PrimaryColor
import com.swastricare.health.ui.theme.SecondaryColor
import java.util.concurrent.Executors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ARBodyScanScreen(
    onNavigateBack: () -> Unit,
    viewModel: ARBodyScanViewModel = viewModel()
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val uiState by viewModel.uiState.collectAsState()

    // Permission launcher
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        viewModel.onPermissionResult(granted)
    }

    // Check permission on launch
    LaunchedEffect(Unit) {
        val hasPermission = ContextCompat.checkSelfPermission(
            context, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
        if (hasPermission) {
            viewModel.onPermissionResult(true)
        } else {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    // Bottom sheet state
    val sheetState = rememberModalBottomSheetState()

    var cameraError by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        if (uiState.cameraPermissionGranted) {
            if (cameraError) {
                // Camera error screen
                CameraErrorScreen(
                    onRetry = { cameraError = false },
                    onNavigateBack = onNavigateBack
                )
            } else {
                // Camera Preview
                CameraPreviewWithAnalysis(
                    onFrameAvailable = { imageProxy ->
                        viewModel.processFrame(imageProxy)
                    },
                    onCameraError = { cameraError = true }
                )

                // Body overlay
                uiState.bodyScanResult?.let { result ->
                    BodyOverlayCanvas(
                        result = result,
                        uiState = uiState,
                        onOrganTapped = { organKey ->
                            viewModel.selectOrgan(organKey)
                        }
                    )
                }

                // Scanning animation overlay
                ScanningOverlay(detectionState = uiState.detectionState)

                // Top bar
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(
                        onClick = onNavigateBack,
                        colors = IconButtonDefaults.iconButtonColors(
                            containerColor = Color.Black.copy(alpha = 0.4f)
                        )
                    ) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }

                    Text(
                        text = "Body Scan",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )

                    Spacer(modifier = Modifier.size(48.dp))
                }

                // Detection status indicator
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 32.dp)
                ) {
                    DetectionStatusChip(detectionState = uiState.detectionState)
                }
            }
        } else {
            // Permission not granted screen
            CameraPermissionScreen(
                onRequestPermission = {
                    permissionLauncher.launch(Manifest.permission.CAMERA)
                },
                onNavigateBack = onNavigateBack
            )
        }
    }

    // Organ detail bottom sheet
    if (uiState.showDetailSheet && uiState.selectedOrgan != null) {
        ModalBottomSheet(
            onDismissRequest = { viewModel.dismissDetailSheet() },
            sheetState = sheetState,
            containerColor = AppColors.surface
        ) {
            OrganDetailSheet(organInfo = uiState.selectedOrgan!!)
        }
    }
}

@Composable
private fun CameraPreviewWithAnalysis(
    onFrameAvailable: (androidx.camera.core.ImageProxy) -> Unit,
    onCameraError: () -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val cameraExecutor = remember { Executors.newSingleThreadExecutor() }

    DisposableEffect(Unit) {
        onDispose {
            cameraExecutor.shutdown()
        }
    }

    AndroidView(
        factory = { ctx ->
            val previewView = PreviewView(ctx)

            val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
            cameraProviderFuture.addListener({
                try {
                    val cameraProvider = cameraProviderFuture.get()

                    val preview = Preview.Builder().build().also {
                        it.setSurfaceProvider(previewView.surfaceProvider)
                    }

                    val imageAnalysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .also { analysis ->
                            analysis.setAnalyzer(cameraExecutor) { imageProxy ->
                                onFrameAvailable(imageProxy)
                            }
                        }

                    val cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA

                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        lifecycleOwner,
                        cameraSelector,
                        preview,
                        imageAnalysis
                    )
                } catch (e: Exception) {
                    Log.e("ARBodyScan", "Camera initialization failed", e)
                    onCameraError()
                }
            }, ContextCompat.getMainExecutor(ctx))

            previewView
        },
        modifier = Modifier.fillMaxSize()
    )
}

@Composable
private fun BodyOverlayCanvas(
    result: BodyScanResult,
    uiState: ARBodyScanState,
    onOrganTapped: (String) -> Unit
) {
    // We need to map image coordinates to screen coordinates.
    // The canvas fills the full screen; we scale proportionally.
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val screenWidth = constraints.maxWidth.toFloat()
        val screenHeight = constraints.maxHeight.toFloat()

        // For front camera, the image is mirrored horizontally.
        // ML Kit returns coordinates in the original image space.
        val scaleX = screenWidth / result.imageHeight.toFloat() // Rotated image
        val scaleY = screenHeight / result.imageWidth.toFloat()

        fun mapPoint(p: PointF): Offset {
            // Mirror X for front camera and account for rotation
            return Offset(
                x = screenWidth - (p.x * scaleX),
                y = p.y * scaleY
            )
        }

        Canvas(modifier = Modifier.fillMaxSize()) {
            val landmarks = result.landmarks

            // Draw skeleton lines
            val skeletonColor = Color.Cyan.copy(alpha = 0.6f)
            val lineWidth = 3f

            // Skeleton connections
            val connections = listOf(
                "left_shoulder" to "right_shoulder",
                "left_shoulder" to "left_elbow",
                "left_elbow" to "left_wrist",
                "right_shoulder" to "right_elbow",
                "right_elbow" to "right_wrist",
                "left_shoulder" to "left_hip",
                "right_shoulder" to "right_hip",
                "left_hip" to "right_hip",
                "left_hip" to "left_knee",
                "left_knee" to "left_ankle",
                "right_hip" to "right_knee",
                "right_knee" to "right_ankle"
            )

            connections.forEach { (from, to) ->
                val fromPoint = landmarks[from]
                val toPoint = landmarks[to]
                if (fromPoint != null && toPoint != null) {
                    drawLine(
                        color = skeletonColor,
                        start = mapPoint(fromPoint),
                        end = mapPoint(toPoint),
                        strokeWidth = lineWidth,
                        cap = StrokeCap.Round
                    )
                }
            }

            // Draw landmark dots
            landmarks.values.forEach { point ->
                val mapped = mapPoint(point)
                drawCircle(
                    color = Color.Cyan,
                    radius = 6f,
                    center = mapped
                )
                drawCircle(
                    color = Color.White,
                    radius = 3f,
                    center = mapped
                )
            }

            // Draw organ indicators
            result.organPositions.forEach { (key, point) ->
                val mapped = mapPoint(point)
                val color = getOrganColor(key)

                // Outer glow
                drawCircle(
                    color = color.copy(alpha = 0.3f),
                    radius = 28f,
                    center = mapped
                )

                // Main circle
                drawCircle(
                    color = color.copy(alpha = 0.8f),
                    radius = 18f,
                    center = mapped
                )

                // Inner ring
                drawCircle(
                    color = Color.White,
                    radius = 18f,
                    center = mapped,
                    style = Stroke(width = 2f)
                )
            }
        }

        // Organ tap targets (Compose clickable overlays)
        result.organPositions.forEach { (key, point) ->
            val mapped = mapPoint(point)
            val xDp = (mapped.x / screenWidth * maxWidth.value).dp
            val yDp = (mapped.y / screenHeight * maxHeight.value).dp

            Box(
                modifier = Modifier
                    .offset(x = xDp - 20.dp, y = yDp - 20.dp)
                    .size(40.dp)
                    .clip(CircleShape)
                    .clickable { onOrganTapped(key) }
            )

            // Organ label
            val label = getOrganLabel(key, uiState)
            Box(
                modifier = Modifier
                    .offset(x = xDp - 40.dp, y = yDp + 18.dp)
                    .width(80.dp)
                    .background(
                        Color.Black.copy(alpha = 0.6f),
                        RoundedCornerShape(6.dp)
                    )
                    .padding(horizontal = 4.dp, vertical = 2.dp)
            ) {
                Text(
                    text = label,
                    color = Color.White,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

private fun getOrganColor(key: String): Color {
    return when (key) {
        "heart" -> HeartRateColor
        "left_lung", "right_lung" -> HydrationColor
        "stomach" -> Color(0xFFFF9F0A)
        "liver" -> SecondaryColor
        "left_kidney", "right_kidney" -> PrimaryColor
        else -> Color.White
    }
}

private fun getOrganLabel(key: String, uiState: ARBodyScanState): String {
    return when (key) {
        "heart" -> "${uiState.heartRate} BPM"
        "left_lung" -> "L Lung"
        "right_lung" -> "R Lung"
        "stomach" -> "${uiState.caloriesConsumed} cal"
        "liver" -> "Liver"
        "left_kidney" -> "${uiState.hydrationCurrent}ml"
        "right_kidney" -> "Kidney"
        else -> key
    }
}

@Composable
private fun ScanningOverlay(detectionState: BodyDetectionState) {
    if (detectionState == BodyDetectionState.SCANNING) {
        val infiniteTransition = rememberInfiniteTransition(label = "scan")
        val scanOffset by infiniteTransition.animateFloat(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(2000, easing = LinearEasing),
                repeatMode = RepeatMode.Reverse
            ),
            label = "scanLine"
        )

        Canvas(modifier = Modifier.fillMaxSize()) {
            val y = size.height * scanOffset
            drawLine(
                color = Color.Cyan.copy(alpha = 0.5f),
                start = Offset(0f, y),
                end = Offset(size.width, y),
                strokeWidth = 3f
            )
            // Glow effect
            drawLine(
                color = Color.Cyan.copy(alpha = 0.15f),
                start = Offset(0f, y - 20f),
                end = Offset(size.width, y - 20f),
                strokeWidth = 40f
            )
        }
    }
}

@Composable
private fun DetectionStatusChip(detectionState: BodyDetectionState) {
    val (text, color) = when (detectionState) {
        BodyDetectionState.SCANNING -> "Scanning..." to Color(0xFFFF9F0A)
        BodyDetectionState.DETECTED -> "Body Detected" to SecondaryColor
        BodyDetectionState.NOT_FOUND -> "Body not detected" to HeartRateColor
    }

    val infiniteTransition = rememberInfiniteTransition(label = "statusPulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0.7f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseAlpha"
    )

    Surface(
        color = Color.Black.copy(alpha = 0.6f),
        shape = RoundedCornerShape(20.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(
                        color.copy(alpha = if (detectionState == BodyDetectionState.SCANNING) alpha else 1f),
                        CircleShape
                    )
            )
            Text(
                text = text,
                color = Color.White,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
private fun OrganDetailSheet(organInfo: OrganInfo) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 16.dp)
            .padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = organInfo.emoji,
                fontSize = 32.sp
            )
            Column {
                Text(
                    text = organInfo.displayName,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = organInfo.value,
                    style = MaterialTheme.typography.titleMedium,
                    color = PrimaryColor,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        HorizontalDivider(color = AppColors.outlineVariant)

        Text(
            text = organInfo.detail,
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurfaceVariant
        )
    }
}

@Composable
private fun CameraErrorScreen(
    onRetry: () -> Unit,
    onNavigateBack: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.Warning,
            contentDescription = null,
            tint = HeartRateColor.copy(alpha = 0.8f),
            modifier = Modifier.size(80.dp)
        )

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "Camera Unavailable",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = Color.White,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(12.dp))

        Text(
            text = "Camera unavailable. Please close other camera apps and try again.",
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White.copy(alpha = 0.7f),
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(32.dp))

        Button(
            onClick = onRetry,
            colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
        ) {
            Text("Try Again")
        }

        Spacer(modifier = Modifier.height(12.dp))

        TextButton(onClick = onNavigateBack) {
            Text("Go Back", color = Color.White.copy(alpha = 0.7f))
        }
    }
}

@Composable
private fun CameraPermissionScreen(
    onRequestPermission: () -> Unit,
    onNavigateBack: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.CameraAlt,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.6f),
            modifier = Modifier.size(80.dp)
        )

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "Camera Permission Required",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = Color.White,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(12.dp))

        Text(
            text = "Body Scan needs access to your camera to detect body landmarks and overlay health data.",
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White.copy(alpha = 0.7f),
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(32.dp))

        Button(
            onClick = onRequestPermission,
            colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
        ) {
            Text("Grant Permission")
        }

        Spacer(modifier = Modifier.height(12.dp))

        TextButton(onClick = onNavigateBack) {
            Text("Go Back", color = Color.White.copy(alpha = 0.7f))
        }
    }
}
