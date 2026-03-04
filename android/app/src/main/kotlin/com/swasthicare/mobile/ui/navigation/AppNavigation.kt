package com.swasthicare.mobile.ui.navigation

import androidx.compose.runtime.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.datastore.preferences.core.edit
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.swasthicare.mobile.data.services.AppUpdateStatus
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.di.CONSENT_ACCEPTED_KEY
import com.swasthicare.mobile.di.ONBOARDING_COMPLETE_KEY
import com.swasthicare.mobile.navigation.DeepLinkHandler
import com.swasthicare.mobile.navigation.DeepLinkRoute
import com.swasthicare.mobile.ui.screens.ar.ARBodyScanScreen
import com.swasthicare.mobile.ui.screens.auth.AuthUiState
import com.swasthicare.mobile.ui.screens.auth.AuthViewModel
import com.swasthicare.mobile.ui.screens.auth.LoginScreen
import com.swasthicare.mobile.ui.screens.auth.ResetPasswordScreen
import com.swasthicare.mobile.ui.screens.auth.SignUpScreen
import com.swasthicare.mobile.ui.screens.main.MainScreen
import com.swasthicare.mobile.ui.screens.onboarding.ConsentScreen
import com.swasthicare.mobile.ui.screens.onboarding.HealthProfileScreen
import com.swasthicare.mobile.ui.screens.onboarding.OnboardingScreen
import com.swasthicare.mobile.ui.screens.splash.ForceUpdateScreen
import com.swasthicare.mobile.ui.screens.splash.SplashScreen
import com.swasthicare.mobile.ui.screens.update.ForceUpdateScreen as UpdateForceUpdateScreen
import com.swasthicare.mobile.ui.screens.update.OptionalUpdateDialog
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
    val navController = rememberNavController()
    val authState by authViewModel.uiState.collectAsState()
    val scope = rememberCoroutineScope()
    val lifecycleOwner = LocalLifecycleOwner.current

    // Version check state (Feature 18)
    var updateStatus by remember { mutableStateOf(AppUpdateStatus.UP_TO_DATE) }
    var updateVersion by remember { mutableStateOf("") }
    var updateReleaseNotes by remember { mutableStateOf<String?>(null) }
    var updateStoreUrl by remember { mutableStateOf<String?>(null) }
    var showOptionalDialog by remember { mutableStateOf(false) }

    // Check for updates on launch
    LaunchedEffect(Unit) {
        try {
            val result = AppContainer.appVersionService.checkForUpdate(AppContainer.currentVersionName)
            updateStatus = result.status
            result.versionInfo?.let { info ->
                updateVersion = info.version
                updateReleaseNotes = info.releaseNotes
                updateStoreUrl = info.storeUrl
            }
            if (result.status == AppUpdateStatus.OPTIONAL_UPDATE &&
                AppContainer.appVersionService.shouldShowOptionalUpdate()
            ) {
                showOptionalDialog = true
            }
        } catch (e: Exception) {
            // Version check failure should not block the app
        }
    }

    // Re-check on ON_RESUME (hourly, guarded by cache TTL in service)
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                scope.launch {
                    try {
                        val result = AppContainer.appVersionService.checkForUpdate(
                            AppContainer.currentVersionName
                        )
                        updateStatus = result.status
                        result.versionInfo?.let { info ->
                            updateVersion = info.version
                            updateReleaseNotes = info.releaseNotes
                            updateStoreUrl = info.storeUrl
                        }
                        if (result.status == AppUpdateStatus.OPTIONAL_UPDATE &&
                            AppContainer.appVersionService.shouldShowOptionalUpdate()
                        ) {
                            showOptionalDialog = true
                        }
                    } catch (_: Exception) { }
                }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    // Force Update blocks everything
    if (updateStatus == AppUpdateStatus.FORCE_UPDATE) {
        UpdateForceUpdateScreen(
            currentVersion = AppContainer.currentVersionName,
            requiredVersion = updateVersion,
            releaseNotes = updateReleaseNotes,
            storeUrl = updateStoreUrl
        )
        return
    }

    // ── Session expiry detection ──
    // When the Supabase refresh token expires mid-session, navigate to login.
    val isSessionExpired by AppContainer.sessionManager.isSessionExpired.collectAsState()

    LaunchedEffect(isSessionExpired) {
        if (isSessionExpired) {
            authViewModel.onSessionExpired()
            AppContainer.sessionManager.clearExpiredFlag()
            navController.navigate("login") {
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
                },
                onForceUpdate = {
                    navController.navigate("force_update") {
                        popUpTo("splash") { inclusive = true }
                    }
                }
            )
        }

        // Force Update Screen
        composable("force_update") {
            ForceUpdateScreen()
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
                        AppContainer.dataStore.edit { it[CONSENT_ACCEPTED_KEY] = true }
                        AppContainer.dataStore.edit { it[ONBOARDING_COMPLETE_KEY] = true }
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

        // Health Profile Questionnaire
        composable("health_profile") {
            val userId = authViewModel.uiState.value.let {
                (it as? AuthUiState.Success)?.user?.id ?: ""
            }
            HealthProfileScreen(
                userId = userId,
                profileRepository = AppContainer.profileRepository,
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
                    AppContainer.sessionManager.clearExpiredFlag()
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

    // Optional Update Dialog overlay (Feature 18)
    if (showOptionalDialog) {
        OptionalUpdateDialog(
            newVersion = updateVersion,
            releaseNotes = updateReleaseNotes,
            storeUrl = updateStoreUrl,
            onDismiss = {
                showOptionalDialog = false
                AppContainer.appVersionService.dismissOptionalUpdate()
            }
        )
    }
}
