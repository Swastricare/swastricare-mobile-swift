package com.swasthicare.mobile.ui.navigation

import androidx.compose.runtime.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.swasthicare.mobile.data.services.AppUpdateStatus
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.ui.screens.ar.ARBodyScanScreen
import com.swasthicare.mobile.ui.screens.auth.AuthUiState
import com.swasthicare.mobile.ui.screens.auth.AuthViewModel
import com.swasthicare.mobile.ui.screens.auth.LoginScreen
import com.swasthicare.mobile.ui.screens.auth.ResetPasswordScreen
import com.swasthicare.mobile.ui.screens.auth.SignUpScreen
import com.swasthicare.mobile.ui.screens.main.MainScreen
import com.swasthicare.mobile.ui.screens.splash.SplashScreen
import com.swasthicare.mobile.ui.screens.update.ForceUpdateScreen
import com.swasthicare.mobile.ui.screens.update.OptionalUpdateDialog
import kotlinx.coroutines.launch

/**
 * App Navigation with Authentication and Version Checking
 * Matches iOS navigation flow:
 * Splash -> ForceUpdate? -> Login -> Main
 */
@Composable
fun AppNavigation(authViewModel: AuthViewModel) {
    val navController = rememberNavController()
    val authState by authViewModel.uiState.collectAsState()
    val lifecycleOwner = LocalLifecycleOwner.current
    val coroutineScope = rememberCoroutineScope()

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
                coroutineScope.launch {
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
        ForceUpdateScreen(
            currentVersion = AppContainer.currentVersionName,
            requiredVersion = updateVersion,
            releaseNotes = updateReleaseNotes,
            storeUrl = updateStoreUrl
        )
        return
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

        // Main App Screen
        composable("main") {
            MainScreen(
                onSignOut = {
                    // Sign out from AuthViewModel
                    authViewModel.signOut()
                    // Navigate back to login
                    navController.navigate("login") {
                        popUpTo("main") { inclusive = true }
                    }
                }
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
