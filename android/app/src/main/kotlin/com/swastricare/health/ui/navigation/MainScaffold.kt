package com.swastricare.health.ui.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.navigation.NavController
import androidx.navigation.compose.currentBackStackEntryAsState

/**
 * Main scaffold with a floating capsule bottom navigation bar.
 *
 * The nav bar is rendered as a Box overlay — content fills the full screen
 * and is never pushed up by the nav bar height.
 */
@Composable
fun MainScaffold(
    navController: NavController,
    showBottomNav: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable (Modifier) -> Unit
) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    Scaffold(modifier = modifier) { innerPadding ->
        val density = LocalDensity.current
        val isKeyboardVisible = WindowInsets.ime.getBottom(density) > 0

        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = innerPadding.calculateTopPadding())
        ) {
            // Content fills the full Box — no bottom padding reserved for nav bar
            content(Modifier.fillMaxSize())

            // Floating capsule nav bar overlays content at the bottom
            // Hidden when keyboard is open to avoid double-obscuring input fields
            AnimatedVisibility(
                visible = showBottomNav && !isKeyboardVisible,
                enter = slideInVertically(initialOffsetY = { it }),
                exit = slideOutVertically(targetOffsetY = { it }),
                modifier = Modifier.align(Alignment.BottomCenter)
            ) {
                SwastriCareNavBar(
                    navController = navController,
                    currentRoute = currentRoute
                )
            }
        }
    }
}
