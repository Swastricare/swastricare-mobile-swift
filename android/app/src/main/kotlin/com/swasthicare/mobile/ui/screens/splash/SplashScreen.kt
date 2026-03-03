package com.swasthicare.mobile.ui.screens.splash

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.di.ONBOARDING_COMPLETE_KEY
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first

@Composable
fun SplashScreen(
    onNavigateToHome: () -> Unit,
    onNavigateToLogin: () -> Unit,
    onNavigateToOnboarding: () -> Unit,
    onForceUpdate: () -> Unit
) {
    // Cinematic entry animation
    var startAnimation by remember { mutableStateOf(false) }
    var fadeOut by remember { mutableStateOf(false) }

    val logoScale by animateFloatAsState(
        targetValue = if (startAnimation) 1f else 0.5f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioLowBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "logoScale"
    )
    val logoAlpha by animateFloatAsState(
        targetValue = if (startAnimation) 1f else 0f,
        animationSpec = tween(800),
        label = "logoAlpha"
    )
    val subtitleAlpha by animateFloatAsState(
        targetValue = if (startAnimation) 1f else 0f,
        animationSpec = tween(800, delayMillis = 400),
        label = "subtitleAlpha"
    )
    val screenAlpha by animateFloatAsState(
        targetValue = if (fadeOut) 0f else 1f,
        animationSpec = tween(500),
        label = "fadeOut"
    )

    // Pulsing glow
    val infiniteTransition = rememberInfiniteTransition(label = "glow")
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.7f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "glowAlpha"
    )

    LaunchedEffect(Unit) {
        startAnimation = true
        delay(2500)

        // Check for force update
        try {
            val config = AppContainer.supabaseClient.postgrest["app_config"]
                .select { filter { eq("key", "min_android_version") } }
                .decodeSingleOrNull<Map<String, String>>()
            val minVersion = config?.get("value")?.toIntOrNull() ?: 1
            val currentVersion = 1 // TODO: Use BuildConfig.VERSION_CODE

            if (currentVersion < minVersion) {
                fadeOut = true
                delay(500)
                onForceUpdate()
                return@LaunchedEffect
            }
        } catch (_: Exception) { }

        val prefs = AppContainer.dataStore.data.first()
        val onboardingDone = prefs[ONBOARDING_COMPLETE_KEY] ?: false

        fadeOut = true
        delay(500)

        if (onboardingDone) {
            onNavigateToLogin()
        } else {
            onNavigateToOnboarding()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .alpha(screenAlpha)
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF0D1B2A),
                        Color(0xFF1B2838),
                        Color(0xFF0D1B2A)
                    )
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        // Background glow orb
        Box(
            modifier = Modifier
                .size(200.dp)
                .alpha(glowAlpha)
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            Color(0xFF2196F3).copy(alpha = 0.4f),
                            Color(0xFF00BCD4).copy(alpha = 0.2f),
                            Color.Transparent
                        )
                    )
                )
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // App name with scale animation
            Text(
                text = "SwasthiCare",
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier
                    .scale(logoScale)
                    .alpha(logoAlpha)
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Your Health Companion",
                fontSize = 16.sp,
                color = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.alpha(subtitleAlpha)
            )
        }
    }
}
