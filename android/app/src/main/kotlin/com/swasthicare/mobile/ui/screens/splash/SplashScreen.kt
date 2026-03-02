package com.swasthicare.mobile.ui.screens.splash

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
    LaunchedEffect(Unit) {
        delay(1500)

        // Check for force update
        try {
            val config = AppContainer.supabaseClient.postgrest["app_config"]
                .select { filter { eq("key", "min_android_version") } }
                .decodeSingleOrNull<Map<String, String>>()
            val minVersion = config?.get("value")?.toIntOrNull() ?: 1
            val currentVersion = 1 // TODO: Use BuildConfig.VERSION_CODE

            if (currentVersion < minVersion) {
                onForceUpdate()
                return@LaunchedEffect
            }
        } catch (_: Exception) {
            // Network error — allow app to proceed
        }

        val prefs = AppContainer.dataStore.data.first()
        val onboardingDone = prefs[ONBOARDING_COMPLETE_KEY] ?: false
        if (onboardingDone) {
            onNavigateToLogin()
        } else {
            onNavigateToOnboarding()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.primary),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "SwasthiCare",
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onPrimary
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Your Health Companion",
                fontSize = 16.sp,
                color = MaterialTheme.colorScheme.onPrimary
            )
        }
    }
}
