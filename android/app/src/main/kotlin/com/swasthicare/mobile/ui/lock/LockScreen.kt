package com.swasthicare.mobile.ui.lock

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Fingerprint
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import com.swasthicare.mobile.ui.theme.PremiumColor
import com.swasthicare.mobile.ui.theme.PrimaryColor

/**
 * Full-screen lock overlay.
 * Auto-triggers biometric prompt on appear.
 */
@Composable
fun LockScreen(
    viewModel: LockScreenViewModel,
    modifier: Modifier = Modifier
) {
    val authError by viewModel.authError.collectAsState()
    val context = LocalContext.current
    val activity = context as? FragmentActivity

    // Pulsing fingerprint animation
    val infiniteTransition = rememberInfiniteTransition(label = "lockPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 0.95f,
        targetValue = 1.1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "fingerprintScale"
    )
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.6f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "fingerprintAlpha"
    )

    // Auto-trigger biometric on appear
    LaunchedEffect(Unit) {
        if (activity != null && viewModel.canUseBiometric) {
            viewModel.authenticate(activity)
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        PremiumColor.MidnightStart,
                        PremiumColor.MidnightEnd,
                        PrimaryColor.copy(alpha = 0.3f)
                    )
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(32.dp),
            modifier = Modifier.padding(32.dp)
        ) {
            // App Icon
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(PrimaryColor, PremiumColor.RoyalBlueEnd)
                        ),
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(36.dp)
                )
            }

            // Title
            Text(
                text = "SwasthiCare",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Text(
                text = "Unlock to access your health data",
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Fingerprint Icon with pulsing animation
            IconButton(
                onClick = {
                    if (activity != null) {
                        viewModel.authenticate(activity)
                    }
                },
                modifier = Modifier
                    .size(80.dp)
                    .scale(pulseScale)
                    .background(
                        PrimaryColor.copy(alpha = 0.15f * pulseAlpha),
                        CircleShape
                    )
            ) {
                Icon(
                    imageVector = Icons.Default.Fingerprint,
                    contentDescription = "Unlock with Biometric",
                    tint = Color.White.copy(alpha = pulseAlpha),
                    modifier = Modifier.size(48.dp)
                )
            }

            Text(
                text = "Tap to unlock",
                style = MaterialTheme.typography.labelLarge,
                color = Color.White.copy(alpha = 0.6f)
            )

            // Error message
            if (authError != null) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = authError!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}
