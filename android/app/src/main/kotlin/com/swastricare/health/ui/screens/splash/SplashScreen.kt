package com.swastricare.health.ui.screens.splash

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.airbnb.lottie.compose.LottieAnimation
import com.airbnb.lottie.compose.LottieCompositionSpec
import com.airbnb.lottie.compose.animateLottieCompositionAsState
import com.airbnb.lottie.compose.rememberLottieComposition
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withTimeoutOrNull

// Version checking is handled by AppVersionService in AppNavigation (matches iOS pattern).
// SplashScreen only handles logo animation and onboarding routing.

@Composable
fun SplashScreen(
    onNavigateToHome: () -> Unit,
    onNavigateToLogin: () -> Unit,
    onNavigateToOnboarding: () -> Unit
) {
    val splashVm: SplashViewModel = hiltViewModel()
    val isDark = isSystemInDarkTheme()
    // Splash background follows the system theme. The fade-out overlay
    // blends into the same color so the transition into the next screen
    // stays seamless in both light and dark modes.
    val splashBackground = if (isDark) Color.Black else Color.White

    // Fade-out overlay for cinematic exit (matches iOS)
    var fadeOut by remember { mutableStateOf(false) }
    val screenAlpha by animateFloatAsState(
        targetValue = if (fadeOut) 1f else 0f,
        animationSpec = tween(400),
        label = "fadeOut"
    )

    // Load the Lottie logo animation from assets — plays once and holds on last frame
    val composition by rememberLottieComposition(
        LottieCompositionSpec.Asset("animations/swasrticare-logo.json")
    )
    // Source animation is ~4.95s @ 60fps. Speed it up so it plays through in
    // exactly 2 seconds: speed = 4.95 / 2.0 ≈ 2.475.
    val progress by animateLottieCompositionAsState(
        composition = composition,
        iterations = 1,
        isPlaying = true,
        speed = 2.475f,
        restartOnPlay = false
    )

    // Navigation logic — wait for the Lottie animation to play through fully
    // AND for the home preload to finish (each capped so a slow network or a
    // missing composition can't stall the app indefinitely).
    LaunchedEffect(Unit) {
        coroutineScope {
            val preloadJob = async {
                withTimeoutOrNull(2_500) { splashVm.preloadHomeData() }
            }
            val animationJob = async {
                // Watch progress through the Snapshot system; cap to a safe
                // upper bound in case the composition fails to load.
                withTimeoutOrNull(3_000) {
                    snapshotFlow { progress }.first { it >= 0.99f }
                }
            }
            preloadJob.await()
            animationJob.await()
        }

        val isAuthed = splashVm.isAuthenticated()
        val onboardingDone = splashVm.isOnboardingComplete()

        fadeOut = true
        delay(250)

        when {
            isAuthed -> onNavigateToHome()
            onboardingDone -> onNavigateToLogin()
            else -> onNavigateToOnboarding()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(splashBackground),
        contentAlignment = Alignment.Center
    ) {
        // Centered Lottie logo animation — sized to read as a logo.
        LottieAnimation(
            composition = composition,
            progress = { progress },
            modifier = Modifier.size(180.dp)
        )

        // Fade overlay for cinematic exit — matches the theme background.
        Box(
            modifier = Modifier
                .fillMaxSize()
                .alpha(screenAlpha)
                .background(splashBackground)
        )
    }
}
