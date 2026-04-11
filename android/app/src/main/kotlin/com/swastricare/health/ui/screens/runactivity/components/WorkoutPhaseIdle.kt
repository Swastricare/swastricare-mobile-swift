package com.swastricare.health.ui.screens.runactivity.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.GpsFixed
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.WorkoutTemplate
import com.swastricare.health.ui.screens.runactivity.LiveWorkoutUiState
import com.swastricare.health.ui.screens.runactivity.WorkoutType
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.SecondaryColor
import kotlinx.coroutines.delay

/**
 * IDLE phase component - workout type selection, templates, and START button.
 * Implements the new permission flow with rationale and settings handling.
 */
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

    // Show permission dialogs
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

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, bottom = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Top bar
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.Default.ArrowBack,
                    contentDescription = "Back",
                    tint = AppColors.onBackground
                )
            }
            Text(
                "Start Workout",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = AppColors.onBackground
            )
            Spacer(Modifier.size(48.dp))
        }

        Spacer(Modifier.height(16.dp))

        // Section header
        Text(
            "Choose Activity",
            style = MaterialTheme.typography.titleMedium,
            color = AppColors.onBackground,
            fontWeight = FontWeight.Medium
        )

        Spacer(Modifier.height(16.dp))

        // Workout type grid with staggered entry animation
        val types = WorkoutType.entries.toList()
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            for ((rowIndex, row) in types.chunked(3).withIndex()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    for ((colIndex, type) in row.withIndex()) {
                        val index = rowIndex * 3 + colIndex
                        var visible by remember { androidx.compose.runtime.mutableStateOf(false) }

                        LaunchedEffect(Unit) {
                            delay(index * 80L)
                            visible = true
                        }

                        AnimatedVisibility(
                            visible = visible,
                            enter = fadeIn(animationSpec = tween(300)) +
                                    scaleIn(initialScale = 0.8f, animationSpec = tween(300))
                        ) {
                            WorkoutTypeCard(
                                type = type,
                                isSelected = uiState.workoutType == type,
                                onClick = {
                                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                    onSelectWorkoutType(type)
                                },
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                    // Fill remaining space if row has fewer than 3 items
                    repeat(3 - row.size) {
                        Spacer(Modifier.weight(1f))
                    }
                }
            }
        }

        Spacer(Modifier.height(24.dp))

        // GPS Ready indicator
        if (usesGps && hasLocationPermission) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = SecondaryColor.copy(alpha = 0.15f)
                ),
                elevation = CardDefaults.cardElevation(
                    defaultElevation = 0.dp
                )
            ) {
                Row(
                    modifier = Modifier
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                        .fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Icon(
                        Icons.Default.GpsFixed,
                        contentDescription = null,
                        tint = SecondaryColor,
                        modifier = Modifier.size(20.dp)
                    )
                    Text(
                        "GPS ready - route will be recorded",
                        style = MaterialTheme.typography.bodySmall,
                        color = AppColors.onSurface.copy(alpha = 0.8f)
                    )
                }
            }
            Spacer(Modifier.height(16.dp))
        }

        // Templates section
        if (uiState.templates.isNotEmpty()) {
            Spacer(Modifier.height(24.dp))

            Text(
                "Templates",
                style = MaterialTheme.typography.titleMedium,
                color = AppColors.onBackground,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(12.dp))

            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(uiState.templates) { template ->
                    TemplateCard(
                        template = template,
                        isSelected = uiState.activeTemplate?.id == template.id,
                        onClick = {
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            onSelectTemplate(template)
                        }
                    )
                }
            }
        }

        Spacer(Modifier.weight(1f))

        // Start button
        Box(
            modifier = Modifier
                .size(120.dp)
                .clip(CircleShape)
                .background(SecondaryColor)
                .clickable {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    onStart()
                },
            contentAlignment = Alignment.Center
        ) {
            Text(
                "START",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Black,
                color = Color.White,
                fontSize = 22.sp
            )
        }

        Spacer(Modifier.height(40.dp))
    }
}
