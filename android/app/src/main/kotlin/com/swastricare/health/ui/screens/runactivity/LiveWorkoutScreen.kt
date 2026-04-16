package com.swastricare.health.ui.screens.runactivity

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Alignment
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.rememberMultiplePermissionsState
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.shouldShowRationale
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.runactivity.components.*
import com.swastricare.health.ui.theme.SecondaryColor

/**
 * LiveWorkoutScreen - Phase orchestrator for workout tracking.
 *
 * Simplified to ~350 lines by extracting phase components:
 * - WorkoutPhaseIdle
 * - WorkoutPhaseCountdown
 * - WorkoutPhaseTracking
 * - WorkoutPhasePaused
 * - WorkoutPhaseCompleted
 *
 * Implements new permission flow:
 * - Check permission when GPS workout selected
 * - Show rationale bottom sheet on first denial
 * - Show settings dialog on permanent denial
 * - Pre-flight permission check before START button works
 */
@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun LiveWorkoutScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToSummary: () -> Unit = {}
) {
    TrackScreen("LiveWorkout")
    val context = LocalContext.current
    val viewModel: LiveWorkoutViewModel = hiltViewModel()
    val uiState by viewModel.uiState.collectAsState()
    val permissionState by viewModel.permissionState.collectAsState()

    // ── Location Permission ──
    val locationPermissions = rememberMultiplePermissionsState(
        permissions = listOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
    ) { permissionsResult ->
        val fineGranted = permissionsResult[Manifest.permission.ACCESS_FINE_LOCATION] == true
        val coarseGranted = permissionsResult[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        val granted = fineGranted || coarseGranted

        viewModel.onLocationPermissionResult(granted)

        // Update permission state
        if (granted) {
            viewModel.checkLocationPermission(granted = true, shouldShowRationale = false)
        }
    }

    // Check permission status when workout type changes to GPS-based
    LaunchedEffect(uiState.workoutType) {
        if (uiState.workoutType.usesGps) {
            val hasAny = locationPermissions.permissions.any { it.status.isGranted }
            viewModel.onLocationPermissionResult(hasAny)

            if (!hasAny) {
                // Check if we should show rationale or if permanently denied
                val shouldShowRationale = locationPermissions.permissions.any {
                    it.status.shouldShowRationale
                }
                val isPermanentlyDenied = !shouldShowRationale &&
                    locationPermissions.permissions.all { !it.status.isGranted }

                viewModel.checkLocationPermission(
                    granted = false,
                    shouldShowRationale = shouldShowRationale || !isPermanentlyDenied
                )
            } else {
                viewModel.checkLocationPermission(granted = true, shouldShowRationale = false)
            }
        }
    }

    // ── Too-short workout dialog ──
    var showTooShortDialog by remember { mutableStateOf(false) }

    if (showTooShortDialog) {
        TooShortWorkoutDialog(
            onContinue = { showTooShortDialog = false },
            onEnd = {
                showTooShortDialog = false
                viewModel.resetWorkout()
                onNavigateBack()
            }
        )
    }

    // Helper: check if workout is too short before stopping
    val onStopRequested = {
        val tooShort = uiState.elapsedSeconds < 20 || uiState.distanceMeters < 30
        if (tooShort) {
            showTooShortDialog = true
        } else {
            viewModel.stopWorkout()
        }
    }

    // Group TRACKING and PAUSED into the same Crossfade key so the map
    // is never destroyed/recreated when toggling pause.
    val crossfadeKey = when (uiState.phase) {
        WorkoutPhase.TRACKING, WorkoutPhase.PAUSED -> "ACTIVE"
        else -> uiState.phase.name
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Crossfade(
            targetState = crossfadeKey,
            animationSpec = when (uiState.phase) {
                WorkoutPhase.COUNTDOWN -> tween(400, easing = FastOutSlowInEasing)
                WorkoutPhase.TRACKING -> tween(500, easing = FastOutSlowInEasing)
                WorkoutPhase.COMPLETED -> tween(600, easing = EaseOutBack)
                else -> tween(300)
            },
            label = "phaseTransition"
        ) { key ->
            when (key) {
            "IDLE" -> WorkoutPhaseIdle(
                uiState = uiState,
                hasLocationPermission = uiState.hasLocationPermission,
                usesGps = uiState.workoutType.usesGps,
                showPermissionRationale = permissionState.showRationaleSheet,
                showPermissionSettings = permissionState.showSettingsDialog,
                onSelectWorkoutType = { type ->
                    viewModel.setWorkoutType(type)
                },
                onSelectTemplate = { template ->
                    viewModel.selectTemplate(template)
                },
                onStart = {
                    // Pre-flight permission check
                    if (uiState.workoutType.usesGps) {
                        if (!locationPermissions.allPermissionsGranted) {
                            val shouldShowRationale = locationPermissions.permissions.any {
                                it.status.shouldShowRationale
                            }
                            val isPermanentlyDenied = !shouldShowRationale &&
                                locationPermissions.permissions.all { !it.status.isGranted }

                            if (isPermanentlyDenied) {
                                viewModel.checkLocationPermission(
                                    granted = false,
                                    shouldShowRationale = false
                                )
                                return@WorkoutPhaseIdle
                            } else {
                                if (permissionState.status == PermissionStatus.NOT_CHECKED) {
                                    viewModel.checkLocationPermission(
                                        granted = false,
                                        shouldShowRationale = true
                                    )
                                    return@WorkoutPhaseIdle
                                }
                            }
                        }
                    }

                    if (viewModel.canStartWorkout()) {
                        viewModel.startWorkout()
                    }
                },
                onBack = onNavigateBack,
                onOpenSettings = {
                    context.startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", context.packageName, null)
                        }
                    )
                },
                onDismissRationale = {
                    viewModel.dismissRationaleSheet()
                },
                onDismissSettings = {
                    viewModel.dismissSettingsDialog()
                },
                onRequestPermission = {
                    locationPermissions.launchMultiplePermissionRequest()
                }
            )

            "COUNTDOWN" -> WorkoutPhaseCountdown(
                countdownValue = uiState.countdownValue
            )

            "ACTIVE" -> WorkoutPhaseTracking(
                uiState = uiState,
                isPaused = uiState.phase == WorkoutPhase.PAUSED,
                onPause = { viewModel.pauseWorkout() },
                onResume = { viewModel.resumeWorkout() },
                onStop = onStopRequested,
                onToggleAutoPause = { viewModel.toggleAutoPause() }
            )

            "COMPLETED" -> WorkoutPhaseCompleted(
                uiState = uiState,
                onDone = {
                    viewModel.saveCompletedWorkout()
                    viewModel.resetWorkout()
                    onNavigateBack()
                },
                onDiscard = {
                    viewModel.resetWorkout()
                    onNavigateBack()
                }
            )
            }
        }
    }
}

@Composable
private fun TooShortWorkoutDialog(onContinue: () -> Unit, onEnd: () -> Unit) {
    androidx.compose.ui.window.Dialog(
        onDismissRequest = onContinue,
        properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(start = 16.dp, end = 16.dp, bottom = 12.dp),
            contentAlignment = Alignment.BottomCenter
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        color = MaterialTheme.colorScheme.surface,
                        shape = RoundedCornerShape(28.dp)
                    )
                    .padding(horizontal = 24.dp, vertical = 28.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "Workout too short",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = "Workout time is too short. This session won't be recorded. End anyway?",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    lineHeight = MaterialTheme.typography.bodyMedium.fontSize * 1.5
                )
                Spacer(Modifier.height(4.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Button(
                        onClick = onContinue,
                        modifier = Modifier.weight(1f).height(52.dp),
                        shape = RoundedCornerShape(50.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant,
                            contentColor = MaterialTheme.colorScheme.onSurface
                        ),
                        elevation = ButtonDefaults.buttonElevation(0.dp)
                    ) {
                        Text("Continue", fontWeight = FontWeight.SemiBold)
                    }
                    Button(
                        onClick = onEnd,
                        modifier = Modifier.weight(1f).height(52.dp),
                        shape = RoundedCornerShape(50.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFF4757)),
                        elevation = ButtonDefaults.buttonElevation(0.dp)
                    ) {
                        Text("End", fontWeight = FontWeight.SemiBold, color = Color.White)
                    }
                }
                Spacer(Modifier.navigationBarsPadding())
            }
        }
    }
}
