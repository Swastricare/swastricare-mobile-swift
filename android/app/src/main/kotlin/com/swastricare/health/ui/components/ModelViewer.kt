package com.swastricare.health.ui.components

import android.util.Log
import android.view.SurfaceHolder
import android.view.View
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.*
import com.swastricare.health.ui.theme.AppColors
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.viewinterop.AndroidView
import io.github.sceneview.SceneView
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import io.github.sceneview.math.colorOf
import io.github.sceneview.node.ModelNode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.nio.ByteBuffer

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
            rotationY = if (autoRotate) rotationY else 270f,
            allowInteraction = allowInteraction,
            onModelLoaded = { isModelLoaded = true },
            modifier = Modifier.fillMaxSize()
        )

        // Bottom blending fade mask — visible in transparent scene areas around the model
        BottomFadeMask(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.65f)
                .align(Alignment.BottomCenter)
        )
    }
}

@Composable
private fun SceneViewComposable(
    modelName: String,
    rotationY: Float,
    allowInteraction: Boolean,
    onModelLoaded: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var modelNode by remember { mutableStateOf<ModelNode?>(null) }
    var sceneView by remember { mutableStateOf<SceneView?>(null) }

    // Track whether this screen is currently RESUMED.
    // When navigation starts an exit transition the back-stack entry goes RESUMED → STARTED.
    // We set the SurfaceView GONE at that point so it can't punch through the incoming screen.
    var isScreenActive by remember { mutableStateOf(true) }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> isScreenActive = true
                Lifecycle.Event.ON_PAUSE  -> isScreenActive = false
                else -> {}
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // Load the GLB model bytes off the main thread to avoid ANR on large assets (~13MB)
    val assetPath = "models/$modelName.glb"
    var modelBuffer by remember { mutableStateOf<ByteBuffer?>(null) }

    LaunchedEffect(assetPath) {
        modelBuffer = withContext(Dispatchers.IO) {
            try {
                context.assets.open(assetPath).use { stream ->
                    val bytes = stream.readBytes()
                    Log.d(TAG, "Read ${bytes.size} bytes from $assetPath on IO thread")
                    ByteBuffer.allocateDirect(bytes.size).apply {
                        put(bytes)
                        rewind()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "!!! Failed to read model asset: ${e.message}", e)
                null
            }
        }
    }

    // Update rotation when rotationY changes
    LaunchedEffect(rotationY) {
        modelNode?.rotation = Rotation(y = rotationY)
    }

    // Lifecycle cleanup: destroy model node and release SceneView resources when leaving
    DisposableEffect(Unit) {
        onDispose {
            Log.d(TAG, "DisposableEffect onDispose: cleaning up SceneView resources")
            modelNode?.let { node ->
                try {
                    sceneView?.removeChildNode(node)
                    node.destroy()
                    Log.d(TAG, "ModelNode destroyed")
                } catch (e: Exception) {
                    Log.w(TAG, "Error destroying ModelNode: ${e.message}")
                }
            }
            modelNode = null
            sceneView?.let { sv ->
                try {
                    sv.destroy()
                    Log.d(TAG, "SceneView destroyed")
                } catch (e: Exception) {
                    Log.w(TAG, "Error destroying SceneView: ${e.message}")
                }
            }
            sceneView = null
        }
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

                    // Camera: model bbox is ~0.2 x 1.0 x 0.6 units; scale 1.5 -> ~0.3 x 1.5 x 0.9
                    cameraNode.position = Position(z = 3.0f)

                    // Disable gesture interaction when not allowed
                    if (!allowInteraction) {
                        setOnTouchListener { _, _ -> true }
                    }

                    sceneView = this
                }
            } catch (e: Exception) {
                // SceneView constructor failed (GPU incompatibility, etc.)
                Log.e(TAG, "!!! SceneView CREATION FAILED: ${e.message}", e)
                android.widget.FrameLayout(ctx)
            }
        },
        modifier = modifier,
        update = { view ->
            // Hide the SurfaceView while not RESUMED — prevents it punching through
            // incoming screens during nav exit transitions (SurfaceView is z-ordered above
            // the Compose canvas and cannot be masked by any Compose overlay).
            view.visibility = if (isScreenActive) View.VISIBLE else View.GONE

            // Apply rotation on every recomposition
            modelNode?.rotation = Rotation(y = rotationY)

            // Once the buffer is loaded and we have a SceneView, create the model instance
            val buffer = modelBuffer
            if (buffer != null && modelNode == null && view is SceneView) {
                try {
                    Log.d(TAG, "Creating model instance from ${buffer.capacity()} byte buffer")

                    val instance = view.modelLoader.createModelInstance(buffer)
                    Log.d(TAG, "ModelInstance OK")

                    // Create and apply a programmatic material (ensures visibility on ALL GPUs)
                    val material = view.materialLoader.createColorInstance(
                        color = colorOf(rgb = 0.82f),
                        metallic = 0.0f,
                        roughness = 0.65f,
                        reflectance = 0.35f
                    )

                    val node = ModelNode(modelInstance = instance).apply {
                        position = Position(y = 0.0f)
                        scale = io.github.sceneview.math.Scale(2.5f)
                        // Apply material to ALL renderable nodes
                        renderableNodes.forEach { renderable ->
                            try {
                                renderable.setMaterialInstances(material)
                            } catch (e: Exception) {
                                Log.w(TAG, "Material apply failed: ${e.message}")
                            }
                        }
                    }
                    view.addChildNode(node)
                    modelNode = node
                    onModelLoaded()
                    Log.d(TAG, "=== SUCCESS: ${node.renderableNodes.size} renderables ===")

                } catch (e: Exception) {
                    Log.e(TAG, "!!! MODEL CREATION FAILED: ${e.message}", e)
                    onModelLoaded() // Clear loading placeholder to avoid infinite spinner
                }
            }
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
 * Gradient mask for bottom fade effect.
 *
 * NOTE: SceneView uses SurfaceView with setZOrderOnTop(true), so this gradient
 * renders on the window surface BELOW the 3D model surface. It is only visible
 * in the transparent areas of the scene (where the model is NOT rendered).
 * The model itself is viewport-clipped by pushing its Y position downward.
 */
@Composable
fun BottomFadeMask(
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .background(
                brush = Brush.verticalGradient(
                    colorStops = arrayOf(
                        0.0f to Color.Transparent,
                        0.12f to AppColors.background.copy(alpha = 0.25f),
                        0.30f to AppColors.background.copy(alpha = 0.55f),
                        0.52f to AppColors.background.copy(alpha = 0.80f),
                        0.72f to AppColors.background.copy(alpha = 0.94f),
                        1.0f to AppColors.background
                    )
                )
            )
    )
}
