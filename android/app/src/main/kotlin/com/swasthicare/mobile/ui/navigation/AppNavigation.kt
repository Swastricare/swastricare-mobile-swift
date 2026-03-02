package com.swasthicare.mobile.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.datastore.preferences.core.edit
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.di.CONSENT_ACCEPTED_KEY
import com.swasthicare.mobile.di.ONBOARDING_COMPLETE_KEY
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
import kotlinx.coroutines.launch

/**
 * App Navigation with Authentication
 * Matches iOS navigation state machine:
 * Splash -> ForceUpdate? -> Onboarding -> Consent -> Login -> HealthProfile? -> Main
 */
@Composable
fun AppNavigation(authViewModel: AuthViewModel) {
    val navController = rememberNavController()
    val authState by authViewModel.uiState.collectAsState()
    val scope = rememberCoroutineScope()

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
                    authViewModel.signOut()
                    navController.navigate("login") {
                        popUpTo("main") { inclusive = true }
                    }
                }
            )
        }
    }
}
