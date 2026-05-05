package com.swastricare.health.ui.screens.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.outlined.DirectionsRun
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.theme.AITeal

private val ScreenBg = Color.White
private val CardSurface = Color.White
private val SoftBorder = Color(0xFFE9EEF3)
private val TextPrimary = Color(0xFF0F172A)
private val TextSecondary = Color(0xFF6B7280)
private val TrackColor = Color(0xFFEFF3F7)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActivityGoalsScreen(
    onNavigateBack: () -> Unit = {},
    viewModel: ActivityGoalsViewModel = hiltViewModel()
) {
    TrackScreen("ActivityGoals")
    val uiState by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(uiState.saveSuccess) {
        if (uiState.saveSuccess) {
            snackbarHostState.showSnackbar("Goals updated")
            viewModel.clearSaveSuccess()
        }
    }
    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.clearError()
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(ScreenBg)) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 4.dp, end = 12.dp, top = 8.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onNavigateBack, modifier = Modifier.size(44.dp)) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = TextPrimary
                    )
                }
                Column(modifier = Modifier.weight(1f).padding(start = 4.dp)) {
                    Text(
                        "Activity Goals",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextPrimary,
                        lineHeight = 22.sp
                    )
                    Text(
                        "Set your daily targets",
                        fontSize = 12.sp,
                        color = TextSecondary,
                        lineHeight = 14.sp
                    )
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                GoalSlider(
                    icon = Icons.Outlined.DirectionsRun,
                    iconTint = AITeal,
                    title = "Steps",
                    description = "Daily step target",
                    value = uiState.goals.dailyStepsGoal.toFloat(),
                    valueRange = 1_000f..30_000f,
                    steps = ((30_000 - 1_000) / 500) - 1,
                    valueLabel = "${formatNumber(uiState.goals.dailyStepsGoal)} steps",
                    onValueChange = { viewModel.updateSteps(it.toInt()) }
                )
                GoalSlider(
                    icon = Icons.Default.Place,
                    iconTint = Color(0xFFEAB308),
                    title = "Distance",
                    description = "Daily distance target",
                    value = uiState.goals.dailyDistanceKm.toFloat(),
                    valueRange = 1f..30f,
                    steps = 28,
                    valueLabel = String.format("%.1f km", uiState.goals.dailyDistanceKm),
                    onValueChange = { viewModel.updateDistanceKm(it.toDouble()) }
                )
                GoalSlider(
                    icon = Icons.Default.LocalFireDepartment,
                    iconTint = Color(0xFFEF8B3C),
                    title = "Active Calories",
                    description = "Calories burned through movement",
                    value = uiState.goals.dailyCaloriesGoal.toFloat(),
                    valueRange = 100f..2_000f,
                    steps = ((2_000 - 100) / 50) - 1,
                    valueLabel = "${uiState.goals.dailyCaloriesGoal} kcal",
                    onValueChange = { viewModel.updateCalories(it.toInt()) }
                )
                GoalSlider(
                    icon = Icons.Default.Schedule,
                    iconTint = Color(0xFF8B5CF6),
                    title = "Active Time",
                    description = "Minutes of activity per day",
                    value = uiState.goals.dailyActiveMinutes.toFloat(),
                    valueRange = 10f..180f,
                    steps = ((180 - 10) / 5) - 1,
                    valueLabel = "${uiState.goals.dailyActiveMinutes} min",
                    onValueChange = { viewModel.updateActiveMinutes(it.toInt()) }
                )
            }

            // Save button
            Button(
                onClick = { viewModel.save() },
                enabled = !uiState.isSaving,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp)
                    .height(54.dp),
                shape = RoundedCornerShape(50),
                colors = ButtonDefaults.buttonColors(containerColor = AITeal),
                elevation = ButtonDefaults.buttonElevation(0.dp)
            ) {
                if (uiState.isSaving) {
                    CircularProgressIndicator(
                        color = Color.White,
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(20.dp)
                    )
                } else {
                    Text(
                        "Save Goals",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 90.dp)
        )
    }
}

@Composable
private fun GoalSlider(
    icon: ImageVector,
    iconTint: Color,
    title: String,
    description: String,
    value: Float,
    valueRange: ClosedFloatingPointRange<Float>,
    steps: Int,
    valueLabel: String,
    onValueChange: (Float) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(CardSurface)
            .border(1.dp, SoftBorder, RoundedCornerShape(18.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .clip(CircleShape)
                    .background(iconTint.copy(alpha = 0.14f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, null, tint = iconTint, modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    title,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = TextPrimary
                )
                Text(
                    description,
                    fontSize = 11.sp,
                    color = TextSecondary
                )
            }
            Text(
                valueLabel,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = iconTint
            )
        }
        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = valueRange,
            steps = steps.coerceAtLeast(0),
            colors = SliderDefaults.colors(
                thumbColor = iconTint,
                activeTrackColor = iconTint,
                inactiveTrackColor = TrackColor,
                activeTickColor = Color.Transparent,
                inactiveTickColor = Color.Transparent
            )
        )
    }
}

private fun formatNumber(value: Int): String =
    if (value < 1000) value.toString() else "%,d".format(value)
