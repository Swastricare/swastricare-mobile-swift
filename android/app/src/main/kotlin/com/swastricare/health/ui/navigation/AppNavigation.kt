package com.swastricare.health.ui.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.swastricare.health.data.services.AppUpdateCheckResult
import com.swastricare.health.data.services.AppUpdateStatus
import com.swastricare.health.navigation.DeepLinkHandler
import com.swastricare.health.navigation.DeepLinkRoute
import com.swastricare.health.ui.screens.ar.ARBodyScanScreen
import com.swastricare.health.ui.screens.auth.AuthUiState
import com.swastricare.health.ui.screens.auth.AuthViewModel
import com.swastricare.health.ui.screens.auth.EmailVerificationScreen
import com.swastricare.health.ui.screens.auth.LoginScreen
import com.swastricare.health.ui.screens.auth.NewPasswordScreen
import com.swastricare.health.ui.screens.auth.ResetPasswordScreen
import com.swastricare.health.ui.screens.auth.SignUpScreen
import com.swastricare.health.ui.screens.main.MainScreen
import com.swastricare.health.ui.screens.onboarding.ConsentScreen
import com.swastricare.health.ui.screens.onboarding.HealthProfileScreen
import com.swastricare.health.ui.screens.onboarding.HealthProfileViewModel
import com.swastricare.health.ui.screens.onboarding.OnboardingScreen
import com.swastricare.health.ui.screens.splash.SplashScreen
import com.swastricare.health.ui.screens.update.ForceUpdateScreen
import com.swastricare.health.ui.screens.update.OptionalUpdateDialog
import kotlinx.coroutines.launch

/**
 * App Navigation with Authentication and Version Checking
 * Matches iOS navigation state machine:
 * Splash -> ForceUpdate? -> Onboarding -> Consent -> Login -> HealthProfile? -> Main
 */
@Composable
fun AppNavigation(
    authViewModel: AuthViewModel,
    deepLinkRoute: DeepLinkRoute? = null,
    onDeepLinkConsumed: () -> Unit = {}
) {
    val navVm: AppNavigationViewModel = hiltViewModel()
    val navController = rememberNavController()
    val authState by authViewModel.uiState.collectAsState()
    val isProcessingDeepLink by authViewModel.isProcessingDeepLink.collectAsState()
    val scope = rememberCoroutineScope()
    val lifecycleOwner = LocalLifecycleOwner.current

    // Version check state (matches iOS AppVersionService flow)
    var updateResult by remember { mutableStateOf<AppUpdateCheckResult?>(null) }
    var showOptionalDialog by remember { mutableStateOf(false) }

    // Helper to run version check
    suspend fun performVersionCheck() {
        val result = navVm.checkForUpdate() ?: return
        updateResult = result
        if (result.status == AppUpdateStatus.OPTIONAL_UPDATE &&
            navVm.shouldShowOptionalUpdate()
        ) {
            showOptionalDialog = true
        }
    }

    // Check for updates on launch
    LaunchedEffect(Unit) {
        performVersionCheck()
    }

    // Re-check on ON_RESUME (hourly, guarded by cache TTL in service)
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                scope.launch { performVersionCheck() }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    // Force Update blocks everything — no way to dismiss
    if (updateResult?.status == AppUpdateStatus.FORCE_UPDATE) {
        ForceUpdateScreen(
            currentVersion = navVm.currentVersionName,
            latestVersion = updateResult?.record?.latestVersion ?: "",
            updateTitle = updateResult?.record?.updateTitle,
            updateMessage = updateResult?.record?.updateMessage,
            storeUrl = updateResult?.record?.updateUrl
        )
        return
    }

    // ── Session expiry detection ──
    // When the Supabase refresh token expires mid-session, navigate to login.
    val isSessionExpired by navVm.sessionManager.isSessionExpired.collectAsState()

    LaunchedEffect(isSessionExpired) {
        if (isSessionExpired) {
            authViewModel.onSessionExpired()
            navVm.sessionManager.clearExpiredFlag()
            navController.navigate("login") {
                popUpTo(0) { inclusive = true }
            }
        }
    }

    // Navigate to new password screen when a recovery deep link is processed
    LaunchedEffect(authState) {
        if (authState is AuthUiState.PasswordRecovery) {
            navController.navigate("new_password") {
                popUpTo(0) { inclusive = true }
            }
        }
    }

    // Determine start destination based on auth state
    val startDestination = when (authState) {
        is AuthUiState.Success -> "main"
        else -> "splash"
    }

    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        // Splash Screen
        composable("splash") {
            SplashScreen(
                onNavigateToHome = {
                    navController.navigate("main") {
                        popUpTo("splash") { inclusive = true }
                    }
                },
                onNavigateToLogin = {
                    navController.navigate("login") {
                        popUpTo("splash") { inclusive = true }
                    }
                },
                onNavigateToOnboarding = {
                    navController.navigate("onboarding") {
                        popUpTo("splash") { inclusive = true }
                    }
                }
            )
        }

        // Onboarding Screen
        composable("onboarding") {
            OnboardingScreen(
                onFinished = {
                    navController.navigate("consent") {
                        popUpTo("onboarding") { inclusive = true }
                    }
                }
            )
        }

        // Consent Screen
        composable("consent") {
            ConsentScreen(
                onAccepted = {
                    scope.launch {
                        navVm.markOnboardingComplete()
                    }
                    navController.navigate("login") {
                        popUpTo("consent") { inclusive = true }
                    }
                }
            )
        }

        // Login Screen
        composable("login") {
            LoginScreen(
                viewModel = authViewModel,
                onNavigateToSignUp = {
                    navController.navigate("signup")
                },
                onNavigateToHome = {
                    navController.navigate("main") {
                        popUpTo("login") { inclusive = true }
                    }
                },
                onNavigateToResetPassword = {
                    navController.navigate("reset_password")
                }
            )
        }

        // Sign Up Screen
        composable("signup") {
            SignUpScreen(
                viewModel = authViewModel,
                onNavigateBack = {
                    navController.popBackStack()
                },
                onNavigateToHome = {
                    navController.navigate("main") {
                        popUpTo("login") { inclusive = true }
                    }
                },
                onNavigateToEmailVerification = {
                    navController.navigate("email_verification") {
                        popUpTo("signup") { inclusive = true }
                    }
                }
            )
        }

        // Email Verification Screen
        composable("email_verification") {
            EmailVerificationScreen(
                viewModel = authViewModel,
                onNavigateToHome = {
                    navController.navigate("main") {
                        popUpTo("login") { inclusive = true }
                    }
                },
                onNavigateBack = {
                    navController.navigate("signup") {
                        popUpTo("email_verification") { inclusive = true }
                    }
                }
            )
        }

        // Reset Password Screen
        composable("reset_password") {
            ResetPasswordScreen(
                viewModel = authViewModel,
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }

        // New Password Screen (after recovery deep link)
        composable("new_password") {
            NewPasswordScreen(
                viewModel = authViewModel,
                onNavigateToHome = {
                    navController.navigate("main") {
                        popUpTo(0) { inclusive = true }
                    }
                }
            )
        }

        // Health Profile Questionnaire
        composable("health_profile") {
            val healthProfileVm: HealthProfileViewModel = hiltViewModel()
            val userId = authState.let {
                (it as? AuthUiState.Success)?.user?.id ?: ""
            }
            HealthProfileScreen(
                userId = userId,
                profileRepository = healthProfileVm.profileRepository,
                onCompleted = {
                    navController.navigate("main") {
                        popUpTo("health_profile") { inclusive = true }
                    }
                }
            )
        }

        // Main App Screen
        composable("main") {
            MainScreen(
                onSignOut = {
                    // Clear session manager first to prevent double-trigger
                    navVm.sessionManager.clearExpiredFlag()
                    authViewModel.signOut()
                    navController.navigate("login") {
                        popUpTo("main") { inclusive = true }
                    }
                },
                deepLinkRoute = deepLinkRoute,
                onDeepLinkConsumed = onDeepLinkConsumed
            )
        }

        // AR Body Scan Screen (Feature 16)
        composable("ar_body_scan") {
            ARBodyScanScreen(
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }
    }

    // Deep link processing overlay
    if (isProcessingDeepLink) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.5f)),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(
                color = MaterialTheme.colorScheme.primary
            )
        }
    }

    // Optional Update Dialog overlay (Feature 18)
    if (showOptionalDialog && updateResult != null) {
        OptionalUpdateDialog(
            newVersion = updateResult?.record?.latestVersion ?: "",
            updateTitle = updateResult?.record?.updateTitle,
            updateMessage = updateResult?.record?.updateMessage,
            storeUrl = updateResult?.record?.updateUrl,
            onDismiss = {
                showOptionalDialog = false
                navVm.dismissOptionalUpdate()
            }
        )
    }
}
