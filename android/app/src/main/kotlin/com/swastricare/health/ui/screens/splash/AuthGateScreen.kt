package com.swastricare.health.ui.screens.splash

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.ui.theme.AITeal

/**
 * Silent auth-gate. Runs the same routing decision as [SplashScreen] but
 * skips the Lottie/cinematic so users coming back from login/signup don't
 * see the splash animation a second time. Cold-launch still uses [SplashScreen].
 */
@Composable
fun AuthGateScreen(
    onNavigateToHome: () -> Unit,
    onNavigateToLogin: () -> Unit,
    onNavigateToOnboarding: () -> Unit,
    onNavigateToHealthProfile: () -> Unit
) {
    val splashVm: SplashViewModel = hiltViewModel()

    LaunchedEffect(Unit) {
        val isAuthed = splashVm.isAuthenticated()
        val onboardingDone = splashVm.isOnboardingComplete()
        val healthProfileDone = if (isAuthed) splashVm.isHealthProfileComplete() else true

        when {
            !isAuthed && !onboardingDone -> onNavigateToOnboarding()
            !isAuthed -> onNavigateToLogin()
            !healthProfileDone -> onNavigateToHealthProfile()
            else -> onNavigateToHome()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(
            color = AITeal,
            modifier = Modifier.size(36.dp),
            strokeWidth = 3.dp
        )
    }
}
