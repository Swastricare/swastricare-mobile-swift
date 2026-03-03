package com.swasthicare.mobile.ui.lock

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Fingerprint
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.outlined.Pin
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.theme.PremiumColor
import com.swasthicare.mobile.ui.theme.PrimaryColor

/**
 * Full-screen biometric lock overlay.
 *
 * Features:
 *  - App logo/name centered
 *  - "SwasthiCare is Locked" message
 *  - "Unlock with Face ID / Fingerprint" button with biometric icon
 *  - "Use Passcode" fallback option
 *  - Premium dark background (PremiumBackground)
 *  - Smooth fade-in animation on appear
 *
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

    // --- Fade-in on appear ---
    var visible by remember { mutableStateOf(false) }
    val fadeAlpha by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = tween(durationMillis = 600, easing = FastOutSlowInEasing),
        label = "lockFadeIn"
    )
    LaunchedEffect(Unit) { visible = true }

    // --- Pulsing fingerprint animation ---
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
            .alpha(fadeAlpha)
    ) {
        // Premium animated background layer
        PremiumBackground()

        // Dark overlay for readability
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            PremiumColor.MidnightStart.copy(alpha = 0.85f),
                            PremiumColor.MidnightEnd.copy(alpha = 0.75f),
                            PrimaryColor.copy(alpha = 0.25f)
                        )
                    )
                )
        )

        // Content
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 32.dp)
        ) {
            Spacer(modifier = Modifier.weight(1f))

            // --- App Icon ---
            Box(
                modifier = Modifier
                    .size(88.dp)
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
                    modifier = Modifier.size(40.dp)
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // --- App Name ---
            Text(
                text = "SwasthiCare",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Spacer(modifier = Modifier.height(8.dp))

            // --- Locked message ---
            Text(
                text = "SwasthiCare is Locked",
                style = MaterialTheme.typography.bodyLarge,
                color = Color.White.copy(alpha = 0.75f),
                textAlign = TextAlign.Center
            )
            Text(
                text = "Unlock to access your health data",
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.55f),
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.weight(1f))

            // --- Fingerprint / Biometric icon with pulse ---
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

            Spacer(modifier = Modifier.height(12.dp))

            // --- Biometric unlock label ---
            Text(
                text = "Unlock with Face ID / Fingerprint",
                style = MaterialTheme.typography.labelLarge,
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(24.dp))

            // --- Use Passcode fallback button ---
            OutlinedButton(
                onClick = {
                    // Re-triggers the system prompt which already includes
                    // DEVICE_CREDENTIAL (PIN/Pattern/Password) fallback.
                    if (activity != null) {
                        viewModel.authenticate(activity)
                    }
                },
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = Color.White
                ),
                border = androidx.compose.foundation.BorderStroke(
                    width = 1.dp,
                    brush = Brush.linearGradient(
                        colors = listOf(
                            Color.White.copy(alpha = 0.3f),
                            Color.White.copy(alpha = 0.15f)
                        )
                    )
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Outlined.Pin,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                    tint = Color.White.copy(alpha = 0.8f)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Use Passcode",
                    style = MaterialTheme.typography.labelLarge,
                    color = Color.White.copy(alpha = 0.8f)
                )
            }

            // --- Error message ---
            if (authError != null) {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = authError!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                    textAlign = TextAlign.Center
                )
            }

            Spacer(modifier = Modifier.height(48.dp))
        }
    }
}
