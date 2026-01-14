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
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Accessibility
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.unit.IntOffset
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
import com.swasthicare.mobile.ui.components.ModelViewer
import com.swasthicare.mobile.ui.components.WeekDateSelector
import com.swasthicare.mobile.ui.components.WeeklyStepsChart
import com.swasthicare.mobile.ui.components.DetailedMetricsSection
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
                    // Activity Stats Column (matching iOS: Calories, Steps, Exercise, Stand Hours)
                    Column(
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.weight(0.45f)
                    ) {
                        ActivityStatRow(
                            icon = Icons.Default.LocalFireDepartment,
                            value = "${uiState.calories}",
                            label = "Active Calories",
                            color = ActivityColor,
                            animationDelay = 300
                        )
                        ActivityStatRow(
                            icon = Icons.Default.DirectionsWalk,
                            value = "${uiState.stepCount}",
                            label = "Step Count",
                            color = SecondaryColor,
                            animationDelay = 400
                        )
                        ActivityStatRow(
                            icon = Icons.Default.Favorite,
                            value = "${uiState.activeMinutes}",
                            label = "Exercise Min",
                            color = HydrationColor,
                            animationDelay = 500
                        )
                        ActivityStatRow(
                            icon = Icons.Default.Accessibility,
                            value = "${uiState.standHours}",
                            label = "Stand Hours",
                            color = SleepColor,
                            animationDelay = 600
                        )
                    }
                    
                    Spacer(modifier = Modifier.width(16.dp))
                    
                    // 3D Anatomy Model (replacing 2D silhouette)
                    Box(
                        modifier = Modifier
                            .weight(0.55f)
                            .height(380.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        ModelViewer(
                            modelName = "anatomy",
                            modifier = Modifier
                                .fillMaxSize()
                                .scale(1.4f)
                                .alpha(0.8f),
                            autoRotate = true,
                            allowInteraction = false,
                            rotationDurationMs = 8000
                        )
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
                
                Spacer(modifier = Modifier.height(20.dp))
                
                // 6. Tracker Section
                // Date Selector
                WeekDateSelector(
                    weekDates = uiState.weekDates,
                    selectedDate = uiState.selectedDate,
                    onDateSelected = { viewModel.selectDate(it) }
                )
                
                Spacer(modifier = Modifier.height(16.dp))
                
                // Weekly Steps Chart
                WeeklyStepsChart(
                    weeklySteps = uiState.weeklySteps,
                    selectedDate = uiState.selectedDate
                )
                
                Spacer(modifier = Modifier.height(20.dp))
                
                // Detailed Metrics
                DetailedMetricsSection(
                    stepCount = uiState.stepCount,
                    heartRate = uiState.heartRate,
                    activeCalories = uiState.calories,
                    exerciseMinutes = uiState.activeMinutes,
                    standHours = uiState.standHours,
                    sleepHours = uiState.sleepHours,
                    distance = uiState.distance,
                    onMeasureHeartRate = { /* TODO: Implement heart rate measurement */ }
                )
                
                Spacer(modifier = Modifier.height(120.dp)) // Extra space for bottom bar
            }
        }
    }
}

@Composable
fun ActivityStatRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: String,
    label: String,
    color: Color,
    animationDelay: Int = 0
) {
    var isVisible by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(animationDelay.toLong())
        isVisible = true
    }
    
    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(durationMillis = 500, easing = FastOutSlowInEasing),
        label = "statAlpha"
    )
    
    val animatedOffset by animateFloatAsState(
        targetValue = if (isVisible) 0f else -20f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "statOffset"
    )
    
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .alpha(animatedAlpha)
            .offset(x = animatedOffset.dp)
            .glass(cornerRadius = 16.dp)
            .padding(horizontal = 12.dp, vertical = 8.dp)
    ) {
        // Icon with background circle
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(color.copy(alpha = 0.2f), androidx.compose.foundation.shape.CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
        }
        
        // Value and label
        Column {
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
