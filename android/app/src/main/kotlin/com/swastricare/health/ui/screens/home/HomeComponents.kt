package com.swastricare.health.ui.screens.home

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.geometry.Size
import com.swastricare.health.ui.components.DailyMetric
import com.swastricare.health.ui.theme.StepsColor
import com.swastricare.health.ui.theme.ActivityColor
import com.swastricare.health.ui.theme.HeartRateColor
import com.swastricare.health.ui.theme.SleepColor
import com.swastricare.health.ui.theme.DistanceColor
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PremiumColor
import com.swastricare.health.ui.theme.PrimaryColor
import java.util.Calendar
import java.util.Date
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

// MARK: - Glass Modifier
@Composable
fun Modifier.glass(
    cornerRadius: Dp = 20.dp,
    opacity: Float = 0.25f,
    strokeWidth: Dp = 0.5.dp,
    accentColor: Color? = null
): Modifier {
    val isDark = isSystemInDarkTheme()
    val borderColor = if (isDark) Color.White.copy(alpha = 0.18f) else Color.Black.copy(alpha = 0.3f)
    val backgroundColor = if (isDark) AppColors.surface else Color.White

    // If accentColor provided, use a gradient border from accent to transparent
    val borderBrush = if (accentColor != null) {
        Brush.linearGradient(
            colors = listOf(
                accentColor.copy(alpha = 0.5f),
                borderColor.copy(alpha = 0.15f),
                borderColor.copy(alpha = 0.05f),
                accentColor.copy(alpha = 0.3f)
            ),
            start = Offset.Zero,
            end = Offset.Infinite
        )
    } else {
        Brush.linearGradient(
            colors = listOf(
                borderColor,
                borderColor.copy(alpha = 0.05f),
                borderColor.copy(alpha = 0.05f),
                borderColor
            ),
            start = Offset.Zero,
            end = Offset.Infinite
        )
    }

    val shadowElevation = if (isDark) 2.dp else 4.dp
    val shadowColor = if (isDark) Color.Black else Color(0xFF000000)

    return this
        .shadow(
            elevation = shadowElevation,
            shape = RoundedCornerShape(cornerRadius),
            spotColor = shadowColor.copy(alpha = if (isDark) 0.4f else 0.08f),
            ambientColor = shadowColor.copy(alpha = if (isDark) 0.2f else 0.04f)
        )
        .clip(RoundedCornerShape(cornerRadius))
        .background(backgroundColor.copy(alpha = opacity))
        .border(
            width = strokeWidth,
            brush = borderBrush,
            shape = RoundedCornerShape(cornerRadius)
        )
}

// MARK: - Light Theme Border Modifier
// Adds a visible border (black at 0.3 alpha) only in light theme.
// Use BEFORE .clip() and .background() for correct rendering.
@Composable
fun Modifier.lightBorder(
    cornerRadius: Dp = 16.dp,
    width: Dp = 1.dp
): Modifier {
    val isDark = isSystemInDarkTheme()
    return if (!isDark) {
        this.border(width, Color.Black.copy(alpha = 0.3f), RoundedCornerShape(cornerRadius))
    } else {
        this
    }
}

// MARK: - Shimmer Loading Modifier
@Composable
fun Modifier.shimmer(
    enabled: Boolean = true,
    durationMillis: Int = 1500
): Modifier {
    if (!enabled) return this

    val infiniteTransition = rememberInfiniteTransition(label = "shimmer")
    val shimmerProgress by infiniteTransition.animateFloat(
        initialValue = -1f,
        targetValue = 2f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "shimmerProgress"
    )

    val isDark = isSystemInDarkTheme()
    val baseColor = if (isDark) Color.White.copy(alpha = 0.05f) else Color.Gray.copy(alpha = 0.1f)
    val highlightColor = if (isDark) Color.White.copy(alpha = 0.15f) else Color.White.copy(alpha = 0.6f)

    val shimmerBrush = Brush.linearGradient(
        colors = listOf(baseColor, highlightColor, baseColor),
        start = Offset(shimmerProgress * 1000f - 500f, 0f),
        end = Offset(shimmerProgress * 1000f + 500f, 0f)
    )

    return this.then(
        Modifier.background(brush = shimmerBrush)
    )
}

// MARK: - Premium Background
@Composable
fun PremiumBackground() {
    val isDark = isSystemInDarkTheme()

    if (!isDark) {
        // Light theme: pure white, no tinting
        Box(modifier = Modifier.fillMaxSize().background(Color.White))
        return
    }

    // Dark theme: animated orb blobs
    val infiniteTransition = rememberInfiniteTransition(label = "background")
    
    // Animate positions - slower and smoother
    val offset1 by infiniteTransition.animateFloat(
        initialValue = -120f,
        targetValue = 120f,
        animationSpec = infiniteRepeatable(
            animation = tween(15000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "orb1"
    )
    
    val offset2 by infiniteTransition.animateFloat(
        initialValue = 180f,
        targetValue = -80f,
        animationSpec = infiniteRepeatable(
            animation = tween(12000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "orb2"
    )
    
    val pulse by infiniteTransition.animateFloat(
        initialValue = 0.8f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(4000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    Box(modifier = Modifier.fillMaxSize().background(AppColors.background)) {
        // Gradient overlay for depth
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            AppColors.background.copy(alpha = 0.5f)
                        )
                    )
                )
        )

        // Orb 1 - Deep Blue/Purple
        Box(
            modifier = Modifier
                .offset(x = offset1.dp, y = (-120).dp)
                .size(400.dp)
                .scale(pulse)
                .blur(120.dp)
                .background(
                    brush = Brush.radialGradient(
                        colors = listOf(
                             PremiumColor.RoyalBlueStart.copy(alpha = 0.15f),
                             Color.Transparent
                        )
                    ), 
                    shape = CircleShape
                )
        )
        
        // Orb 2 - Magenta/Pink
        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .offset(x = offset2.dp, y = 150.dp)
                .size(350.dp)
                .blur(110.dp)
                .background(
                     brush = Brush.radialGradient(
                        colors = listOf(
                             PremiumColor.SunsetEnd.copy(alpha = 0.15f),
                             Color.Transparent
                        )
                    ),
                    shape = CircleShape
                )
        )
        
        // Orb 3 - Cyan/Green
        Box(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .offset(x = -80.dp, y = 80.dp)
                .size(250.dp)
                .blur(90.dp)
                .background(
                     brush = Brush.radialGradient(
                        colors = listOf(
                             PremiumColor.NeonGreenEnd.copy(alpha = 0.12f),
                             Color.Transparent
                        )
                    ),
                    shape = CircleShape
                )
        )
    }
}

// MARK: - Living Status Header
@Composable
fun LivingStatusHeader(
    userName: String,
    greeting: String,
    statusColor: Color,
    onNotificationClick: () -> Unit = {}
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = greeting,
                style = MaterialTheme.typography.titleSmall,
                color = statusColor,
                fontWeight = FontWeight.Medium
            )

            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = userName,
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onBackground
                )


            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            // Notification Bell with glass
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .glass(cornerRadius = 22.dp, opacity = 0.15f, strokeWidth = 0.dp)
                    .clickable { onNotificationClick() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Notifications,
                    contentDescription = "Notifications",
                    tint = AppColors.primary,
                    modifier = Modifier.size(20.dp)
                )
            }

        }
    }
}

// MARK: - Water Wave Animation
@Composable
fun WaterWave(
    progress: Float,
    color: Color,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "wave")
    val phase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 2f * PI.toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "phase"
    )

    Canvas(modifier = modifier) {
        val width = size.width
        val height = size.height
        val amplitude = height * 0.05f
        val waterHeight = height * progress
        
        val path = Path()
        path.moveTo(0f, height)
        path.lineTo(0f, height - waterHeight)
        
        // Draw sine wave
        for (x in 0..width.toInt() step 5) {
            val xPos = x.toFloat()
            val relativeX = xPos / width
            val angle = relativeX * 2 * PI.toFloat() + phase
            val yPos = height - waterHeight + sin(angle) * amplitude
            path.lineTo(xPos, yPos)
        }
        
        path.lineTo(width, height)
        path.close()
        
        drawPath(path = path, color = color, style = Fill)
    }
}

// MARK: - Rising Bubbles Effect
@Composable
fun RisingBubblesEffect(
    color: Color,
    modifier: Modifier = Modifier
) {
    BoxWithConstraints(modifier = modifier.clip(RoundedCornerShape(20.dp))) {
        val width = maxWidth
        val height = maxHeight
        
        // Generate random bubbles
        val bubbles = remember { List(10) { RandomBubbleState() } }
        
        bubbles.forEach { bubble ->
            Bubble(state = bubble, containerHeight = height, color = color)
        }
    }
}

data class RandomBubbleState(
    val size: Dp = Random.nextInt(4, 12).dp,
    val xOffsetRatio: Float = Random.nextFloat(),
    val durationMillis: Int = Random.nextInt(2000, 4000),
    val startDelayMillis: Int = Random.nextInt(0, 2000)
)

@Composable
fun Bubble(state: RandomBubbleState, containerHeight: Dp, color: Color) {
    val infiniteTransition = rememberInfiniteTransition(label = "bubble")
    val yOffset by infiniteTransition.animateFloat(
        initialValue = 1f, // Start at bottom (relative 1.0)
        targetValue = -0.2f, // End slightly above top
        animationSpec = infiniteRepeatable(
            animation = tween(state.durationMillis, delayMillis = state.startDelayMillis, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "bubbleY"
    )
    
    // Convert container height to pixels roughly or use Box constraints
    // Since we are inside a Box, we can use alignment or offset
    // Using simple fractional offset for Y
    
    Box(
        modifier = Modifier
            .fillMaxHeight()
            .fillMaxWidth()
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .offset(
                    x = (state.xOffsetRatio * 300).dp, // Approximation, better to use absolute pixels if possible
                    y = -(containerHeight * (1f - yOffset)) // Move up
                )
                .size(state.size)
                .background(color, CircleShape)
        )
    }
}

// MARK: - Vital Card with Staggered Animation
@Composable
fun VitalCard(
    icon: ImageVector,
    title: String,
    value: String,
    unit: String,
    color: Color,
    modifier: Modifier = Modifier,
    delay: Int = 0,
    showCameraBadge: Boolean = false
) {
    var isVisible by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        delay(delay.toLong())
        isVisible = true
    }
    
    // Staggered entry animations
    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(durationMillis = 600, easing = FastOutSlowInEasing),
        label = "cardAlpha"
    )
    
    val animatedScale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0.9f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "cardScale"
    )
    
    val animatedOffset by animateFloatAsState(
        targetValue = if (isVisible) 0f else 20f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "cardOffset"
    )
    
    // Icon rotation animation
    var iconAppeared by remember { mutableStateOf(false) }
    LaunchedEffect(isVisible) {
        if (isVisible) {
            delay(100)
            iconAppeared = true
        }
    }
    
    val iconScale by animateFloatAsState(
        targetValue = if (iconAppeared) 1f else 0f,
        animationSpec = spring(dampingRatio = 0.5f, stiffness = 400f),
        label = "iconScale"
    )
    
    val iconRotation by animateFloatAsState(
        targetValue = if (iconAppeared) 0f else -180f,
        animationSpec = spring(dampingRatio = 0.6f, stiffness = 300f),
        label = "iconRotation"
    )
    
    val isDarkVital = isSystemInDarkTheme()
    Box(
        modifier = modifier
            .graphicsLayer {
                alpha = animatedAlpha
                scaleX = animatedScale
                scaleY = animatedScale
                translationY = animatedOffset
            }
            .clip(RoundedCornerShape(20.dp))
            .background(color.copy(alpha = 0.18f))
//            .border(
//                width = 0.dp,
//                brush = Brush.linearGradient(
//                    colors = listOf(
//                        color.copy(alpha = 0.5f),
//                        color.copy(alpha = 0.15f)
//                    )
//                ),
//                shape = RoundedCornerShape(20.dp)
//            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(14.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // Header with Icon and optional camera badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .graphicsLayer {
                            scaleX = iconScale
                            scaleY = iconScale
                            rotationZ = iconRotation
                        }
                        .background(color.copy(alpha = 0.3f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = color,
                        modifier = Modifier.size(16.dp)
                    )
                }

                if (showCameraBadge) {
                    Box(
                        modifier = Modifier
                            .size(22.dp)
                            .background(color.copy(alpha = 0.1f), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Favorite,
                            contentDescription = "Measure",
                            tint = color.copy(alpha = 0.7f),
                            modifier = Modifier.size(11.dp)
                        )
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )

                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = value,
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.onSurface,
                        maxLines = 1
                    )
                    if (unit.isNotEmpty()) {
                        Text(
                            text = unit,
                            style = MaterialTheme.typography.labelSmall,
                            color = AppColors.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 4.dp)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Animated Section Wrapper for Scroll-Triggered Animations
@Composable
fun AnimatedSection(
    modifier: Modifier = Modifier,
    delay: Int = 0,
    content: @Composable () -> Unit
) {
    var isVisible by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        delay(delay.toLong())
        isVisible = true
    }
    
    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(durationMillis = 500, easing = FastOutSlowInEasing),
        label = "sectionAlpha"
    )
    
    val animatedScale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0.8f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "sectionScale"
    )
    
    Box(
        modifier = modifier.graphicsLayer {
            alpha = animatedAlpha
            scaleX = animatedScale
            scaleY = animatedScale
        }
    ) {
        content()
    }
}

// MARK: - Demo Mode Banner
@Composable
fun DemoModeBanner(
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .background(
                color = Color(0xFFFFA500).copy(alpha = 0.1f),
                shape = RoundedCornerShape(16.dp)
            )
            .border(
                width = 1.dp,
                color = Color(0xFFFFA500).copy(alpha = 0.3f),
                shape = RoundedCornerShape(16.dp)
            )
            .padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = androidx.compose.material.icons.Icons.Default.Favorite,
            contentDescription = null,
            tint = Color(0xFFFFA500),
            modifier = Modifier.size(24.dp)
        )
        
        Column {
            Text(
                text = "Demo Mode Active",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
            Text(
                text = "Showing sample health data. Enable health access for real data.",
                style = MaterialTheme.typography.bodySmall,
                color = AppColors.onSurfaceVariant
            )
        }
    }
}

// MARK: - Nudge Card
@Composable
fun NudgeCard(
    nudge: ServerNudge,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    // Parse accent color (fallback to blue)
    val accentColor = remember(nudge.color) {
        try { Color(android.graphics.Color.parseColor(nudge.color)) }
        catch (_: Exception) { Color(0xFF007AFF) }
    }

    Box(
        modifier = modifier
            .width(240.dp)
            .glass(cornerRadius = 20.dp)
    ) {
        // Colored left accent bar
        Box(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .width(4.dp)
                .fillMaxHeight()
                .clip(RoundedCornerShape(topStart = 20.dp, bottomStart = 20.dp))
                .background(accentColor)
        )
        Row(
            modifier = Modifier
                .padding(start = 12.dp, end = 12.dp, top = 12.dp, bottom = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // Icon
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(accentColor.copy(alpha = 0.15f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Bolt,
                    contentDescription = null,
                    tint = accentColor,
                    modifier = Modifier.size(18.dp)
                )
            }
            // Text
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    nudge.title,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface
                )
                Text(
                    nudge.message,
                    style = MaterialTheme.typography.bodySmall,
                    color = AppColors.onSurface.copy(alpha = 0.7f),
                    maxLines = 2,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
                )
            }
            // Dismiss button
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = "Dismiss",
                tint = AppColors.onSurface.copy(alpha = 0.4f),
                modifier = Modifier
                    .size(18.dp)
                    .clickable { onDismiss() }
                    .align(Alignment.Top)
            )
        }
    }
}

// MARK: - Nudges Card Strip
@Composable
fun NudgesCardStrip(
    nudges: List<ServerNudge>,
    onDismiss: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    if (nudges.isEmpty()) return

    val scrollState = rememberScrollState()
    Row(
        modifier = modifier
            .fillMaxWidth()
            .horizontalScroll(scrollState)
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        nudges.forEach { nudge ->
            NudgeCard(
                nudge = nudge,
                onDismiss = { onDismiss(nudge.id) }
            )
        }
    }
}

// MARK: - Diet Quick Action Card
private val DietOrange = com.swastricare.health.ui.theme.ActivityColor

@Composable
fun DietQuickActionCard(
    calorieCurrent: Int,
    calorieGoal: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val progress = if (calorieGoal > 0) (calorieCurrent.toFloat() / calorieGoal).coerceIn(0f, 1f) else 0f

    val animatedProgress by animateFloatAsState(
        targetValue = progress,
        animationSpec = tween(durationMillis = 1200, easing = FastOutSlowInEasing),
        label = "dietProgress"
    )

    val isDarkDiet = isSystemInDarkTheme()
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(24.dp))
            .background(DietOrange.copy(alpha = 0.12f))
            .clickable { onClick() }
    ) {
        // Orange liquid fill from bottom
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(24.dp))
        ) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .fillMaxHeight(animatedProgress)
                    .background(DietOrange.copy(alpha = 0.45f))
            )
        }

        // Content — spread top to bottom like medication card
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(DietOrange.copy(alpha = 0.2f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.LocalFireDepartment,
                    contentDescription = null,
                    tint = DietOrange,
                    modifier = Modifier.size(18.dp)
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    "Diet",
                    style = MaterialTheme.typography.labelMedium,
                    color = AppColors.onSurface.copy(alpha = 0.8f)
                )
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        "$calorieCurrent",
                        style = MaterialTheme.typography.headlineLarge,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.onSurface
                    )
                    Text(
                        " cal",
                        style = MaterialTheme.typography.bodyMedium,
                        color = AppColors.onSurface.copy(alpha = 0.6f),
                        modifier = Modifier.padding(bottom = 6.dp, start = 2.dp)
                    )
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(DietOrange.copy(alpha = 0.15f))
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(animatedProgress)
                            .fillMaxHeight()
                            .clip(RoundedCornerShape(2.dp))
                            .background(DietOrange)
                    )
                }
                Text(
                    "Goal: $calorieGoal",
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurface.copy(alpha = 0.5f)
                )
            }
        }
    }
}

// MARK: - Cycle Tracker Card
private val CyclePurple = com.swastricare.health.ui.theme.CycleColor

@Composable
fun CycleTrackerCard(
    phaseLabel: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "cyclePulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 0.85f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "cycleScale"
    )
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.2f,
        targetValue = 0.5f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "cycleAlpha"
    )

    val isDarkCycle = isSystemInDarkTheme()
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(24.dp))
            .clickable { onClick() }
    ) {
        // Solid background
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(CyclePurple.copy(alpha = 0.5f))
        )

        // Pulsing circle decoration in top-right corner
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(8.dp)
                .size(60.dp)
                .scale(pulseScale)
                .background(Color.White.copy(alpha = pulseAlpha), CircleShape)
        )

        // Content — spread top to bottom like medication card
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(Color.White.copy(alpha = 0.2f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = androidx.compose.material.icons.Icons.Default.Favorite,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(18.dp)
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    "Cycle",
                    style = MaterialTheme.typography.labelMedium,
                    color = Color.White.copy(alpha = 0.8f)
                )
                Text(
                    phaseLabel,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }
        }
    }
}

// MARK: - Health Authorization Banner
@Composable
fun HealthAuthBanner(
    onRequestAccess: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .glass(cornerRadius = 16.dp)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            imageVector = androidx.compose.material.icons.Icons.Default.Favorite,
            contentDescription = null,
            tint = Color.Red,
            modifier = Modifier.size(40.dp)
        )
        
        Text(
            text = "Enable Health Access",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )
        
        Text(
            text = "Allow SwastriCare to read your health data for personalized insights",
            style = MaterialTheme.typography.bodySmall,
            color = AppColors.onSurfaceVariant,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
        
        androidx.compose.material3.Button(
            onClick = onRequestAccess,
            modifier = Modifier.fillMaxWidth(),
            colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                containerColor = PremiumColor.RoyalBlueStart
            )
        ) {
            Text("Allow Access")
        }
    }
}

// MARK: - Date Chip Strip
@Composable
fun DateChipStrip(
    weekDates: List<Date>,
    selectedDate: Date,
    onDateSelected: (Date) -> Unit,
    modifier: Modifier = Modifier
) {
    val dayFormat = remember { java.text.SimpleDateFormat("EEE", java.util.Locale.getDefault()) }
    val dayNumFormat = remember { java.text.SimpleDateFormat("d", java.util.Locale.getDefault()) }
    val today = Calendar.getInstance().time

    LazyRow(
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(weekDates) { date ->
            val isSelected = isSameDay(date, selectedDate)
            val isToday = isSameDay(date, today)
            val isFuture = date.after(today) && !isToday
            val alpha = if (isFuture) 0.3f else if (isSelected) 1f else 0.6f

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .alpha(alpha)
                    .clip(RoundedCornerShape(20.dp))
                    .background(
                        if (isSelected) PrimaryColor else Color.Transparent
                    )
                    .then(
                        if (!isSelected) Modifier.border(
                            1.dp,
                            Color.White.copy(alpha = 0.15f),
                            RoundedCornerShape(20.dp)
                        ) else Modifier
                    )
                    .clickable(enabled = !isFuture) { onDateSelected(date) }
                    .padding(horizontal = 12.dp, vertical = 10.dp)
            ) {
                Text(
                    text = dayFormat.format(date).uppercase(),
                    style = MaterialTheme.typography.labelSmall,
                    color = if (isSelected) Color.White else AppColors.onSurfaceVariant,
                    fontWeight = FontWeight.Medium
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = dayNumFormat.format(date),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = if (isSelected) Color.White else AppColors.onSurface
                )
                if (isToday && !isSelected) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Box(
                        modifier = Modifier
                            .size(4.dp)
                            .background(PrimaryColor, CircleShape)
                    )
                }
            }
        }
    }
}

private fun isSameDay(d1: Date, d2: Date): Boolean {
    val c1 = Calendar.getInstance().apply { time = d1 }
    val c2 = Calendar.getInstance().apply { time = d2 }
    return c1.get(Calendar.YEAR) == c2.get(Calendar.YEAR) &&
           c1.get(Calendar.DAY_OF_YEAR) == c2.get(Calendar.DAY_OF_YEAR)
}

// MARK: - Metric Color Helper
fun metricColor(metric: MetricType): Color = when (metric) {
    MetricType.STEPS -> StepsColor
    MetricType.CALORIES -> ActivityColor
    MetricType.HEART_RATE -> HeartRateColor
    MetricType.SLEEP -> SleepColor
    MetricType.EXERCISE -> DistanceColor
    MetricType.DISTANCE -> DistanceColor
}

// MARK: - Hero Metric Card
@Composable
fun HeroMetricCard(
    selectedMetric: MetricType,
    currentValue: String,
    weeklySteps: List<DailyMetric>,
    selectedDate: Date,
    modifier: Modifier = Modifier
) {
    val accentColor = metricColor(selectedMetric)

    val chartValues: List<Float> = remember(weeklySteps, selectedMetric) {
        if (weeklySteps.isEmpty()) List(7) { 0f }
        else weeklySteps.map { metric ->
            when (selectedMetric) {
                MetricType.STEPS -> metric.steps.toFloat()
                MetricType.CALORIES -> metric.steps / 20f
                MetricType.EXERCISE -> metric.steps / 100f
                MetricType.DISTANCE -> metric.steps / 1500f
                MetricType.HEART_RATE -> 72f
                MetricType.SLEEP -> 7f
            }
        }
    }

    val maxValue = remember(chartValues) { chartValues.maxOrNull()?.takeIf { it > 0f } ?: 1f }

    var chartKey by remember { mutableStateOf(0) }
    LaunchedEffect(selectedMetric) { chartKey++ }
    val drawProgress by animateFloatAsState(
        targetValue = 1f,
        animationSpec = tween(durationMillis = 800),
        label = "chartDraw"
    )

    val trend: Int = remember(chartValues) {
        if (chartValues.size < 6) 0
        else {
            val recent = chartValues.takeLast(3).average()
            val prior = chartValues.take(3).average()
            if (prior == 0.0) 0
            else (((recent - prior) / prior) * 100).toInt()
        }
    }

    val weeklyAvg = remember(chartValues) {
        val avg = chartValues.filter { it > 0f }.average()
        if (avg.isNaN()) "—" else "%.0f".format(avg)
    }
    val bestDay = remember(chartValues) {
        val best = chartValues.maxOrNull() ?: 0f
        "%.0f".format(best)
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .glass(cornerRadius = 24.dp, opacity = 0.2f, accentColor = accentColor)
            .padding(20.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = selectedMetric.label,
                        style = MaterialTheme.typography.labelLarge,
                        color = AppColors.onSurface.copy(alpha = 0.6f)
                    )
                    Row(
                        verticalAlignment = Alignment.Bottom,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            text = currentValue,
                            style = MaterialTheme.typography.displaySmall,
                            fontWeight = FontWeight.Bold,
                            color = AppColors.onSurface
                        )
                        Text(
                            text = selectedMetric.unit,
                            style = MaterialTheme.typography.bodyMedium,
                            color = AppColors.onSurface.copy(alpha = 0.5f),
                            modifier = Modifier.padding(bottom = 6.dp)
                        )
                    }
                }

                if (trend != 0) {
                    val trendColor = if (trend >= 0) StepsColor else HeartRateColor
                    val arrow = if (trend >= 0) "↑" else "↓"
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(trendColor.copy(alpha = 0.15f))
                            .padding(horizontal = 10.dp, vertical = 5.dp)
                    ) {
                        Text(
                            text = "$arrow ${kotlin.math.abs(trend)}%",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = trendColor
                        )
                    }
                }
            }

            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(100.dp)
            ) {
                if (chartValues.size < 2) return@Canvas

                val width = size.width
                val height = size.height
                val step = width / (chartValues.size - 1)

                val linePath = Path()
                val fillPath = Path()

                chartValues.forEachIndexed { i, value ->
                    val x = i * step
                    val y = height - (value / maxValue) * height * 0.85f
                    if (i == 0) {
                        linePath.moveTo(x, y)
                        fillPath.moveTo(x, height)
                        fillPath.lineTo(x, y)
                    } else {
                        val prevX = (i - 1) * step
                        val prevY = height - (chartValues[i - 1] / maxValue) * height * 0.85f
                        val cpX = (prevX + x) / 2f
                        linePath.cubicTo(cpX, prevY, cpX, y, x, y)
                        fillPath.cubicTo(cpX, prevY, cpX, y, x, y)
                    }
                }
                fillPath.lineTo(chartValues.size * step - step, height)
                fillPath.close()

                clipRect(right = size.width * drawProgress) {
                    drawPath(
                        path = fillPath,
                        brush = Brush.verticalGradient(
                            colors = listOf(
                                accentColor.copy(alpha = 0.3f),
                                accentColor.copy(alpha = 0f)
                            ),
                            startY = 0f,
                            endY = height
                        )
                    )
                    drawPath(
                        path = linePath,
                        color = accentColor,
                        style = Stroke(
                            width = 2.5.dp.toPx(),
                            cap = StrokeCap.Round,
                            join = StrokeJoin.Round
                        )
                    )
                }

                val dotIndex = chartValues.size / 2
                val dotX = dotIndex * step
                val dotY = height - (chartValues[dotIndex] / maxValue) * height * 0.85f
                drawCircle(color = accentColor, radius = 5.dp.toPx(), center = Offset(dotX, dotY))
                drawCircle(color = Color.White, radius = 3.dp.toPx(), center = Offset(dotX, dotY))
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                HeroStatBadge(label = "Weekly Avg", value = weeklyAvg, color = accentColor)
                HeroStatBadge(label = "Best Day", value = bestDay, color = accentColor)
                HeroStatBadge(label = "Unit", value = selectedMetric.unit, color = accentColor)
            }
        }
    }
}

@Composable
private fun HeroStatBadge(label: String, value: String, color: Color) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(color.copy(alpha = 0.1f))
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurface.copy(alpha = 0.5f)
        )
    }
}
