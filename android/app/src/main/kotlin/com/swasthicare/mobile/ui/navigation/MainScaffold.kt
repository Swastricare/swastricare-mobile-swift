package com.swasthicare.mobile.ui.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.DirectionsRun
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import androidx.navigation.compose.currentBackStackEntryAsState

/**
 * Reusable main scaffold with bottom navigation bar.
 * Handles visibility of bottom nav based on current route.
 *
 * @param navController The navigation controller
 * @param showBottomNav Whether to show the bottom navigation bar
 * @param modifier Modifier for the scaffold
 * @param content The main content composable
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
                MainBottomNavigation(
                    navController = navController,
                    currentRoute = currentRoute
                )
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentAlignment = Alignment.TopCenter
        ) {
            // Pass modifier to content so screens can use fillMaxSize()
            // without double-padding - the innerPadding is already applied here
            content(Modifier.fillMaxSize())
        }
    }
}

/**
 * Main bottom navigation bar with 5 tabs.
 */
@Composable
private fun MainBottomNavigation(
    navController: NavController,
    currentRoute: String?
) {
    NavigationBar(modifier = Modifier.height(80.dp)) {
        BottomNavTab.items.forEach { tab ->
            val selected = currentRoute == tab.route

            NavigationBarItem(
                selected = selected,
                onClick = {
                    if (currentRoute != tab.route) {
                        navController.navigate(tab.route) {
                            // Pop up to the start destination of the graph to
                            // avoid building up a large stack of destinations
                            popUpTo(navController.graph.startDestinationId) {
                                saveState = true
                            }
                            // Avoid multiple copies of the same destination when
                            // reselecting the same item
                            launchSingleTop = true
                            // Restore state when reselecting a previously selected item
                            restoreState = true
                        }
                    }
                },
                icon = {
                    Icon(
                        imageVector = getIconForTab(tab, selected),
                        contentDescription = tab.title
                    )
                },
                label = { Text(tab.title) }
            )
        }
    }
}

@Composable
private fun getIconForTab(tab: BottomNavTab, selected: Boolean): ImageVector {
    return when (tab) {
        BottomNavTab.Vitals -> if (selected) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder
        BottomNavTab.Vault -> if (selected) Icons.Filled.Lock else Icons.Outlined.Lock
        BottomNavTab.AI -> if (selected) Icons.Filled.AutoAwesome else Icons.Outlined.AutoAwesome
        BottomNavTab.Steps -> if (selected) Icons.Filled.DirectionsRun else Icons.Outlined.DirectionsRun
        BottomNavTab.Profile -> if (selected) Icons.Filled.Person else Icons.Outlined.Person
    }
}
