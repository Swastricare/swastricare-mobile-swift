package com.swasthicare.mobile.ui.screens.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bed
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocalDrink
import androidx.compose.material.icons.filled.Medication
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.swasthicare.mobile.ui.theme.*

@Composable
fun HomeScreen(
    viewModel: HomeViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val scrollState = rememberScrollState()
    
    Box(modifier = Modifier.fillMaxSize()) {
        // 1. Premium Animated Background
        PremiumBackground()
        
        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .verticalScroll(scrollState)
            ) {
                // 2. Header
                LivingStatusHeader(
                    userName = uiState.userName,
                    greeting = uiState.greeting,
                    statusColor = SecondaryColor
                )
                
                Spacer(modifier = Modifier.height(20.dp))
                
                // 3. Body Status Section
                Text(
                    text = "Daily Activity",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 20.dp)
                )
                
                Spacer(modifier = Modifier.height(16.dp))
                
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    // Activity Stats Column
                    Column(
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                        modifier = Modifier.weight(0.45f)
                    ) {
                        ActivityStatRow(
                            icon = Icons.Default.DirectionsWalk,
                            value = "${uiState.stepCount}",
                            label = "Steps",
                            color = SecondaryColor
                        )
                         ActivityStatRow(
                            icon = Icons.Default.Favorite,
                            value = "${uiState.calories}",
                            label = "Kcal",
                            color = ActivityColor
                        )
                         ActivityStatRow(
                            icon = Icons.Default.LocalDrink,
                            value = "${uiState.activeMinutes}",
                            label = "Active Min",
                            color = HydrationColor
                        )
                    }
                    
                    Spacer(modifier = Modifier.width(16.dp))
                    
                    // Body Silhouette
                     Box(
                        modifier = Modifier
                            .weight(0.55f)
                            .height(320.dp)
                            .glass(cornerRadius = 20.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        BodySilhouette(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.2f))
                        
                        // Overlay some "scanning" effect or status dots
                        ScanningEffect()
                    }
                }
                
                Spacer(modifier = Modifier.height(30.dp))
                
                // 4. Vitals Grid
                Text(
                    text = "Health Vitals",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(horizontal = 20.dp)
                )
                
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    VitalCard(
                        icon = Icons.Default.Favorite,
                        title = "Heart Rate",
                        value = "${uiState.heartRate}",
                        unit = "BPM",
                        color = HeartRateColor,
                        modifier = Modifier.weight(1f),
                        delay = 100
                    )
                    
                    VitalCard(
                        icon = Icons.Default.Bed,
                        title = "Sleep",
                        value = uiState.sleepHours,
                        unit = "",
                        color = SleepColor,
                        modifier = Modifier.weight(1f),
                        delay = 200
                    )
                    
                     VitalCard(
                        icon = Icons.Default.DirectionsWalk,
                        title = "Distance",
                        value = "${uiState.distance}",
                        unit = "km",
                        color = SecondaryColor,
                        modifier = Modifier.weight(1f),
                        delay = 300
                    )
                }
                
                Spacer(modifier = Modifier.height(20.dp))
                
                // 5. Complex Widgets (Hydration & Medication)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp),
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // Medication Card
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(180.dp)
                            .glass(cornerRadius = 24.dp)
                            .clickable { /* TODO */ }
                    ) {
                        val progress = uiState.medicationsTaken.toFloat() / uiState.medicationsTotal.toFloat()
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .clip(RoundedCornerShape(24.dp))
                        ) {
                            // Liquid
                            Box(
                                modifier = Modifier
                                    .align(Alignment.BottomCenter)
                                    .fillMaxWidth()
                                    .fillMaxHeight(progress)
                                    .background(
                                        brush = androidx.compose.ui.graphics.Brush.verticalGradient(
                                            colors = listOf(
                                                PrimaryColor.copy(alpha = 0.6f),
                                                SleepColor.copy(alpha = 0.6f)
                                            )
                                        )
                                    )
                            ) {
                                 RisingBubblesEffect(color = Color.White.copy(alpha = 0.3f))
                            }
                        }
                        
                        // Content
                        Column(
                            modifier = Modifier.padding(16.dp),
                            verticalArrangement = Arrangement.SpaceBetween
                        ) {
                            Icon(
                                imageVector = Icons.Default.Medication,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurface,
                                modifier = Modifier.size(24.dp)
                            )
                            
                            Column {
                                Text(
                                    "Medication",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.9f)
                                )
                                Row(verticalAlignment = Alignment.Bottom) {
                                    Text(
                                        "${uiState.medicationsTaken}",
                                        style = MaterialTheme.typography.headlineMedium,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        "/${uiState.medicationsTotal}",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                                        modifier = Modifier.padding(bottom = 4.dp, start = 2.dp)
                                    )
                                }
                            }
                        }
                    }
                    
                    // Hydration Card
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(180.dp)
                            .glass(cornerRadius = 24.dp)
                            .clickable { viewModel.incrementHydration() }
                    ) {
                        val progress = uiState.hydrationCurrent.toFloat() / uiState.hydrationGoal.toFloat()
                        
                        Box(
                             modifier = Modifier
                                .fillMaxSize()
                                .clip(RoundedCornerShape(24.dp))
                        ) {
                             WaterWave(
                                progress = progress,
                                color = HydrationColor.copy(alpha = 0.3f),
                                modifier = Modifier.fillMaxSize()
                            )
                            WaterWave(
                                progress = progress,
                                color = HydrationColor.copy(alpha = 0.4f),
                                 modifier = Modifier.fillMaxSize().padding(top = 5.dp)
                            )
                        }
                        
                         Column(
                            modifier = Modifier.padding(16.dp),
                            verticalArrangement = Arrangement.SpaceBetween
                        ) {
                            Icon(
                                imageVector = Icons.Default.LocalDrink,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurface,
                                modifier = Modifier.size(24.dp)
                            )
                            
                            Column {
                                Text(
                                    "Hydration",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.9f)
                                )
                                Text(
                                    "${uiState.hydrationCurrent} ml",
                                    style = MaterialTheme.typography.titleLarge,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    "Goal: ${uiState.hydrationGoal}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                                )
                            }
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(120.dp)) // Extra space for bottom bar
            }
        }
    }
}

@Composable
fun ActivityStatRow(icon: androidx.compose.ui.graphics.vector.ImageVector, value: String, label: String, color: Color) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 16.dp)
            .padding(horizontal = 12.dp, vertical = 12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(color.copy(alpha = 0.2f), androidx.compose.foundation.shape.CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
        }
        Column {
            Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
fun BodySilhouette(color: Color) {
    Canvas(modifier = Modifier.fillMaxSize().padding(20.dp)) {
        val width = size.width
        val height = size.height
        val cx = width / 2
        val headRadius = width * 0.15f // Moved up
        
        val path = Path().apply {
            // Head
            addOval(androidx.compose.ui.geometry.Rect(cx - headRadius, 0f, cx + headRadius, headRadius * 2))
            
            // Neck
            moveTo(cx - headRadius * 0.6f, headRadius * 1.8f)
            quadraticBezierTo(cx, headRadius * 2.2f, cx + headRadius * 0.6f, headRadius * 1.8f)
            
            // Shoulders
            moveTo(cx - headRadius * 0.6f, headRadius * 1.9f)
            quadraticBezierTo(cx - width * 0.35f, headRadius * 2.2f, cx - width * 0.35f, headRadius * 3.5f) // Left shoulder
            
            moveTo(cx + headRadius * 0.6f, headRadius * 1.9f)
            quadraticBezierTo(cx + width * 0.35f, headRadius * 2.2f, cx + width * 0.35f, headRadius * 3.5f) // Right shoulder

            // Torso
            moveTo(cx - width * 0.35f, headRadius * 3.5f)
            lineTo(cx - width * 0.25f, height * 0.45f) // Waist Left
            quadraticBezierTo(cx - width * 0.28f, height * 0.55f, cx - width * 0.15f, height * 0.8f) // Left Leg Start
            
            moveTo(cx + width * 0.35f, headRadius * 3.5f)
            lineTo(cx + width * 0.25f, height * 0.45f) // Waist Right
            quadraticBezierTo(cx + width * 0.28f, height * 0.55f, cx + width * 0.15f, height * 0.8f) // Right Leg Start
            
            // Legs (Abstracted)
            moveTo(cx - width * 0.15f, height * 0.8f)
            lineTo(cx - width * 0.1f, height * 0.95f)
            
            moveTo(cx + width * 0.15f, height * 0.8f)
            lineTo(cx + width * 0.1f, height * 0.95f)
        }
        
        // Draw Fill
        drawPath(path, color = color.copy(alpha = 0.1f), style = Fill)
        
        // Draw Stroke
        drawPath(path, color = color, style = Stroke(width = 2.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round))
        
        // Draw Joints/Points
        val jointColor = SecondaryColor
        drawCircle(jointColor, radius = 4.dp.toPx(), center = Offset(cx, headRadius)) // Head center
        drawCircle(jointColor, radius = 4.dp.toPx(), center = Offset(cx - width * 0.35f, headRadius * 3.5f)) // L Shoulder
        drawCircle(jointColor, radius = 4.dp.toPx(), center = Offset(cx + width * 0.35f, headRadius * 3.5f)) // R Shoulder
        drawCircle(jointColor, radius = 4.dp.toPx(), center = Offset(cx, height * 0.45f)) // Core
    }
}

@Composable
fun ScanningEffect() {
    val infiniteTransition = rememberInfiniteTransition(label = "scan")
    val offsetY by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "scanLine"
    )
    
    Canvas(modifier = Modifier.fillMaxSize()) {
        val lineY = size.height * offsetY
        
        drawLine(
            color = SecondaryColor.copy(alpha = 0.8f),
            start = Offset(0f, lineY),
            end = Offset(size.width, lineY),
            strokeWidth = 2.dp.toPx()
        )
        
        // Glow effect
        drawRect(
            brush = androidx.compose.ui.graphics.Brush.verticalGradient(
                colors = listOf(SecondaryColor.copy(alpha = 0f), SecondaryColor.copy(alpha = 0.3f)),
                startY = lineY - 50.dp.toPx(),
                endY = lineY
            ),
            topLeft = Offset(0f, lineY - 50.dp.toPx()),
            size = Size(size.width, 50.dp.toPx())
        )
    }
}
