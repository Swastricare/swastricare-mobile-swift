package com.swasthicare.mobile.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.abs
import kotlin.math.roundToInt

// ─────────────────────────────────────
// MARK: - RulerPicker
// ─────────────────────────────────────

/**
 * Horizontal scrolling ruler picker for numeric input.
 * Used for height (cm) and weight (kg) selection.
 *
 * Matches the iOS RulerPicker component.
 */
@Composable
fun RulerPicker(
    value: Int,
    onValueChange: (Int) -> Unit,
    minValue: Int = 100,
    maxValue: Int = 250,
    unit: String = "cm",
    accentColor: Color = MaterialTheme.colorScheme.primary,
    modifier: Modifier = Modifier
) {
    val density = LocalDensity.current
    val textMeasurer = rememberTextMeasurer()

    // Ruler dimensions
    val tickSpacingDp = 8.dp
    val tickSpacingPx = with(density) { tickSpacingDp.toPx() }
    val rulerHeight = 80.dp
    val rulerHeightPx = with(density) { rulerHeight.toPx() }

    // Calculate offset based on current value
    var dragOffset by remember(value) {
        mutableFloatStateOf((value - minValue) * tickSpacingPx)
    }

    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Current value display
        Text(
            text = "$value $unit",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = accentColor
        )

        Spacer(Modifier.height(8.dp))

        // Ruler Canvas
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(rulerHeight)
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f))
        ) {
            Canvas(
                modifier = Modifier
                    .fillMaxSize()
                    .pointerInput(Unit) {
                        detectDragGestures { change, dragAmount ->
                            change.consume()
                            dragOffset -= dragAmount.x
                            val newValue = ((dragOffset / tickSpacingPx) + minValue)
                                .roundToInt()
                                .coerceIn(minValue, maxValue)
                            onValueChange(newValue)
                        }
                    }
            ) {
                val canvasWidth = size.width
                val canvasHeight = size.height
                val centerX = canvasWidth / 2f

                val totalTicks = maxValue - minValue
                val startTick = ((dragOffset - canvasWidth) / tickSpacingPx).toInt().coerceAtLeast(0)
                val endTick = ((dragOffset + canvasWidth) / tickSpacingPx).toInt().coerceAtMost(totalTicks)

                for (i in startTick..endTick) {
                    val tickValue = minValue + i
                    val x = centerX - dragOffset + (i * tickSpacingPx)

                    if (x < -20f || x > canvasWidth + 20f) continue

                    val isMajor = tickValue % 10 == 0
                    val isMid = tickValue % 5 == 0

                    val tickHeight = when {
                        isMajor -> canvasHeight * 0.6f
                        isMid -> canvasHeight * 0.4f
                        else -> canvasHeight * 0.25f
                    }

                    val tickWidth = if (isMajor) 2.5f else 1.5f
                    val tickAlpha = when {
                        abs(x - centerX) < tickSpacingPx -> 1f
                        abs(x - centerX) < canvasWidth * 0.3f -> 0.7f
                        else -> 0.3f
                    }

                    val tickColor = if (abs(x - centerX) < tickSpacingPx * 0.5f)
                        accentColor else Color.Gray.copy(alpha = tickAlpha)

                    drawLine(
                        color = tickColor,
                        start = Offset(x, canvasHeight - tickHeight),
                        end = Offset(x, canvasHeight),
                        strokeWidth = tickWidth
                    )

                    // Draw label for major ticks
                    if (isMajor) {
                        val labelText = tickValue.toString()
                        val textResult = textMeasurer.measure(
                            text = labelText,
                            style = TextStyle(
                                fontSize = 10.sp,
                                color = tickColor,
                                fontWeight = FontWeight.Medium
                            )
                        )
                        drawText(
                            textLayoutResult = textResult,
                            topLeft = Offset(
                                x - textResult.size.width / 2f,
                                canvasHeight - tickHeight - textResult.size.height - 4f
                            )
                        )
                    }
                }

                // Center indicator line
                drawLine(
                    color = accentColor,
                    start = Offset(centerX, 0f),
                    end = Offset(centerX, canvasHeight),
                    strokeWidth = 3f
                )

                // Center indicator triangle
                val triSize = 8f
                drawPath(
                    path = androidx.compose.ui.graphics.Path().apply {
                        moveTo(centerX - triSize, 0f)
                        lineTo(centerX + triSize, 0f)
                        lineTo(centerX, triSize * 1.5f)
                        close()
                    },
                    color = accentColor
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - ScaleOnPress Modifier
// ─────────────────────────────────────

/**
 * Adds a spring press animation to any composable.
 * When pressed, the composable scales down slightly and bounces back.
 * Matches the iOS ScaleButtonStyle.
 */
fun Modifier.scaleOnPress(
    pressedScale: Float = 0.95f,
    animationSpec: AnimationSpec<Float> = spring(
        dampingRatio = Spring.DampingRatioMediumBouncy,
        stiffness = Spring.StiffnessLow
    )
): Modifier = composed {
    var isPressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isPressed) pressedScale else 1f,
        animationSpec = animationSpec,
        label = "scaleOnPress"
    )

    this
        .graphicsLayer {
            scaleX = scale
            scaleY = scale
        }
        .pointerInput(Unit) {
            detectTapGestures(
                onPress = {
                    isPressed = true
                    tryAwaitRelease()
                    isPressed = false
                }
            )
        }
}

// ─────────────────────────────────────
// MARK: - Shimmer Modifier
// ─────────────────────────────────────

/**
 * Adds a shimmer/skeleton loading effect to any composable.
 * Use with a placeholder shape to indicate loading state.
 */
fun Modifier.shimmer(): Modifier = composed {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val translateAnim by transition.animateFloat(
        initialValue = -1f,
        targetValue = 2f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1200, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "shimmerTranslate"
    )

    val shimmerColors = listOf(
        Color.LightGray.copy(alpha = 0.3f),
        Color.LightGray.copy(alpha = 0.5f),
        Color.LightGray.copy(alpha = 0.3f)
    )

    this.background(
        brush = Brush.linearGradient(
            colors = shimmerColors,
            start = Offset(translateAnim * 200f, 0f),
            end = Offset((translateAnim + 1f) * 200f, 0f)
        )
    )
}

/**
 * Pre-built skeleton shape for loading states.
 * Rounded rectangle with shimmer effect.
 */
@Composable
fun SkeletonShape(
    width: Dp = Dp.Unspecified,
    height: Dp = 16.dp,
    cornerRadius: Dp = 8.dp,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .then(if (width != Dp.Unspecified) Modifier.width(width) else Modifier.fillMaxWidth())
            .height(height)
            .clip(RoundedCornerShape(cornerRadius))
            .shimmer()
    )
}

/**
 * Pre-built skeleton circle for avatar/icon loading states.
 */
@Composable
fun SkeletonCircle(
    size: Dp = 40.dp,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .size(size)
            .clip(RoundedCornerShape(size / 2))
            .shimmer()
    )
}

// ─────────────────────────────────────
// MARK: - Custom Styled Date Picker
// ─────────────────────────────────────

/**
 * Wrapper function to style the system DatePickerDialog
 * with the app's design system colors.
 * Usage: call from a button onClick, pass result to callback.
 */
// Note: Android DatePickerDialog is shown via Dialog composable
// This is a themed configuration helper matching the design system.
// Use `DatePickerDialog` from Material3 directly in composables.
