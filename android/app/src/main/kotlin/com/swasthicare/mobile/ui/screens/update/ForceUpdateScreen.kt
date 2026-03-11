package com.swasthicare.mobile.ui.screens.update

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.SystemUpdate
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.ui.screens.auth.components.PremiumColors
import com.swasthicare.mobile.ui.theme.PrimaryColor

/**
 * ForceUpdateScreen
 * Blocking full-screen overlay requiring the user to update the app.
 * No back/dismiss option. Matches iOS ForceUpdateView.
 *
 * Uses server-provided updateTitle/updateMessage when available,
 * falls back to defaults.
 */
@Composable
fun ForceUpdateScreen(
    currentVersion: String,
    latestVersion: String,
    updateTitle: String? = null,
    updateMessage: String? = null,
    storeUrl: String? = null
) {
    val context = LocalContext.current

    // Block back button
    BackHandler(enabled = true) {
        // Do nothing - this screen is blocking
    }

    val infiniteTransition = rememberInfiniteTransition(label = "forceUpdateAnim")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(
                        Color(0xFFF8FAFC),
                        Color(0xFFEFF4F9),
                        Color(0xFFE2E9F3)
                    )
                )
            )
    ) {
        // Decorative circles
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 100.dp, y = (-100).dp)
                .size(400.dp)
                .background(PremiumColors.Cyan.copy(alpha = 0.05f), CircleShape)
                .blur(80.dp)
        )
        Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .offset(x = (-100).dp, y = 100.dp)
                .size(400.dp)
                .background(PremiumColors.RoyalBlue.copy(alpha = 0.05f), CircleShape)
                .blur(80.dp)
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // App Logo
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .scale(pulseScale)
                    .background(
                        Brush.linearGradient(
                            listOf(PremiumColors.RoyalBlue, PremiumColors.Cyan)
                        ),
                        RoundedCornerShape(28.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Favorite,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(48.dp)
                )
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Update icon
            Icon(
                imageVector = Icons.Default.SystemUpdate,
                contentDescription = null,
                tint = PrimaryColor,
                modifier = Modifier.size(48.dp)
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Title (server-provided or default)
            Text(
                text = updateTitle ?: "Update Required",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = PremiumColors.TextDark,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Version info
            Text(
                text = "Current: v$currentVersion",
                style = MaterialTheme.typography.bodyMedium,
                color = PremiumColors.TextGrey
            )
            if (latestVersion.isNotBlank()) {
                Text(
                    text = "Latest: v$latestVersion",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = PrimaryColor
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Description (server-provided or default)
            Text(
                text = updateMessage
                    ?: "A critical update is required to continue using SwasthiCare. Please update to the latest version for the best experience.",
                style = MaterialTheme.typography.bodyMedium,
                color = PremiumColors.TextGrey,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 16.dp)
            )

            Spacer(modifier = Modifier.height(40.dp))

            // Update button
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
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = PrimaryColor
                )
            ) {
                Text(
                    text = "Update Now",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }
        }
    }
}
