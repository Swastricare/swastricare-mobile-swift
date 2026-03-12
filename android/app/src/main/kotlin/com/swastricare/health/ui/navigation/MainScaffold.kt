package com.swastricare.health.ui.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import androidx.navigation.compose.currentBackStackEntryAsState

/**
 * Main scaffold with the custom SwastriCare bottom navigation bar.
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

    Scaffold(
        modifier = modifier,
        bottomBar = {
            AnimatedVisibility(
                visible = showBottomNav,
                enter = slideInVertically(initialOffsetY = { it }),
                exit = slideOutVertically(targetOffsetY = { it })
            ) {
                SwastriCareNavBar(
                    navController = navController,
                    currentRoute = currentRoute
                )
            }
        }
    ) { innerPadding ->
        val density = LocalDensity.current
        val isKeyboardVisible = WindowInsets.ime.getBottom(density) > 0

        // When keyboard is open, drop the bottom padding (nav bar area) so
        // screens using imePadding() don't get double-padded.
        val adjustedPadding = if (isKeyboardVisible) {
            PaddingValues(
                top = innerPadding.calculateTopPadding(),
                bottom = 0.dp
            )
        } else {
            innerPadding
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(adjustedPadding),
            contentAlignment = Alignment.TopCenter
        ) {
            content(Modifier.fillMaxSize())
        }
    }
}
