package com.swastricare.health.ui.screens.runactivity.components

import androidx.compose.foundation.Image
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
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.WorkoutTemplate
import com.swastricare.health.ui.screens.runactivity.LiveWorkoutUiState
import com.swastricare.health.ui.screens.runactivity.WorkoutType
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.AITealDark

private val ScreenBg = Color.White
private val CardBg = Color.White
private val MintTint = Color(0xFFE6F7F2)
private val TextPrimary = Color(0xFF0F172A)
private val TextSecondary = Color(0xFF64748B)
private val SoftBorder = Color(0xFFE5EAF0)

private enum class GoalType { DISTANCE, DURATION, CALORIES, NO_GOAL }

private data class ActivityOption(
    val type: WorkoutType,
    val title: String,
    val subtitle: String,
    val asset: String
)

private val ActivityOptions = listOf(
    ActivityOption(WorkoutType.RUN, "Run", "Track your run and improve your pace", "icons/run activity illustration.png"),
    ActivityOption(WorkoutType.WALK, "Walk", "Track your steps and stay active", "icons/walk illustration.png"),
    ActivityOption(WorkoutType.CYCLE, "Cycle", "Track your ride and distance covered", "icons/cycle illustration.png"),
    ActivityOption(WorkoutType.HIKE, "Hike", "Explore trails and track your hike", "icons/hike illustration.png")
)

@Composable
fun WorkoutPhaseIdle(
    uiState: LiveWorkoutUiState,
    hasLocationPermission: Boolean,
    usesGps: Boolean,
    showPermissionRationale: Boolean,
    showPermissionSettings: Boolean,
    onSelectWorkoutType: (WorkoutType) -> Unit,
    onSelectTemplate: (WorkoutTemplate) -> Unit,
    onStart: () -> Unit,
    onBack: () -> Unit,
    onOpenSettings: () -> Unit,
    onDismissRationale: () -> Unit,
    onDismissSettings: () -> Unit,
    onRequestPermission: () -> Unit
) {
    val haptic = LocalHapticFeedback.current

    if (showPermissionRationale) {
        LocationPermissionRationale(
            onAllow = {
                onDismissRationale()
                onRequestPermission()
            },
            onDismiss = onDismissRationale
        )
    }
    if (showPermissionSettings) {
        PermissionSettingsDialog(
            onOpenSettings = onOpenSettings,
            onDismiss = onDismissSettings
        )
    }

    var selectedGoal by remember { mutableStateOf<GoalType?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(ScreenBg)
            .statusBarsPadding()
    ) {
        StartWorkoutHeader(onBack = onBack)

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
        ) {
            Spacer(Modifier.height(12.dp))
            SectionHeader(title = "Choose Activity", actionLabel = "Learn more", onAction = {})
            Spacer(Modifier.height(12.dp))

            ActivityOptions.chunked(2).forEach { rowOptions ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(IntrinsicSize.Max),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    rowOptions.forEach { option ->
                        ActivityCard(
                            option = option,
                            isSelected = uiState.workoutType == option.type,
                            onClick = {
                                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                onSelectWorkoutType(option.type)
                            },
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                        )
                    }
                    if (rowOptions.size < 2) Spacer(Modifier.weight(1f))
                }
                Spacer(Modifier.height(12.dp))
            }

            Spacer(Modifier.height(8.dp))
            SectionHeader(title = "Set Your Goal", actionLabel = "Skip", onAction = { selectedGoal = null })
            Spacer(Modifier.height(12.dp))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(IntrinsicSize.Max),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                GoalCard(
                    title = "Distance",
                    subtitle = "Set a target distance",
                    icon = Icons.Default.TrackChanges,
                    iconBg = Color(0xFFE0EAFF),
                    iconTint = Color(0xFF4F46E5),
                    isSelected = selectedGoal == GoalType.DISTANCE,
                    onClick = { selectedGoal = GoalType.DISTANCE },
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
                GoalCard(
                    title = "Duration",
                    subtitle = "Set a target time",
                    icon = Icons.Default.Timer,
                    iconBg = Color(0xFFEFE3FF),
                    iconTint = Color(0xFF7C3AED),
                    isSelected = selectedGoal == GoalType.DURATION,
                    onClick = { selectedGoal = GoalType.DURATION },
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
                GoalCard(
                    title = "Calories",
                    subtitle = "Set a target calories",
                    icon = Icons.Default.LocalFireDepartment,
                    iconBg = Color(0xFFFFE0EE),
                    iconTint = Color(0xFFE11D74),
                    isSelected = selectedGoal == GoalType.CALORIES,
                    onClick = { selectedGoal = GoalType.CALORIES },
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
                GoalCard(
                    title = "No Goal",
                    subtitle = "Just track your activity",
                    icon = Icons.Default.EmojiEvents,
                    iconBg = Color(0xFFFFE7D6),
                    iconTint = Color(0xFFEA580C),
                    isSelected = selectedGoal == GoalType.NO_GOAL,
                    onClick = { selectedGoal = GoalType.NO_GOAL },
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
            }

            Spacer(Modifier.height(20.dp))
            MoreSettingsCard(onClick = {})
            Spacer(Modifier.height(20.dp))
        }

        StartWorkoutButton(
            onClick = {
                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                onStart()
            }
        )
    }
}

// ── Header ──────────────────────────────────────────────────────────────────

@Composable
private fun StartWorkoutHeader(onBack: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 0.dp, end = 12.dp, top = 4.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onBack, modifier = Modifier.size(44.dp)) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = TextPrimary
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "Start Workout",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary,
                lineHeight = 22.sp
            )
            Text(
                text = "Choose your activity and set your goal",
                fontSize = 12.sp,
                color = TextSecondary,
                lineHeight = 14.sp
            )
        }
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(CardBg)
                .border(1.dp, SoftBorder, CircleShape)
                .clickable { },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.History,
                contentDescription = "History",
                tint = AITeal,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

// ── Section Header ──────────────────────────────────────────────────────────

@Composable
private fun SectionHeader(title: String, actionLabel: String, onAction: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = title,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary
        )
        Text(
            text = actionLabel,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = AITeal,
            modifier = Modifier.clickable(onClick = onAction)
        )
    }
}

// ── Activity Card ───────────────────────────────────────────────────────────

@Composable
private fun ActivityCard(
    option: ActivityOption,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val bitmap = remember(option.asset) {
        runCatching {
            context.assets.open(option.asset).use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }
    val borderColor = if (isSelected) AITeal else SoftBorder
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(CardBg)
            .border(
                width = if (isSelected) 1.5.dp else 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(20.dp)
            )
            .clickable { onClick() }
            .padding(14.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(96.dp),
                contentAlignment = Alignment.Center
            ) {
                if (bitmap != null) {
                    Image(
                        bitmap = bitmap.asImageBitmap(),
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(96.dp)
                    )
                }
            }
            Text(
                text = option.title,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary
            )
            Text(
                text = option.subtitle,
                fontSize = 11.sp,
                color = TextSecondary,
                lineHeight = 14.sp
            )
        }

        // Selection radio
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .size(22.dp)
                .clip(CircleShape)
                .background(if (isSelected) AITeal else Color.White)
                .border(
                    width = 1.5.dp,
                    color = if (isSelected) AITeal else SoftBorder,
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            if (isSelected) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(14.dp)
                )
            }
        }
    }
}

// ── Goal Card ───────────────────────────────────────────────────────────────

@Composable
private fun GoalCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    iconBg: Color,
    iconTint: Color,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg)
            .border(
                width = if (isSelected) 1.5.dp else 1.dp,
                color = if (isSelected) AITeal else SoftBorder,
                shape = RoundedCornerShape(16.dp)
            )
            .clickable { onClick() }
            .padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(iconBg),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = iconTint,
                modifier = Modifier.size(18.dp)
            )
        }
        Text(
            text = title,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = TextPrimary
        )
        Text(
            text = subtitle,
            fontSize = 10.sp,
            color = TextSecondary,
            lineHeight = 12.sp,
            maxLines = 2,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
    }
}

// ── More Settings Row ───────────────────────────────────────────────────────

@Composable
private fun MoreSettingsCard(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg)
            .border(1.dp, SoftBorder, RoundedCornerShape(16.dp))
            .clickable { onClick() }
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(MintTint),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Settings,
                contentDescription = null,
                tint = AITealDark,
                modifier = Modifier.size(18.dp)
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = "More Settings",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Text(
                text = "Workout reminders, audio feedback, units",
                fontSize = 11.sp,
                color = TextSecondary
            )
        }
        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = null,
            tint = TextSecondary,
            modifier = Modifier.size(20.dp)
        )
    }
}

// ── Start Workout Button ────────────────────────────────────────────────────

@Composable
private fun StartWorkoutButton(onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 16.dp)
            .navigationBarsPadding()
    ) {
        Button(
            onClick = onClick,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(50),
            colors = ButtonDefaults.buttonColors(containerColor = AITeal),
            elevation = ButtonDefaults.buttonElevation(0.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.PlayArrow,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(18.dp)
                )
            }
            Spacer(Modifier.width(10.dp))
            Text(
                text = "Start Workout",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
        }
    }
}
