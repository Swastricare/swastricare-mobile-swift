package com.swasthicare.mobile.ui.components

import android.content.Context
import android.util.Log
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import io.github.sceneview.SceneView
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import io.github.sceneview.node.ModelNode

/**
 * 3D Model Viewer Component using SceneView (Filament wrapper)
 *
 * Displays GLB models with auto-rotation, lighting, and smooth animations.
 * Matching iOS SceneKit ModelViewer implementation.
 */
@Composable
fun ModelViewer(
    modelName: String,
    modifier: Modifier = Modifier,
    autoRotate: Boolean = true,
    allowInteraction: Boolean = false,
    rotationDurationMs: Int = 8000
) {
    var isModelLoaded by remember { mutableStateOf(false) }

    // Entrance animation (matching iOS: 0→0.8 opacity, 0.8→1.2 scale)
    val animatedAlpha by animateFloatAsState(
        targetValue = if (isModelLoaded) 0.8f else 0f,
        animationSpec = tween(durationMillis = 1000, delayMillis = 200),
        label = "modelAlpha"
    )

    val animatedScale by animateFloatAsState(
        targetValue = if (isModelLoaded) 1f else 0.8f,
        animationSpec = tween(durationMillis = 1000, delayMillis = 200, easing = FastOutSlowInEasing),
        label = "modelScale"
    )

    // Auto-rotation animation
    val infiniteTransition = rememberInfiniteTransition(label = "rotation")
    val rotationY by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(rotationDurationMs, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotationY"
    )

    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {
        // Background glow effect
        RadialGlowBackground(
            modifier = Modifier.fillMaxSize(),
            isVisible = isModelLoaded
        )

        // Placeholder while loading
        if (!isModelLoaded) {
            LoadingPlaceholder(
                modifier = Modifier.fillMaxSize()
            )
        }

        // SceneView for 3D rendering
        SceneViewComposable(
            modelName = modelName,
            rotationY = if (autoRotate) rotationY else 0f,
            onModelLoaded = { isModelLoaded = true },
            modifier = Modifier
                .fillMaxSize()
                .alpha(animatedAlpha)
                .scale(animatedScale)
        )

        // Bottom fade mask (matching iOS gradient mask)
        BottomFadeMask(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .align(Alignment.BottomCenter)
        )
    }
}

@Composable
private fun SceneViewComposable(
    modelName: String,
    rotationY: Float,
    onModelLoaded: () -> Unit,
    modifier: Modifier = Modifier
) {
    var modelNode by remember { mutableStateOf<ModelNode?>(null) }

    // Update rotation when rotationY changes
    LaunchedEffect(rotationY) {
        modelNode?.rotation = Rotation(y = rotationY)
    }

    AndroidView(
        factory = { ctx ->
            SceneView(ctx, isOpaque = false).apply {

                // Configure camera
                cameraNode.position = Position(z = 4f)

                // Load model on the main thread after SceneView is fully initialized
                val assetPath = "models/$modelName.glb"
                post {
                    try {
                        // Read the GLB file as a ByteBuffer from assets
                        val buffer = ctx.assets.open(assetPath).use { stream ->
                            val bytes = stream.readBytes()
                            java.nio.ByteBuffer.allocateDirect(bytes.size).apply {
                                put(bytes)
                                rewind()
                            }
                        }
                        Log.d("ModelViewer", "Read ${buffer.capacity()} bytes from $assetPath")

                        val instance = modelLoader.createModelInstance(buffer)
                        val node = ModelNode(
                            modelInstance = instance
                        ).apply {
                            position = Position(y = -0.5f)
                            scale = io.github.sceneview.math.Scale(1.5f)
                        }
                        addChildNode(node)
                        modelNode = node
                        onModelLoaded()
                        Log.d("ModelViewer", "Successfully loaded $modelName.glb")
                    } catch (e: Exception) {
                        Log.e("ModelViewer", "Failed to load $modelName.glb: ${e.message}", e)
                    }
                }
            }
        },
        modifier = modifier,
        update = { _ ->
            // Update rotation
            modelNode?.rotation = Rotation(y = rotationY)
        }
    )
}

/**
 * Radial glow background behind the 3D model
 */
@Composable
fun RadialGlowBackground(
    modifier: Modifier = Modifier,
    isVisible: Boolean = true
) {
    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(durationMillis = 1000),
        label = "glowAlpha"
    )

    Box(
        modifier = modifier
            .alpha(animatedAlpha)
            .background(
                brush = Brush.radialGradient(
                    colors = listOf(
                        Color(0xFF2E3192).copy(alpha = 0.3f),
                        Color.Transparent
                    )
                )
            )
    )
}

/**
 * Loading placeholder with pulsing animation
 */
@Composable
fun LoadingPlaceholder(
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "loading")
    val scale by infiniteTransition.animateFloat(
        initialValue = 0.8f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseScale"
    )

    val alpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.6f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseAlpha"
    )

    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .size(200.dp)
                .scale(scale)
                .blur(40.dp)
                .background(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            Color(0xFF2E3192).copy(alpha = alpha),
                            Color.Transparent
                        )
                    ),
                    shape = CircleShape
                )
        )
    }
}

/**
 * Gradient mask for bottom fade effect (matching iOS LinearGradient mask)
 */
@Composable
fun BottomFadeMask(
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color.Transparent,
                        MaterialTheme.colorScheme.background.copy(alpha = 0.6f),
                        MaterialTheme.colorScheme.background
                    )
                )
            )
    )
}
