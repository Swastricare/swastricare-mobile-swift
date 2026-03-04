package com.swasthicare.mobile.ui.components

import android.util.Log
import android.view.SurfaceHolder
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
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import io.github.sceneview.SceneView
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import io.github.sceneview.math.colorOf
import io.github.sceneview.node.ModelNode

private const val TAG = "ModelViewer"

/**
 * 3D Model Viewer Component using SceneView (Filament wrapper)
 *
 * IMPORTANT: No Compose alpha/scale modifiers are applied to the SceneView AndroidView.
 * SurfaceView with setZOrderOnTop(true) does not respect View.setAlpha() consistently
 * across GPU vendors (Mali, Adreno, etc.). The SceneView is always rendered at full opacity.
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
        modifier = modifier.clipToBounds(),
        contentAlignment = Alignment.Center
    ) {
        // Background glow effect (fades in when model is loaded)
        RadialGlowBackground(
            modifier = Modifier.fillMaxSize(),
            isVisible = isModelLoaded
        )

        // Placeholder while loading (fades out when model loads)
        if (!isModelLoaded) {
            LoadingPlaceholder(
                modifier = Modifier.fillMaxSize()
            )
        }

        // SceneView for 3D rendering
        // CRITICAL: Do NOT apply .alpha() or .scale() to this — breaks SurfaceView on many GPUs
        SceneViewComposable(
            modelName = modelName,
            rotationY = if (autoRotate) rotationY else 0f,
            onModelLoaded = { isModelLoaded = true },
            modifier = Modifier.fillMaxSize()
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
            Log.d(TAG, "=== SceneView Factory START ===")
            try {
                SceneView(ctx, isOpaque = false).apply {
                    Log.d(TAG, "SceneView constructed (isOpaque=false)")

                    // Debug: Surface lifecycle
                    holder.addCallback(object : SurfaceHolder.Callback {
                        override fun surfaceCreated(holder: SurfaceHolder) {
                            Log.d(TAG, "Surface CREATED")
                        }
                        override fun surfaceChanged(holder: SurfaceHolder, format: Int, w: Int, h: Int) {
                            Log.d(TAG, "Surface CHANGED: ${w}x${h} format=$format")
                        }
                        override fun surfaceDestroyed(holder: SurfaceHolder) {
                            Log.w(TAG, "Surface DESTROYED")
                        }
                    })

                    // Camera: model bbox is ~0.2 x 1.0 x 0.6 units; scale 1.5 → ~0.3 x 1.5 x 0.9
                    cameraNode.position = Position(z = 3.0f)

                    // Load model on main/GL thread after layout
                    val assetPath = "models/$modelName.glb"
                    post {
                        Log.d(TAG, "Post: view=${width}x${height}")
                        try {
                            val buffer = ctx.assets.open(assetPath).use { stream ->
                                val bytes = stream.readBytes()
                                java.nio.ByteBuffer.allocateDirect(bytes.size).apply {
                                    put(bytes)
                                    rewind()
                                }
                            }
                            Log.d(TAG, "Read ${buffer.capacity()} bytes")

                            val instance = modelLoader.createModelInstance(buffer)
                            Log.d(TAG, "ModelInstance OK")

                            // Create and apply a programmatic material (ensures visibility on ALL GPUs)
                            val material = materialLoader.createColorInstance(
                                color = colorOf(rgb = 0.82f),
                                metallic = 0.0f,
                                roughness = 0.65f,
                                reflectance = 0.35f
                            )

                            val node = ModelNode(modelInstance = instance).apply {
                                position = Position(y = -0.5f)
                                scale = io.github.sceneview.math.Scale(1.5f)
                                // Apply material to ALL renderable nodes
                                renderableNodes.forEach { renderable ->
                                    try {
                                        renderable.setMaterialInstances(material)
                                    } catch (e: Exception) {
                                        Log.w(TAG, "Material apply failed: ${e.message}")
                                    }
                                }
                            }
                            addChildNode(node)
                            modelNode = node
                            onModelLoaded()
                            Log.d(TAG, "=== SUCCESS: ${node.renderableNodes.size} renderables ===")

                        } catch (e: Exception) {
                            Log.e(TAG, "!!! LOAD FAILED: ${e.message}", e)
                        }
                    }
                }
            } catch (e: Exception) {
                // SceneView constructor failed (GPU incompatibility, etc.)
                Log.e(TAG, "!!! SceneView CREATION FAILED: ${e.message}", e)
                android.widget.FrameLayout(ctx)
            }
        },
        modifier = modifier,
        update = { _ ->
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
