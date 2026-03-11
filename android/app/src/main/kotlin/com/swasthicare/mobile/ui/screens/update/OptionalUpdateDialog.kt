package com.swasthicare.mobile.ui.screens.update

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SystemUpdate
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.swasthicare.mobile.ui.theme.AppColors
import com.swasthicare.mobile.ui.theme.PrimaryColor

/**
 * OptionalUpdateDialog
 * Dismissable dialog shown when a non-mandatory update is available.
 * Uses server-provided title/message when available.
 * "Later" dismisses for 24 hours.
 */
@Composable
fun OptionalUpdateDialog(
    newVersion: String,
    updateTitle: String? = null,
    updateMessage: String? = null,
    storeUrl: String?,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = RoundedCornerShape(24.dp),
        icon = {
            Icon(
                imageVector = Icons.Default.SystemUpdate,
                contentDescription = null,
                tint = PrimaryColor,
                modifier = Modifier.size(40.dp)
            )
        },
        title = {
            Text(
                text = updateTitle ?: "Update Available",
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = updateMessage
                        ?: "Version $newVersion is available with improvements and bug fixes.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppColors.onSurfaceVariant,
                    textAlign = TextAlign.Center
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val url = storeUrl ?: "market://details?id=com.swasthicare.mobile"
                    try {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    } catch (_: Exception) {
                        context.startActivity(
                            Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("https://play.google.com/store/apps/details?id=com.swasthicare.mobile")
                            )
                        )
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
            ) {
                Text("Update")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Maybe Later")
            }
        }
    )
}
