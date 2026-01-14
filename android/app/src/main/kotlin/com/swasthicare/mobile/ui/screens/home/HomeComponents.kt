package com.swasthicare.mobile.ui.screens.home

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.ui.theme.PremiumColor
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

// MARK: - Glass Modifier
@Composable
fun Modifier.glass(
    cornerRadius: Dp = 20.dp,
    opacity: Float = 0.25f, // Increased opacity for better visibility
    strokeWidth: Dp = 1.dp
): Modifier {
    val isDark = isSystemInDarkTheme()
    val borderColor = if (isDark) Color.White.copy(alpha = 0.3f) else Color.White.copy(alpha = 0.4f)
    val backgroundColor = if (isDark) MaterialTheme.colorScheme.surface else Color.White

    return this
        .clip(RoundedCornerShape(cornerRadius))
        .background(backgroundColor.copy(alpha = opacity))
        .border(
            width = strokeWidth,
            brush = Brush.linearGradient(
                colors = listOf(
                    borderColor,
                    borderColor.copy(alpha = 0.05f),
                    borderColor.copy(alpha = 0.05f),
                    borderColor
                ),
                start = Offset.Zero,
                end = Offset.Infinite
            ),
            shape = RoundedCornerShape(cornerRadius)
        )
}

// MARK: - Premium Background
@Composable
fun PremiumBackground() {
    val isDark = isSystemInDarkTheme()
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

    Box(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        // Gradient overlay for depth
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            MaterialTheme.colorScheme.background.copy(alpha = 0.5f)
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
                             PremiumColor.RoyalBlueStart.copy(alpha = if (isDark) 0.15f else 0.08f),
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
                             PremiumColor.SunsetEnd.copy(alpha = if (isDark) 0.15f else 0.08f),
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
                             PremiumColor.NeonGreenEnd.copy(alpha = if (isDark) 0.12f else 0.06f),
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
    statusColor: Color
) {
    val infiniteTransition = rememberInfiniteTransition(label = "heartbeat")
    
    // Pulsing heart animation (matching iOS)
    val heartScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "heartScale"
    )
    
    val heartAlpha by infiniteTransition.animateFloat(
        initialValue = 0.8f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "heartAlpha"
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = greeting,
                style = MaterialTheme.typography.labelLarge,
                color = statusColor,
                fontWeight = FontWeight.Medium
            )
            
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = userName,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onBackground
                )
                
                // Pulsing Heart with scale animation
                Icon(
                    imageVector = androidx.compose.material.icons.Icons.Default.Favorite,
                    contentDescription = "Heart Rate",
                    tint = Color.Red.copy(alpha = heartAlpha),
                    modifier = Modifier
                        .size(24.dp)
                        .scale(heartScale)
                )
            }
        }
        
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            // Notification Bell
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .glass(cornerRadius = 20.dp)
                    .padding(8.dp),
                contentAlignment = Alignment.Center
            ) {
                 Icon(
                    imageVector = androidx.compose.material.icons.Icons.Default.Notifications,
                    contentDescription = "Notifications",
                    tint = MaterialTheme.colorScheme.primary
                )
            }
            
            // Profile Image Placeholder
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color.Gray.copy(alpha = 0.3f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = androidx.compose.material.icons.Icons.Default.Person,
                    contentDescription = "Profile",
                    tint = Color.White
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
    
    Column(
        modifier = modifier
            .graphicsLayer {
                alpha = animatedAlpha
                scaleX = animatedScale
                scaleY = animatedScale
                translationY = animatedOffset
            }
            .glass(cornerRadius = 20.dp)
            .padding(14.dp)
            .fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // Header with Icon and optional camera badge
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .graphicsLayer {
                        scaleX = iconScale
                        scaleY = iconScale
                        rotationZ = iconRotation
                    }
                    .background(color.copy(alpha = 0.15f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = color,
                    modifier = Modifier.size(14.dp)
                )
            }
            
            if (showCameraBadge) {
                Box(
                    modifier = Modifier
                        .size(20.dp)
                        .background(Color.White.copy(alpha = 0.1f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = androidx.compose.material.icons.Icons.Default.Favorite,
                        contentDescription = "Measure",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(10.dp)
                    )
                }
            }
        }
        
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = value,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                if (unit.isNotEmpty()) {
                    Text(
                        text = unit,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(bottom = 4.dp)
                    )
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
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = "Showing sample health data. Enable health access for real data.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
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
            text = "Allow SwasthiCare to read your health data for personalized insights",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
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
