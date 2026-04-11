package com.swastricare.health.ui.screens.runactivity.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GpsFixed
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.SecondaryColor

// ─────────────────────────────────────
// MARK: - Location Permission Rationale Sheet
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LocationPermissionRationale(
    onAllow: () -> Unit,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = AppColors.surface,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // GPS Icon
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .background(
                        color = SecondaryColor.copy(alpha = 0.15f),
                        shape = RoundedCornerShape(20.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.GpsFixed,
                    contentDescription = null,
                    tint = SecondaryColor,
                    modifier = Modifier.size(40.dp)
                )
            }

            Spacer(Modifier.height(8.dp))

            // Title
            Text(
                text = "Location Permission",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface,
                textAlign = TextAlign.Center
            )

            // Explanation
            Text(
                text = "SwasthiCare needs access to your location to track your route, distance, and provide accurate workout statistics.",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant,
                textAlign = TextAlign.Center,
                lineHeight = MaterialTheme.typography.bodyMedium.lineHeight * 1.5f
            )

            Spacer(Modifier.height(8.dp))

            // Allow Button
            Button(
                onClick = onAllow,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = SecondaryColor
                ),
                shape = RoundedCornerShape(16.dp)
            ) {
                Text(
                    text = "Allow Location Access",
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.titleMedium
                )
            }

            // Cancel Button
            TextButton(
                onClick = onDismiss,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = "Not Now",
                    color = AppColors.onSurfaceVariant,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Permission Settings Dialog
// ─────────────────────────────────────

@Composable
fun PermissionSettingsDialog(
    onOpenSettings: () -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = AppColors.surface,
        icon = {
            Icon(
                imageVector = Icons.Default.GpsFixed,
                contentDescription = null,
                tint = Color(0xFFFF6B6B),
                modifier = Modifier.size(32.dp)
            )
        },
        title = {
            Text(
                text = "Location Permission Denied",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
        },
        text = {
            Text(
                text = "Location access was permanently denied. To enable GPS tracking, please open Settings and grant location permission.",
                style = MaterialTheme.typography.bodyMedium,
                color = AppColors.onSurfaceVariant,
                lineHeight = MaterialTheme.typography.bodyMedium.lineHeight * 1.5f
            )
        },
        confirmButton = {
            Button(
                onClick = {
                    onOpenSettings()
                    onDismiss()
                },
                colors = ButtonDefaults.buttonColors(
                    containerColor = SecondaryColor
                ),
                shape = RoundedCornerShape(12.dp)
            ) {
                Text(
                    text = "Open Settings",
                    fontWeight = FontWeight.Bold
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(
                    text = "Cancel",
                    color = AppColors.onSurfaceVariant,
                    fontWeight = FontWeight.Medium
                )
            }
        },
        shape = RoundedCornerShape(24.dp)
    )
}
