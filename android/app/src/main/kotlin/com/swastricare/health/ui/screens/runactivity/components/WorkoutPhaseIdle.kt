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
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Straighten
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material.icons.filled.VolumeUp
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
    var goalValue by remember { mutableStateOf<String?>(null) }
    var pendingGoalType by remember { mutableStateOf<GoalType?>(null) }
    var showSettingsSheet by remember { mutableStateOf(false) }
    var showActivityInfoSheet by remember { mutableStateOf(false) }

    if (showSettingsSheet) {
        WorkoutSettingsSheet(onDismiss = { showSettingsSheet = false })
    }

    pendingGoalType?.let { type ->
        WorkoutGoalSheet(
            goalType = type,
            initialValue = if (selectedGoal == type) goalValue ?: "" else "",
            onDismiss = { pendingGoalType = null },
            onConfirm = { value ->
                selectedGoal = type
                goalValue = value
                pendingGoalType = null
            }
        )
    }

    if (showActivityInfoSheet) {
        ActivityInfoSheet(onDismiss = { showActivityInfoSheet = false })
    }

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
            SectionHeader(
                title = "Choose Activity",
                actionLabel = "Learn more",
                onAction = { showActivityInfoSheet = true }
            )
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
            SectionHeader(
                title = "Set Your Goal",
                actionLabel = "Skip",
                onAction = {
                    selectedGoal = null
                    goalValue = null
                }
            )
            Spacer(Modifier.height(12.dp))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(IntrinsicSize.Max),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                GoalCard(
                    title = "Distance",
                    subtitle = if (selectedGoal == GoalType.DISTANCE && !goalValue.isNullOrBlank())
                        "${goalValue} km" else "Set a target distance",
                    icon = Icons.Default.TrackChanges,
                    iconBg = Color(0xFFE0EAFF),
                    iconTint = Color(0xFF4F46E5),
                    isSelected = selectedGoal == GoalType.DISTANCE,
                    onClick = { pendingGoalType = GoalType.DISTANCE },
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
                GoalCard(
                    title = "Duration",
                    subtitle = if (selectedGoal == GoalType.DURATION && !goalValue.isNullOrBlank())
                        "${goalValue} min" else "Set a target time",
                    icon = Icons.Default.Timer,
                    iconBg = Color(0xFFEFE3FF),
                    iconTint = Color(0xFF7C3AED),
                    isSelected = selectedGoal == GoalType.DURATION,
                    onClick = { pendingGoalType = GoalType.DURATION },
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
                GoalCard(
                    title = "Calories",
                    subtitle = if (selectedGoal == GoalType.CALORIES && !goalValue.isNullOrBlank())
                        "${goalValue} kcal" else "Set a target calories",
                    icon = Icons.Default.LocalFireDepartment,
                    iconBg = Color(0xFFFFE0EE),
                    iconTint = Color(0xFFE11D74),
                    isSelected = selectedGoal == GoalType.CALORIES,
                    onClick = { pendingGoalType = GoalType.CALORIES },
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
                GoalCard(
                    title = "No Goal",
                    subtitle = "Just track your activity",
                    icon = Icons.Default.EmojiEvents,
                    iconBg = Color(0xFFFFE7D6),
                    iconTint = Color(0xFFEA580C),
                    isSelected = selectedGoal == GoalType.NO_GOAL,
                    onClick = {
                        selectedGoal = GoalType.NO_GOAL
                        goalValue = null
                    },
                    modifier = Modifier.weight(1f).fillMaxHeight()
                )
            }

            Spacer(Modifier.height(20.dp))
            MoreSettingsCard(onClick = { showSettingsSheet = true })
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

// ── Workout Preferences (SharedPreferences-backed) ─────────────────────────

private object WorkoutPrefs {
    private const val PREFS_NAME = "workout_preferences"
    private const val KEY_REMINDERS = "reminders_enabled"
    private const val KEY_AUDIO = "audio_feedback_enabled"
    private const val KEY_UNITS = "distance_units" // "km" or "mi"

    fun prefs(context: android.content.Context): android.content.SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)

    fun remindersEnabled(c: android.content.Context) = prefs(c).getBoolean(KEY_REMINDERS, true)
    fun setRemindersEnabled(c: android.content.Context, value: Boolean) {
        prefs(c).edit().putBoolean(KEY_REMINDERS, value).apply()
    }

    fun audioEnabled(c: android.content.Context) = prefs(c).getBoolean(KEY_AUDIO, true)
    fun setAudioEnabled(c: android.content.Context, value: Boolean) {
        prefs(c).edit().putBoolean(KEY_AUDIO, value).apply()
    }

    fun units(c: android.content.Context): String = prefs(c).getString(KEY_UNITS, "km") ?: "km"
    fun setUnits(c: android.content.Context, value: String) {
        prefs(c).edit().putString(KEY_UNITS, value).apply()
    }
}

// ── Workout Settings Sheet ─────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WorkoutSettingsSheet(onDismiss: () -> Unit) {
    val context = LocalContext.current
    var reminders by remember { mutableStateOf(WorkoutPrefs.remindersEnabled(context)) }
    var audio by remember { mutableStateOf(WorkoutPrefs.audioEnabled(context)) }
    var units by remember { mutableStateOf(WorkoutPrefs.units(context)) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Color.White,
        contentColor = TextPrimary,
        tonalElevation = 0.dp,
        dragHandle = null
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 24.dp)
        ) {
            // Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Workout Settings",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextPrimary
                    )
                    Text(
                        text = "Customize how your workouts behave",
                        fontSize = 12.sp,
                        color = TextSecondary
                    )
                }
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFF1F5F9))
                        .clickable(onClick = onDismiss),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = TextSecondary,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            SettingsToggleRow(
                icon = Icons.Default.NotificationsActive,
                iconBg = Color(0xFFE0EAFF),
                iconTint = Color(0xFF4F46E5),
                title = "Workout reminders",
                subtitle = "Get nudged to keep your daily streak",
                checked = reminders,
                onCheckedChange = {
                    reminders = it
                    WorkoutPrefs.setRemindersEnabled(context, it)
                }
            )
            Spacer(Modifier.height(10.dp))
            SettingsToggleRow(
                icon = Icons.Default.VolumeUp,
                iconBg = Color(0xFFEFE3FF),
                iconTint = Color(0xFF7C3AED),
                title = "Audio feedback",
                subtitle = "Hear pace and distance milestones",
                checked = audio,
                onCheckedChange = {
                    audio = it
                    WorkoutPrefs.setAudioEnabled(context, it)
                }
            )
            Spacer(Modifier.height(10.dp))
            SettingsUnitsRow(
                selected = units,
                onSelect = {
                    units = it
                    WorkoutPrefs.setUnits(context, it)
                }
            )

            Spacer(Modifier.height(20.dp))

            Button(
                onClick = onDismiss,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(50),
                colors = ButtonDefaults.buttonColors(containerColor = AITeal),
                elevation = ButtonDefaults.buttonElevation(0.dp)
            ) {
                Text(
                    text = "Done",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
            }
        }
    }
}

@Composable
private fun SettingsToggleRow(
    icon: ImageVector,
    iconBg: Color,
    iconTint: Color,
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg)
            .border(1.dp, SoftBorder, RoundedCornerShape(16.dp))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
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
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = title,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Text(
                text = subtitle,
                fontSize = 11.sp,
                color = TextSecondary
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = AITeal,
                uncheckedThumbColor = Color.White,
                uncheckedTrackColor = Color(0xFFCBD5E1),
                uncheckedBorderColor = Color(0xFFCBD5E1)
            )
        )
    }
}

@Composable
private fun SettingsUnitsRow(
    selected: String,
    onSelect: (String) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg)
            .border(1.dp, SoftBorder, RoundedCornerShape(16.dp))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(Color(0xFFFFE7D6)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Straighten,
                contentDescription = null,
                tint = Color(0xFFEA580C),
                modifier = Modifier.size(18.dp)
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = "Units",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Text(
                text = "Choose how distance is shown",
                fontSize = 11.sp,
                color = TextSecondary
            )
        }
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .background(Color(0xFFF1F5F9))
                .padding(3.dp),
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            UnitsChip(label = "km", isSelected = selected == "km", onClick = { onSelect("km") })
            UnitsChip(label = "mi", isSelected = selected == "mi", onClick = { onSelect("mi") })
        }
    }
}

@Composable
private fun UnitsChip(label: String, isSelected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(18.dp))
            .background(if (isSelected) AITeal else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (isSelected) Color.White else TextSecondary
        )
    }
}

// ── Workout Goal Sheet ─────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WorkoutGoalSheet(
    goalType: GoalType,
    initialValue: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    val title = when (goalType) {
        GoalType.DISTANCE -> "Distance goal"
        GoalType.DURATION -> "Duration goal"
        GoalType.CALORIES -> "Calories goal"
        GoalType.NO_GOAL -> ""
    }
    val subtitle = when (goalType) {
        GoalType.DISTANCE -> "How far would you like to go today?"
        GoalType.DURATION -> "How long do you want to train for?"
        GoalType.CALORIES -> "How many calories do you want to burn?"
        GoalType.NO_GOAL -> ""
    }
    val unit = when (goalType) {
        GoalType.DISTANCE -> "km"
        GoalType.DURATION -> "min"
        GoalType.CALORIES -> "kcal"
        GoalType.NO_GOAL -> ""
    }
    val presets = when (goalType) {
        GoalType.DISTANCE -> listOf("3", "5", "10")
        GoalType.DURATION -> listOf("20", "30", "60")
        GoalType.CALORIES -> listOf("200", "400", "600")
        GoalType.NO_GOAL -> emptyList()
    }

    var input by remember { mutableStateOf(initialValue) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Color.White,
        contentColor = TextPrimary,
        tonalElevation = 0.dp,
        dragHandle = null
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 24.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(title, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                    Text(subtitle, fontSize = 12.sp, color = TextSecondary)
                }
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFF1F5F9))
                        .clickable(onClick = onDismiss),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = TextSecondary,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color(0xFFF8FAFC))
                    .border(1.dp, SoftBorder, RoundedCornerShape(16.dp))
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                androidx.compose.foundation.text.BasicTextField(
                    value = input,
                    onValueChange = { new ->
                        // Allow digits and a single dot for distance
                        val filtered = if (goalType == GoalType.DISTANCE)
                            new.filter { it.isDigit() || it == '.' }
                        else new.filter { it.isDigit() }
                        input = filtered.take(6)
                    },
                    singleLine = true,
                    textStyle = androidx.compose.ui.text.TextStyle(
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextPrimary
                    ),
                    cursorBrush = androidx.compose.ui.graphics.SolidColor(AITeal),
                    keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
                        keyboardType = if (goalType == GoalType.DISTANCE)
                            androidx.compose.ui.text.input.KeyboardType.Decimal
                        else androidx.compose.ui.text.input.KeyboardType.Number
                    ),
                    modifier = Modifier.weight(1f),
                    decorationBox = { inner ->
                        if (input.isEmpty()) {
                            Text(
                                "0",
                                fontSize = 28.sp,
                                fontWeight = FontWeight.Bold,
                                color = TextSecondary
                            )
                        }
                        inner()
                    }
                )
                Text(
                    text = unit,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = TextSecondary
                )
            }

            if (presets.isNotEmpty()) {
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    presets.forEach { preset ->
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(20.dp))
                                .background(MintTint)
                                .clickable { input = preset }
                                .padding(horizontal = 14.dp, vertical = 8.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                "$preset $unit",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = AITealDark
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(20.dp))

            Button(
                onClick = {
                    val trimmed = input.trim().trimEnd('.')
                    if (trimmed.isNotEmpty() && (trimmed.toDoubleOrNull() ?: 0.0) > 0.0) {
                        onConfirm(trimmed)
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                enabled = (input.trim().trimEnd('.').toDoubleOrNull() ?: 0.0) > 0.0,
                shape = RoundedCornerShape(50),
                colors = ButtonDefaults.buttonColors(
                    containerColor = AITeal,
                    disabledContainerColor = AITeal.copy(alpha = 0.4f)
                ),
                elevation = ButtonDefaults.buttonElevation(0.dp)
            ) {
                Text(
                    text = "Save Goal",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
            }
        }
    }
}

// ── Activity Info Sheet ────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ActivityInfoSheet(onDismiss: () -> Unit) {
    val items = listOf(
        Triple("Run", "Higher intensity cardio. Tracks pace, distance, and calories using GPS.", "icons/run activity illustration.png"),
        Triple("Walk", "Low-impact movement that's great for daily steps and recovery days.", "icons/walk illustration.png"),
        Triple("Cycle", "Track ride distance, average speed, and elevation when outdoors.", "icons/cycle illustration.png"),
        Triple("Hike", "Outdoor trail tracking with elevation gain and time on trail.", "icons/hike illustration.png")
    )

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Color.White,
        contentColor = TextPrimary,
        tonalElevation = 0.dp,
        dragHandle = null
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 24.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("About activities", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                    Text("Pick the one that matches what you're doing today", fontSize = 12.sp, color = TextSecondary)
                }
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFF1F5F9))
                        .clickable(onClick = onDismiss),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = TextSecondary,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            items.forEach { (title, desc, asset) ->
                ActivityInfoRow(title = title, description = desc, asset = asset)
                Spacer(Modifier.height(10.dp))
            }

            Spacer(Modifier.height(8.dp))

            Button(
                onClick = onDismiss,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(50),
                colors = ButtonDefaults.buttonColors(containerColor = AITeal),
                elevation = ButtonDefaults.buttonElevation(0.dp)
            ) {
                Text(
                    text = "Got it",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
            }
        }
    }
}

@Composable
private fun ActivityInfoRow(title: String, description: String, asset: String) {
    val context = LocalContext.current
    val bitmap = remember(asset) {
        runCatching {
            context.assets.open(asset).use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg)
            .border(1.dp, SoftBorder, RoundedCornerShape(16.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(56.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(MintTint),
            contentAlignment = Alignment.Center
        ) {
            if (bitmap != null) {
                Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(56.dp)
                        .clip(RoundedCornerShape(12.dp))
                )
            }
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = TextPrimary)
            Text(description, fontSize = 11.sp, color = TextSecondary, lineHeight = 14.sp)
        }
    }
}
