package com.swastricare.health.ui.screens.stress

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.domain.model.stress.StressCategory
import com.swastricare.health.domain.model.stress.StressMood
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.theme.AppColors

@Composable
fun StressScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToAnalytics: () -> Unit = {}
) {
    TrackScreen("Stress")
    val viewModel: StressViewModel = hiltViewModel()
    val uiState by viewModel.uiState.collectAsState()

    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(uiState.logSuccess) {
        if (uiState.logSuccess) {
            snackbarHostState.showSnackbar("Stress entry logged")
            viewModel.dismissLogSuccess()
        }
    }

    LaunchedEffect(uiState.errorMessage) {
        uiState.errorMessage?.let {
            snackbarHostState.showSnackbar(it)
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            // ── Top Bar ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = AppColors.onSurface)
                }
                Text(
                    "Stress",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f).padding(start = 4.dp)
                )
                IconButton(onClick = onNavigateToAnalytics) {
                    Icon(Icons.Default.BarChart, "Analytics", tint = AppColors.onSurfaceVariant)
                }
            }

            when {
                uiState.isLoading -> StressSkeletonContent()
                else -> StressContent(
                    uiState = uiState,
                    onStressLevelChange = { viewModel.setStressLevel(it) },
                    onMoodSelected = { viewModel.setMood(it) },
                    onNotesChanged = { viewModel.setLogNotes(it) },
                    onLogStress = { viewModel.logStress() },
                    onNavigateToAnalytics = onNavigateToAnalytics
                )
            }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(16.dp)
        )
    }
}

// ── Content ──

@Composable
private fun StressContent(
    uiState: StressUiState,
    onStressLevelChange: (Int) -> Unit,
    onMoodSelected: (StressMood) -> Unit,
    onNotesChanged: (String) -> Unit,
    onLogStress: () -> Unit,
    onNavigateToAnalytics: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // ── Current Stress Hero Card ──
        CurrentStressHero(currentEntry = uiState.currentEntry)

        // ── Manual Logging Section ──
        ManualLoggingCard(
            selectedLevel = uiState.selectedStressLevel,
            selectedMood = uiState.selectedMood,
            notes = uiState.logNotes,
            isLogging = uiState.isLogging,
            onLevelChange = onStressLevelChange,
            onMoodSelected = onMoodSelected,
            onNotesChanged = onNotesChanged,
            onLogStress = onLogStress
        )

        // ── Quick Summary Row ──
        QuickSummaryRow(
            entries = uiState.allEntries,
            currentEntry = uiState.currentEntry
        )

        // ── Stress Tips ──
        StressTipsSection(
            category = uiState.currentEntry?.category ?: StressCategory.fromLevel(uiState.selectedStressLevel)
        )

        // ── View Analytics Button ──
        Button(
            onClick = onNavigateToAnalytics,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color(0xFF7C3AED)
            )
        ) {
            Icon(Icons.Default.BarChart, null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text("View Analytics", fontWeight = FontWeight.SemiBold)
        }

        Spacer(Modifier.height(100.dp))
    }
}

// ── Current Stress Hero ──

@Composable
private fun CurrentStressHero(
    currentEntry: com.swastricare.health.domain.model.stress.StressEntry?
) {
    val category = currentEntry?.category ?: StressCategory.LOW
    val goodPercent = currentEntry?.calculatedStressPercent ?: 100
    val categoryColor = Color(category.colorHex)

    val infiniteTransition = rememberInfiniteTransition(label = "stressPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.05f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 24.dp, accentColor = categoryColor)
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Large circular indicator
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .graphicsLayer { scaleX = pulseScale; scaleY = pulseScale }
                    .clip(CircleShape)
                    .background(
                        Brush.radialGradient(
                            colors = listOf(
                                categoryColor.copy(alpha = 0.3f),
                                categoryColor.copy(alpha = 0.1f)
                            )
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "$goodPercent%",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = categoryColor
                )
            }

            Text(
                text = "${goodPercent}% Good",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
            Text(
                text = category.displayName,
                fontSize = 14.sp,
                color = categoryColor,
                fontWeight = FontWeight.SemiBold
            )
            if (currentEntry != null) {
                Text(
                    text = "Last logged: ${currentEntry.timestamp.format(
                        java.time.format.DateTimeFormatter.ofPattern("MMM d, h:mm a")
                    )}",
                    fontSize = 12.sp,
                    color = AppColors.onSurfaceVariant
                )
            } else {
                Text(
                    text = "No entries yet — log your first one below",
                    fontSize = 12.sp,
                    color = AppColors.onSurfaceVariant
                )
            }
        }
    }
}

// ── Manual Logging Card ──

@Composable
private fun ManualLoggingCard(
    selectedLevel: Int,
    selectedMood: StressMood,
    notes: String,
    isLogging: Boolean,
    onLevelChange: (Int) -> Unit,
    onMoodSelected: (StressMood) -> Unit,
    onNotesChanged: (String) -> Unit,
    onLogStress: () -> Unit
) {
    val category = StressCategory.fromLevel(selectedLevel)
    val categoryColor = Color(category.colorHex)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "How are you feeling?",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )

        // Stress slider
        Column {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Stress Level: $selectedLevel/10",
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurfaceVariant
                )
                Text(
                    text = category.displayName,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = categoryColor
                )
            }
            Spacer(Modifier.height(4.dp))
            Slider(
                value = selectedLevel.toFloat(),
                onValueChange = { onLevelChange(it.toInt()) },
                valueRange = 1f..10f,
                steps = 8,
                colors = SliderDefaults.colors(
                    thumbColor = categoryColor,
                    activeTrackColor = categoryColor,
                    inactiveTrackColor = categoryColor.copy(alpha = 0.2f)
                )
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Calm", fontSize = 11.sp, color = AppColors.onSurfaceVariant)
                Text("Stressed", fontSize = 11.sp, color = AppColors.onSurfaceVariant)
            }
        }

        // Mood chip row
        Column {
            Text(
                text = "Mood",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant
            )
            Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                StressMood.entries.take(3).forEach { mood ->
                    MoodChip(
                        mood = mood,
                        isSelected = mood == selectedMood,
                        onClick = { onMoodSelected(mood) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                StressMood.entries.drop(3).forEach { mood ->
                    MoodChip(
                        mood = mood,
                        isSelected = mood == selectedMood,
                        onClick = { onMoodSelected(mood) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }

        // Notes field
        OutlinedTextField(
            value = notes,
            onValueChange = onNotesChanged,
            label = { Text("Notes (optional)") },
            modifier = Modifier.fillMaxWidth(),
            maxLines = 3,
            shape = RoundedCornerShape(12.dp)
        )

        // Log button
        Button(
            onClick = onLogStress,
            enabled = !isLogging,
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(containerColor = categoryColor)
        ) {
            if (isLogging) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                    color = Color.White
                )
            } else {
                Icon(Icons.Default.Add, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("Log Stress", fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun MoodChip(
    mood: StressMood,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val bgColor = if (isSelected) Color(0xFF7C3AED).copy(alpha = 0.15f) else Color.Transparent
    val borderColor = if (isSelected) Color(0xFF7C3AED) else AppColors.onSurfaceVariant.copy(alpha = 0.3f)

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(bgColor)
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(text = mood.emoji, fontSize = 20.sp)
            Spacer(Modifier.height(2.dp))
            Text(
                text = mood.displayName,
                fontSize = 10.sp,
                color = if (isSelected) Color(0xFF7C3AED) else AppColors.onSurfaceVariant,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
            )
        }
    }
}

// ── Quick Summary Row ──

@Composable
private fun QuickSummaryRow(
    entries: List<com.swastricare.health.domain.model.stress.StressEntry>,
    currentEntry: com.swastricare.health.domain.model.stress.StressEntry?
) {
    val today = java.time.LocalDate.now()
    val weekAgo = today.minusDays(7)
    val weekEntries = entries.filter {
        val d = it.timestamp.toLocalDate()
        !d.isBefore(weekAgo) && !d.isAfter(today)
    }
    val avgLast7d = if (weekEntries.isNotEmpty()) weekEntries.map { it.stressLevel }.average().toInt() else 0
    val todayCount = entries.count { it.timestamp.toLocalDate() == today }

    // Streak: consecutive days with at least one entry
    var streak = 0
    var checkDate = today
    while (true) {
        if (entries.any { it.timestamp.toLocalDate() == checkDate }) {
            streak++
            checkDate = checkDate.minusDays(1)
        } else {
            break
        }
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SummaryMiniCard(
            label = "Avg (7d)",
            value = if (avgLast7d > 0) "$avgLast7d/10" else "--",
            icon = Icons.AutoMirrored.Filled.TrendingDown,
            color = Color(0xFF7C3AED),
            modifier = Modifier.weight(1f)
        )
        SummaryMiniCard(
            label = "Today",
            value = "$todayCount",
            icon = Icons.Default.Today,
            color = Color(0xFF0EA5E9),
            modifier = Modifier.weight(1f)
        )
        SummaryMiniCard(
            label = "Streak",
            value = "${streak}d",
            icon = Icons.Default.LocalFireDepartment,
            color = Color(0xFFF59E0B),
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun SummaryMiniCard(
    label: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .glass(cornerRadius = 16.dp)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(icon, null, tint = color, modifier = Modifier.size(20.dp))
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = AppColors.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

// ── Stress Tips Section ──

@Composable
private fun StressTipsSection(category: StressCategory) {
    val tips = remember(category) {
        when (category) {
            StressCategory.LOW -> listOf(
                "Keep up the great work with your self-care routine",
                "Maintain regular sleep and exercise habits",
                "Practice gratitude journaling"
            )
            StressCategory.MODERATE -> listOf(
                "Try a 5-minute breathing exercise (4-7-8 technique)",
                "Take a short walk outdoors",
                "Limit screen time before bed"
            )
            StressCategory.HIGH -> listOf(
                "Practice progressive muscle relaxation",
                "Reach out to a friend or family member",
                "Take a break from stressful tasks"
            )
            StressCategory.SEVERE -> listOf(
                "Consider speaking with a mental health professional",
                "Practice box breathing (4-4-4-4)",
                "Remove yourself from stressful environments if possible",
                "Focus on one small task at a time"
            )
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .glass(cornerRadius = 20.dp)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                Icons.Default.Lightbulb,
                null,
                tint = Color(0xFFF59E0B),
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = "Tips for You",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
        }

        tips.forEach { tip ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.Top
            ) {
                Box(
                    modifier = Modifier
                        .padding(top = 6.dp)
                        .size(6.dp)
                        .clip(CircleShape)
                        .background(Color(category.colorHex).copy(alpha = 0.7f))
                )
                Text(
                    text = tip,
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurfaceVariant
                )
            }
        }
    }
}

// ── Skeleton ──

@Composable
private fun StressSkeletonContent() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        repeat(3) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(if (it == 0) 200.dp else 120.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(AppColors.onSurface.copy(alpha = 0.06f))
            )
        }
    }
}
