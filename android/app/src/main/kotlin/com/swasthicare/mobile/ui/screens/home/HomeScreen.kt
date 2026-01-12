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
import com.swasthicare.mobile.ui.theme.PremiumColor

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
                CircularProgressIndicator(color = Color.White)
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
                    statusColor = Color.Green
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
                            color = Color.Green
                        )
                         ActivityStatRow(
                            icon = Icons.Default.Favorite,
                            value = "${uiState.calories}",
                            label = "Kcal",
                            color = Color(0xFFFF9500)
                        )
                         ActivityStatRow(
                            icon = Icons.Default.LocalDrink,
                            value = "${uiState.activeMinutes}",
                            label = "Active Min",
                             color = Color.Blue
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
                        BodySilhouette(color = Color.White.copy(alpha = 0.2f))
                        
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
                        color = Color.Red,
                        modifier = Modifier.weight(1f),
                        delay = 100
                    )
                    
                    VitalCard(
                        icon = Icons.Default.Bed,
                        title = "Sleep",
                        value = uiState.sleepHours,
                        unit = "",
                        color = Color(0xFF5856D6),
                        modifier = Modifier.weight(1f),
                        delay = 200
                    )
                    
                     VitalCard(
                        icon = Icons.Default.DirectionsWalk,
                        title = "Distance",
                        value = "${uiState.distance}",
                        unit = "km",
                        color = Color.Green,
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
                                                Color(0xFFAF52DE).copy(alpha = 0.6f),
                                                Color(0xFF5856D6).copy(alpha = 0.6f)
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
                                tint = Color.White,
                                modifier = Modifier.size(24.dp)
                            )
                            
                            Column {
                                Text(
                                    "Medication",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = Color.White.copy(alpha = 0.9f)
                                )
                                Row(verticalAlignment = Alignment.Bottom) {
                                    Text(
                                        "${uiState.medicationsTaken}",
                                        style = MaterialTheme.typography.headlineMedium,
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White
                                    )
                                    Text(
                                        "/${uiState.medicationsTotal}",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = Color.White.copy(alpha = 0.7f),
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
                                color = Color.Blue.copy(alpha = 0.3f),
                                modifier = Modifier.fillMaxSize()
                            )
                            WaterWave(
                                progress = progress,
                                color = Color.Cyan.copy(alpha = 0.4f),
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
                                tint = Color.White,
                                modifier = Modifier.size(24.dp)
                            )
                            
                            Column {
                                Text(
                                    "Hydration",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = Color.White.copy(alpha = 0.9f)
                                )
                                Text(
                                    "${uiState.hydrationCurrent} ml",
                                    style = MaterialTheme.typography.titleLarge,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White
                                )
                                Text(
                                    "Goal: ${uiState.hydrationGoal}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = Color.White.copy(alpha = 0.7f)
                                )
                            }
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(40.dp))
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
        
        val path = Path().apply {
            // Head
            addOval(androidx.compose.ui.geometry.Rect(width/2 - 25.dp.toPx(), 0f, width/2 + 25.dp.toPx(), 50.dp.toPx()))
            
            // Shoulders/Torso (simplified)
            moveTo(width/2, 55.dp.toPx())
            lineTo(width/2 - 60.dp.toPx(), 80.dp.toPx()) // Left Shoulder
            lineTo(width/2 - 50.dp.toPx(), 200.dp.toPx()) // Left Hip
            lineTo(width/2 + 50.dp.toPx(), 200.dp.toPx()) // Right Hip
            lineTo(width/2 + 60.dp.toPx(), 80.dp.toPx()) // Right Shoulder
            close()
            
            // Legs (simplified)
            moveTo(width/2 - 40.dp.toPx(), 205.dp.toPx())
            lineTo(width/2 - 40.dp.toPx(), height - 20.dp.toPx())
            lineTo(width/2 - 10.dp.toPx(), height - 20.dp.toPx())
            lineTo(width/2 - 5.dp.toPx(), 205.dp.toPx())
            
            moveTo(width/2 + 40.dp.toPx(), 205.dp.toPx())
            lineTo(width/2 + 40.dp.toPx(), height - 20.dp.toPx())
            lineTo(width/2 + 10.dp.toPx(), height - 20.dp.toPx())
            lineTo(width/2 + 5.dp.toPx(), 205.dp.toPx())
        }
        
        drawPath(path, color = color, style = Stroke(width = 2.dp.toPx()))
    }
}

@Composable
fun ScanningEffect() {
    val infiniteTransition = rememberInfiniteTransition(label = "scan")
    val offsetY by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = androidx.compose.animation.core.infiniteRepeatable(
            animation = androidx.compose.animation.core.tween(3000, easing = androidx.compose.animation.core.LinearEasing),
            repeatMode = androidx.compose.animation.core.RepeatMode.Restart
        ),
        label = "scanLine"
    )
    
    Canvas(modifier = Modifier.fillMaxSize()) {
        val lineY = size.height * offsetY
        
        drawLine(
            color = Color.Cyan.copy(alpha = 0.6f),
            start = Offset(0f, lineY),
            end = Offset(size.width, lineY),
            strokeWidth = 2.dp.toPx()
        )
        
        // Glow effect
        drawRect(
            brush = androidx.compose.ui.graphics.Brush.verticalGradient(
                colors = listOf(Color.Cyan.copy(alpha = 0f), Color.Cyan.copy(alpha = 0.3f)),
                startY = lineY - 50.dp.toPx(),
                endY = lineY
            ),
            topLeft = Offset(0f, lineY - 50.dp.toPx()),
            size = Size(size.width, 50.dp.toPx())
        )
    }
}
