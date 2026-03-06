package com.swasthicare.mobile.ui.screens.main

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.swasthicare.mobile.di.AppContainer
import com.swasthicare.mobile.navigation.DeepLinkHandler
import com.swasthicare.mobile.navigation.DeepLinkRoute
import com.swasthicare.mobile.ui.navigation.BottomNavConfig
import com.swasthicare.mobile.ui.navigation.BottomNavTab
import com.swasthicare.mobile.ui.navigation.MainNavGraph
import com.swasthicare.mobile.ui.navigation.MainScaffold
import com.swasthicare.mobile.ui.screens.profile.ProfileViewModel

/**
 * Main screen with bottom navigation.
 *
 * Architecture:
 * - Scaffold with NavigationBar (hidden on full-screen routes)
 * - NavHost containing all tab screens and nested screens
 * - Deep linking support for both tabs and nested routes
 *
 * The key to proper padding:
 * - MainScaffold applies innerPadding from Scaffold to the content Box
 * - NavHost modifier is set to fillMaxSize() so all screens naturally fill the available space
 * - Individual screens use fillMaxSize() without extra padding - they occupy exactly what's left
 */
@Composable
fun MainScreen(
    onSignOut: () -> Unit = {},
    deepLinkRoute: DeepLinkRoute? = null,
    onDeepLinkConsumed: () -> Unit = {}
) {
    val navController = rememberNavController()

    // Shared ProfileViewModel scoped to MainScreen so Profile and EditProfile share state
    val profileViewModel: ProfileViewModel = viewModel()

    // Track current route for analytics and bottom nav visibility
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    // Determine if bottom nav should be visible
    val showBottomNav = remember(currentRoute) {
        BottomNavConfig.shouldShowBottomNav(currentRoute)
    }

    // Tab items for deep link handling
    val tabItems = remember { BottomNavTab.items }

    // Handle deep link navigation
    LaunchedEffect(deepLinkRoute) {
        if (deepLinkRoute != null) {
            val navRoute = DeepLinkHandler.toNavRoute(deepLinkRoute)

            // Check if it's a tab route or a nested screen route
            val isTabRoute = tabItems.any { it.route == navRoute }
            if (isTabRoute) {
                navController.navigate(navRoute) {
                    popUpTo(navController.graph.findStartDestination().id) {
                        saveState = true
                    }
                    launchSingleTop = true
                    restoreState = true
                }
            } else {
                navController.navigate(navRoute) {
                    launchSingleTop = true
                }
            }
            onDeepLinkConsumed()
        }
    }

    // Track screen views when route changes
    LaunchedEffect(currentRoute) {
        if (currentRoute != null) {
            val screenName = tabItems.firstOrNull { it.route == currentRoute }?.title ?: currentRoute
            AppContainer.firebaseAnalyticsService.logScreenView(screenName)
            AppContainer.appAnalyticsService.trackScreenView(screenName)
        }
    }

    // Main scaffold with bottom navigation
    MainScaffold(
        navController = navController,
        showBottomNav = showBottomNav
    ) { modifier ->
        MainNavGraph(
            navController = navController,
            modifier = modifier,
            profileViewModel = profileViewModel,
            onSignOut = onSignOut
        )
    }
}
