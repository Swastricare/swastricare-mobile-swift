package com.swasthicare.mobile.ui.screens.runactivity

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material.icons.filled.Pool
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Route
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.services.SavedWorkoutState
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.theme.PremiumColor
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

// ---- Color palette for workout types --------------------------------------

private val RunningColor = Color(0xFF22C55E)
private val WalkingColor = Color(0xFF64D2FF)
private val CyclingColor = Color(0xFFFF9F0A)
private val HikingColor = Color(0xFF30D158)
private val SwimmingColor = Color(0xFF4F46E5)
private val DiscardRed = Color(0xFFFF453A)
private val WarningOrange = Color(0xFFFF9F0A)

// ---- Helpers ---------------------------------------------------------------

private fun workoutTypeIcon(type: String): ImageVector = when (type.uppercase()) {
    "RUNNING"  -> Icons.Default.DirectionsRun
    "WALKING"  -> Icons.Default.DirectionsWalk
    "CYCLING"  -> Icons.Default.DirectionsBike
    "HIKING"   -> Icons.Default.Terrain
    "SWIMMING" -> Icons.Default.Pool
    else       -> Icons.Default.DirectionsRun
}

private fun workoutTypeLabel(type: String): String = when (type.uppercase()) {
    "RUNNING"  -> "Running"
    "WALKING"  -> "Walking"
    "CYCLING"  -> "Cycling"
    "HIKING"   -> "Hiking"
    "SWIMMING" -> "Swimming"
    else       -> type.replaceFirstChar { it.uppercase() }
}

private fun workoutTypeEmoji(type: String): String = when (type.uppercase()) {
    "RUNNING"  -> "\uD83C\uDFC3"
    "WALKING"  -> "\uD83D\uDEB6"
    "CYCLING"  -> "\uD83D\uDEB4"
    "HIKING"   -> "\u26F0\uFE0F"
    "SWIMMING" -> "\uD83C\uDFCA"
    else       -> "\uD83C\uDFC3"
}

private fun workoutTypeColor(type: String): Color = when (type.uppercase()) {
    "RUNNING"  -> RunningColor
    "WALKING"  -> WalkingColor
    "CYCLING"  -> CyclingColor
    "HIKING"   -> HikingColor
    "SWIMMING" -> SwimmingColor
    else       -> RunningColor
}

private fun formatElapsedTime(seconds: Long): String {
    val h = seconds / 3600
    val m = (seconds % 3600) / 60
    val s = seconds % 60
    return if (h > 0) String.format(Locale.US, "%d:%02d:%02d", h, m, s)
    else String.format(Locale.US, "%02d:%02d", m, s)
}

private fun formatStartTime(isoString: String): String {
    return try {
        val instant = Instant.parse(isoString)
        val zdt = instant.atZone(ZoneId.systemDefault())
        val formatter = DateTimeFormatter.ofPattern("d MMM, h:mm a", Locale.US)
        zdt.format(formatter)
    } catch (_: Exception) {
        isoString
    }
}

private fun formatDistance(meters: Double): String {
    val km = meters / 1000.0
    return String.format(Locale.US, "%.2f km", km)
}

// ---- Composable: WorkoutRecoveryDialog ------------------------------------

/**
 * Modal bottom sheet displayed on app launch when [WorkoutStateManager]
 * detects an abandoned workout from a previous session.
 *
 * @param savedState      The recovered workout state.
 * @param onResume        Called when the user wants to continue the workout.
 * @param onDiscard       Called when the user wants to throw it away.
 * @param onDismissRequest Called when the sheet is dismissed externally.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WorkoutRecoveryDialog(
    savedState: SavedWorkoutState,
    onResume: (SavedWorkoutState) -> Unit,
    onDiscard: () -> Unit,
    onDismissRequest: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var showDiscardConfirmation by remember { mutableStateOf(false) }
    var contentVisible by remember { mutableStateOf(false) }

    // Trigger the fade-in after the sheet settles
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(300)
        contentVisible = true
    }

    // Warning icon pulsing animation
    val infiniteTransition = rememberInfiniteTransition(label = "warningPulse")
    val warningScale by infiniteTransition.animateFloat(
        initialValue = 0.9f,
        targetValue = 1.1f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "warningScale"
    )

    val activityColor = workoutTypeColor(savedState.workoutType)

    ModalBottomSheet(
        onDismissRequest = onDismissRequest,
        sheetState = sheetState,
        containerColor = Color.Transparent,
        dragHandle = null,
        tonalElevation = 0.dp,
        scrimColor = Color.Black.copy(alpha = 0.5f)
    ) {
        // Glass-morphism sheet body with purple tint
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 28.dp, opacity = 0.35f)
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            PremiumColor.DeepPurpleStart.copy(alpha = 0.15f),
                            Color.Transparent
                        )
                    ),
                    shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
                )
                .padding(horizontal = 24.dp)
                .padding(top = 28.dp, bottom = 36.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // -- Drag indicator
            Box(
                modifier = Modifier
                    .width(40.dp)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f))
            )

            // -- Pulsing warning icon
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .scale(warningScale)
                    .background(WarningOrange.copy(alpha = 0.15f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = "Warning",
                    tint = WarningOrange,
                    modifier = Modifier.size(28.dp)
                )
            }

            // -- Title
            Text(
                text = "Unfinished Workout Detected",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center
            )

            Text(
                text = "It looks like your last workout ended unexpectedly. Would you like to pick up where you left off?",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 8.dp)
            )

            // -- Workout info card with fade-in
            AnimatedVisibility(
                visible = contentVisible,
                enter = fadeIn(tween(500)) + slideInVertically(
                    initialOffsetY = { it / 4 },
                    animationSpec = tween(500, easing = FastOutSlowInEasing)
                )
            ) {
                WorkoutInfoCard(savedState = savedState, activityColor = activityColor)
            }

            Spacer(modifier = Modifier.height(4.dp))

            // -- Buttons
            // Resume
            Button(
                onClick = { onResume(savedState) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
                contentPadding = PaddingValues()
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            brush = Brush.horizontalGradient(
                                colors = listOf(
                                    PremiumColor.RoyalBlueStart,
                                    PremiumColor.NeonGreenStart
                                )
                            ),
                            shape = RoundedCornerShape(16.dp)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "Resume Workout",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }

            // Discard
            if (showDiscardConfirmation) {
                OutlinedButton(
                    onClick = {
                        onDiscard()
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = DiscardRed
                    ),
                    border = androidx.compose.foundation.BorderStroke(1.5.dp, DiscardRed)
                ) {
                    Text(
                        text = "Yes, Discard Workout",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            } else {
                OutlinedButton(
                    onClick = { showDiscardConfirmation = true },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = DiscardRed
                    ),
                    border = androidx.compose.foundation.BorderStroke(1.5.dp, DiscardRed.copy(alpha = 0.5f))
                ) {
                    Text(
                        text = "Discard",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

// ---- Composable: WorkoutInfoCard ------------------------------------------

@Composable
private fun WorkoutInfoCard(
    savedState: SavedWorkoutState,
    activityColor: Color
) {
    val icon = workoutTypeIcon(savedState.workoutType)
    val label = workoutTypeLabel(savedState.workoutType)
    val emoji = workoutTypeEmoji(savedState.workoutType)

    Box(
        modifier = Modifier.fillMaxWidth()
    ) {
        // Left accent border
        Box(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .width(4.dp)
                .matchParentSize()
                .clip(RoundedCornerShape(topStart = 16.dp, bottomStart = 16.dp))
                .background(activityColor)
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .glass(cornerRadius = 16.dp, opacity = 0.20f)
                .padding(start = 12.dp) // extra indent past accent bar
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Activity type row
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .background(activityColor.copy(alpha = 0.15f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = label,
                        tint = activityColor,
                        modifier = Modifier.size(20.dp)
                    )
                }

                Text(
                    text = "$emoji $label",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }

            // Divider
            HorizontalDivider(
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.12f)
            )

            // Details grid
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                // Started at
                DetailColumn(
                    icon = Icons.Default.AccessTime,
                    label = "Started",
                    value = formatStartTime(savedState.startTime),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                // Duration
                DetailColumn(
                    icon = Icons.Default.AccessTime,
                    label = "Duration",
                    value = formatElapsedTime(savedState.elapsedSeconds),
                    tint = activityColor
                )

                // Distance (only if meaningful)
                if (savedState.distanceMeters > 0) {
                    DetailColumn(
                        icon = Icons.Default.Route,
                        label = "Distance",
                        value = formatDistance(savedState.distanceMeters),
                        tint = activityColor
                    )
                }
            }
        }
    }
}

@Composable
private fun DetailColumn(
    icon: ImageVector,
    label: String,
    value: String,
    tint: Color
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(16.dp)
        )
        Column {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = value,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}
