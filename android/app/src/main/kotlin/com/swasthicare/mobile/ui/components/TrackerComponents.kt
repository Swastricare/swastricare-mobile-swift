package com.swasthicare.mobile.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.*
import java.text.SimpleDateFormat
import java.util.*

/**
 * Weekly Tracker Section - Matches iOS implementation
 * 
 * Contains:
 * - Horizontal date selector (7 days)
 * - Weekly steps bar chart
 * - Detailed metrics list
 */

// Data class for daily metrics
data class DailyMetric(
    val date: Date,
    val steps: Int,
    val dayName: String
)

// MARK: - Date Selector
@Composable
fun WeekDateSelector(
    weekDates: List<Date>,
    selectedDate: Date,
    onDateSelected: (Date) -> Unit,
    modifier: Modifier = Modifier
) {
    var isVisible by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(100)
        isVisible = true
    }
    
    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500, easing = FastOutSlowInEasing),
        label = "selectorAlpha"
    )
    
    val animatedOffset by animateFloatAsState(
        targetValue = if (isVisible) 0f else 20f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "selectorOffset"
    )
    
    Row(
        modifier = modifier
            .horizontalScroll(rememberScrollState())
            .graphicsLayer {
                alpha = animatedAlpha
                translationY = animatedOffset
            }
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        weekDates.forEach { date ->
            DateButton(
                date = date,
                isSelected = isSameDay(date, selectedDate),
                onClick = { onDateSelected(date) }
            )
        }
    }
}

@Composable
private fun DateButton(
    date: Date,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val calendar = Calendar.getInstance().apply { time = date }
    val dayName = SimpleDateFormat("EEE", Locale.getDefault()).format(date).take(3)
    val dayNumber = calendar.get(Calendar.DAY_OF_MONTH)
    
    Column(
        modifier = Modifier
            .width(50.dp)
            .height(60.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(
                if (isSelected)
                     PremiumColor.RoyalBlueStart else Color.Transparent
            )
            .border(
                width = 1.dp,
                color = if (isSelected) Color.Transparent else Color.Gray.copy(alpha = 0.3f),
                shape = RoundedCornerShape(12.dp)
            )
            .clickable { onClick() },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = dayName,
            style = MaterialTheme.typography.labelSmall,
            color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = "$dayNumber",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface
        )
    }
}

// MARK: - Weekly Steps Chart
@Composable
fun WeeklyStepsChart(
    weeklySteps: List<DailyMetric>,
    selectedDate: Date,
    stepGoal: Int = 10000,
    modifier: Modifier = Modifier
) {
    var isVisible by remember { mutableStateOf(false) }
    var tappedIndex by remember { mutableStateOf(-1) }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(200)
        isVisible = true
    }

    val animatedAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500),
        label = "chartAlpha"
    )

    val animatedScale by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0.9f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "chartScale"
    )

    // Use the max of steps and goal so the goal line is always visible
    val maxValue = maxOf(weeklySteps.maxOfOrNull { it.steps } ?: 1, stepGoal)
    val chartHeight = 150f

    // Determine today's date for highlighting
    val today = Calendar.getInstance().time

    Column(
        modifier = modifier
            .fillMaxWidth()
            .graphicsLayer {
                alpha = animatedAlpha
                scaleX = animatedScale
                scaleY = animatedScale
            }
            .padding(horizontal = 20.dp)
            .glass(cornerRadius = 16.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Weekly Steps",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
            // Show step count of tapped bar
            if (tappedIndex in weeklySteps.indices) {
                val tappedMetric = weeklySteps[tappedIndex]
                Text(
                    text = "%,d steps".format(tappedMetric.steps),
                    style = MaterialTheme.typography.labelMedium,
                    color = PremiumColor.RoyalBlueStart,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(chartHeight.dp)
        ) {
            // Goal line (dashed)
            if (stepGoal > 0) {
                val goalRatio = stepGoal.toFloat() / maxValue
                val goalY = chartHeight * (1f - goalRatio)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .offset(y = goalY.dp)
                        .height(1.dp)
                        .background(Color.Gray.copy(alpha = 0.4f))
                )
            }

            Row(
                modifier = Modifier.fillMaxSize(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.Bottom
            ) {
                weeklySteps.forEachIndexed { index, metric ->
                    val isSelectedDay = isSameDay(metric.date, selectedDate)
                    val isToday = isSameDay(metric.date, today)
                    val barHeightDp = if (maxValue > 0) (metric.steps.toFloat() / maxValue) * (chartHeight - 20f) else 0f

                    // Animate bar height
                    val animatedHeight by animateFloatAsState(
                        targetValue = if (isVisible) barHeightDp else 0f,
                        animationSpec = tween(
                            durationMillis = 800,
                            delayMillis = index * 80,
                            easing = FastOutSlowInEasing
                        ),
                        label = "barHeight$index"
                    )

                    val barColor = when {
                        isToday -> PremiumColor.RoyalBlueStart
                        isSelectedDay -> PremiumColor.RoyalBlueStart.copy(alpha = 0.7f)
                        else -> Color.Gray.copy(alpha = 0.3f)
                    }

                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                        modifier = Modifier.clickable {
                            tappedIndex = if (tappedIndex == index) -1 else index
                        }
                    ) {
                        Box(
                            modifier = Modifier
                                .width(30.dp)
                                .height(animatedHeight.dp)
                                .clip(RoundedCornerShape(4.dp))
                                .background(barColor)
                        )

                        Text(
                            text = metric.dayName,
                            style = MaterialTheme.typography.labelSmall,
                            color = if (isToday) PremiumColor.RoyalBlueStart
                            else MaterialTheme.colorScheme.onSurfaceVariant,
                            fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                }
            }
        }

        // Goal label
        if (stepGoal > 0) {
            Text(
                text = "Goal: %,d steps".format(stepGoal),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

// MARK: - Detailed Metrics Section
@Composable
fun DetailedMetricsSection(
    stepCount: Int,
    heartRate: Int,
    activeCalories: Int,
    exerciseMinutes: Int,
    standHours: Int,
    sleepHours: String,
    distance: Double,
    onMeasureHeartRate: () -> Unit,
    modifier: Modifier = Modifier
) {
    var isVisible by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(300)
        isVisible = true
    }
    
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(15.dp)
    ) {
        Text(
            text = "Detailed Metrics",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.graphicsLayer {
                alpha = if (isVisible) 1f else 0f
            }
        )
        
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 16.dp)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            MetricRow(
                icon = Icons.Default.DirectionsWalk,
                title = "Steps",
                value = "$stepCount",
                color = SecondaryColor,
                isVisible = isVisible,
                delay = 300
            )
            
            // Heart rate with measure button
            HeartRateMetricRow(
                heartRate = heartRate,
                onMeasure = onMeasureHeartRate,
                isVisible = isVisible,
                delay = 400
            )
            
            MetricRow(
                icon = Icons.Default.LocalFireDepartment,
                title = "Active Calories",
                value = "$activeCalories kcal",
                color = ActivityColor,
                isVisible = isVisible,
                delay = 500
            )
            
            MetricRow(
                icon = Icons.Default.Schedule,
                title = "Exercise",
                value = "$exerciseMinutes mins",
                color = HydrationColor,
                isVisible = isVisible,
                delay = 600
            )
            
            MetricRow(
                icon = Icons.Default.Accessibility,
                title = "Stand Hours",
                value = "$standHours hrs",
                color = SleepColor,
                isVisible = isVisible,
                delay = 700
            )
            
            MetricRow(
                icon = Icons.Default.Bedtime,
                title = "Sleep",
                value = sleepHours,
                color = Color(0xFF4F46E5),
                isVisible = isVisible,
                delay = 800
            )
            
            MetricRow(
                icon = Icons.Default.SwapHoriz,
                title = "Distance",
                value = String.format("%.2f km", distance),
                color = Color(0xFF00BCD4),
                isVisible = isVisible,
                delay = 900
            )
        }
    }
}

@Composable
private fun MetricRow(
    icon: ImageVector,
    title: String,
    value: String,
    color: Color,
    isVisible: Boolean,
    delay: Int
) {
    var rowVisible by remember { mutableStateOf(false) }
    
    LaunchedEffect(isVisible) {
        if (isVisible) {
            kotlinx.coroutines.delay(delay.toLong())
            rowVisible = true
        }
    }
    
    val animatedAlpha by animateFloatAsState(
        targetValue = if (rowVisible) 1f else 0f,
        animationSpec = tween(500),
        label = "rowAlpha"
    )
    
    val animatedOffset by animateFloatAsState(
        targetValue = if (rowVisible) 0f else -20f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "rowOffset"
    )
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer {
                alpha = animatedAlpha
                translationX = animatedOffset
            }
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = color,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = title,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

@Composable
private fun HeartRateMetricRow(
    heartRate: Int,
    onMeasure: () -> Unit,
    isVisible: Boolean,
    delay: Int
) {
    var rowVisible by remember { mutableStateOf(false) }
    
    LaunchedEffect(isVisible) {
        if (isVisible) {
            kotlinx.coroutines.delay(delay.toLong())
            rowVisible = true
        }
    }
    
    val animatedAlpha by animateFloatAsState(
        targetValue = if (rowVisible) 1f else 0f,
        animationSpec = tween(500),
        label = "heartRowAlpha"
    )
    
    val animatedOffset by animateFloatAsState(
        targetValue = if (rowVisible) 0f else -20f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "heartRowOffset"
    )
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer {
                alpha = animatedAlpha
                translationX = animatedOffset
            }
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Favorite,
                contentDescription = null,
                tint = HeartRateColor,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = "Heart Rate",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "$heartRate BPM",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            
            // Measure button
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(HeartRateColor)
                    .clickable { onMeasure() }
                    .padding(horizontal = 10.dp, vertical = 6.dp)
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.CameraAlt,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        text = "Measure",
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White
                    )
                }
            }
        }
    }
}

// Helper function to compare dates
private fun isSameDay(date1: Date, date2: Date): Boolean {
    val cal1 = Calendar.getInstance().apply { time = date1 }
    val cal2 = Calendar.getInstance().apply { time = date2 }
    return cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
           cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
}

// Helper function to generate week dates
fun generateWeekDates(): List<Date> {
    val calendar = Calendar.getInstance()
    val today = calendar.time
    
    // Start from beginning of week
    calendar.set(Calendar.DAY_OF_WEEK, calendar.firstDayOfWeek)
    
    return (0..6).map {
        val date = calendar.time
        calendar.add(Calendar.DAY_OF_MONTH, 1)
        date
    }
}

// Generate sample weekly steps data
fun generateSampleWeeklySteps(): List<DailyMetric> {
    val calendar = Calendar.getInstance()
    calendar.set(Calendar.DAY_OF_WEEK, calendar.firstDayOfWeek)
    
    val sampleSteps = listOf(6500, 8200, 7800, 9100, 8432, 5600, 4200)
    val dayNames = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
    
    return sampleSteps.mapIndexed { index, steps ->
        val date = calendar.time
        calendar.add(Calendar.DAY_OF_MONTH, 1)
        DailyMetric(
            date = date,
            steps = steps,
            dayName = dayNames[index]
        )
    }
}
