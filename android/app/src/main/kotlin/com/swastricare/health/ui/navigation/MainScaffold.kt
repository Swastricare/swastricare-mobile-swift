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

@Composable
fun MainScaffold(
    navController: NavController,
    showBottomNav: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable (Modifier) -> Unit
) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route
    val density = LocalDensity.current

    // ── V2: normal bottom bar (pushes content up) ──
    Scaffold(
        modifier = modifier,
        bottomBar = {
            AnimatedVisibility(
                visible = showBottomNav && WindowInsets.ime.getBottom(density) == 0,
                enter = slideInVertically(initialOffsetY = { it }),
                exit = slideOutVertically(targetOffsetY = { it }),
            ) {
                SwastriCareNavBarV2(
                    navController = navController,
                    currentRoute = currentRoute
                )
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            content(Modifier.fillMaxSize())
        }
    }

    // ── V1: floating capsule bar (overlay, does not push content) ──
    // Scaffold(modifier = modifier) { innerPadding ->
    //     val isKeyboardVisible = WindowInsets.ime.getBottom(density) > 0
    //     Box(
    //         modifier = Modifier
    //             .fillMaxSize()
    //             .padding(top = innerPadding.calculateTopPadding())
    //     ) {
    //         content(Modifier.fillMaxSize())
    //         AnimatedVisibility(
    //             visible = showBottomNav && !isKeyboardVisible,
    //             enter = slideInVertically(initialOffsetY = { it }),
    //             exit = slideOutVertically(targetOffsetY = { it }),
    //             modifier = Modifier.align(Alignment.BottomCenter)
    //         ) {
    //             SwastriCareNavBar(navController = navController, currentRoute = currentRoute)
    //         }
    //     }
    // }
}
