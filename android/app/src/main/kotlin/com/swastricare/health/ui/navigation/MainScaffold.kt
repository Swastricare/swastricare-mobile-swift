package com.swastricare.health.ui.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import androidx.navigation.compose.currentBackStackEntryAsState

/** Intrinsic height of [SwastriCareNavBarV2] (excl. system nav-bar inset). */
private val NAV_BAR_CONTENT_HEIGHT = 56.dp

/**
 * The chrome around the 5 bottom-nav tabs.
 *
 * Because this composable now hosts *only* the 5 tab destinations — nested
 * routes live at the top-level [AppNavigation] graph and aren't inside
 * this scaffold at all — the bar is simply always visible here. The only
 * legitimate reasons to hide it are:
 *
 *   • AI chat full-screen — animated slide down / up.
 *   • IME (keyboard) visible — keep out of the input's way.
 *
 * The bar is drawn as an overlay (BottomCenter) rather than in Scaffold's
 * `bottomBar` slot so that AI/keyboard toggles don't change the content's
 * measured size.
 */
@Composable
fun MainScaffold(
    navController: NavController,
    aiFullScreen: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable (Modifier) -> Unit
) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route
    val density = LocalDensity.current

    val keyboardVisible = WindowInsets.ime.getBottom(density) > 0
    val barVisible = !aiFullScreen && !keyboardVisible
    val systemNavInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    // Bottom reservation for the tab content. Three cases:
    //   • Bar visible   → leave room for the bar + the system-nav gesture inset.
    //   • Keyboard up   → 0; the child's `imePadding()` already keeps content
    //                     above the IME (which subsumes the gesture inset).
    //   • Bar hidden,
    //     keyboard down → only the gesture inset, so the content (e.g. AI
    //                     input bar) doesn't sit under the gesture handle.
    val targetReservation = when {
        barVisible -> NAV_BAR_CONTENT_HEIGHT + systemNavInset
        keyboardVisible -> 0.dp
        else -> systemNavInset
    }
    val bottomReservation by animateDpAsState(
        targetValue = targetReservation,
        animationSpec = tween(durationMillis = 260),
        label = "navBarReservation"
    )

    // Horizontal system insets only — the bottom nav bar's background
    // extends down into the gesture area (so there's no dead space below
    // it), while the bar's own `windowInsetsPadding` keeps the icons
    // above the gesture zone.
    Scaffold(
        modifier = modifier,
        containerColor = Color.White,
        contentWindowInsets = WindowInsets.systemBars.only(WindowInsetsSides.Horizontal)
    ) { innerPadding ->
        Box(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            // Single source of truth for top + bottom tab-chrome padding:
            // every tab sits below the status bar and above the nav bar.
            // Individual screens should NOT re-apply statusBarsPadding.
            content(
                Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .padding(bottom = bottomReservation)
            )

            AnimatedVisibility(
                visible = barVisible,
                modifier = Modifier.align(Alignment.BottomCenter),
                enter = slideInVertically(
                    animationSpec = tween(durationMillis = 260),
                    initialOffsetY = { fullHeight -> fullHeight }
                ) + fadeIn(tween(220)),
                exit = slideOutVertically(
                    animationSpec = tween(durationMillis = 260),
                    targetOffsetY = { fullHeight -> fullHeight }
                ) + fadeOut(tween(200))
            ) {
                SwastriCareNavBarV2(
                    navController = navController,
                    currentRoute = currentRoute
                )
            }
        }
    }
}
