package com.swasthicare.mobile.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.swasthicare.mobile.ui.screens.auth.AuthUiState
import com.swasthicare.mobile.ui.screens.auth.AuthViewModel
import com.swasthicare.mobile.ui.screens.auth.LoginScreen
import com.swasthicare.mobile.ui.screens.auth.ResetPasswordScreen
import com.swasthicare.mobile.ui.screens.auth.SignUpScreen
import com.swasthicare.mobile.ui.screens.main.MainScreen
import com.swasthicare.mobile.ui.screens.splash.SplashScreen

/**
 * App Navigation with Authentication
 * Matches iOS navigation flow
 */
@Composable
fun AppNavigation(authViewModel: AuthViewModel) {
    val navController = rememberNavController()
    val authState by authViewModel.uiState.collectAsState()
    
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
    }
}
