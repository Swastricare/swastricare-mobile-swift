package com.swasthicare.mobile.ui.screens.main

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarDefaults
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.swasthicare.mobile.ui.screens.ai.AIScreen
import com.swasthicare.mobile.ui.screens.home.HomeScreen
import com.swasthicare.mobile.ui.screens.home.glass
import com.swasthicare.mobile.ui.screens.profile.ProfileScreen
import com.swasthicare.mobile.ui.screens.vault.VaultScreen

sealed class MainTab(
    val route: String, 
    val title: String, 
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
) {
    object Vitals : MainTab(
        route = "vitals", 
        title = "Vitals", 
        selectedIcon = Icons.Filled.Favorite,
        unselectedIcon = Icons.Outlined.FavoriteBorder
    )
    object AI : MainTab(
        route = "ai", 
        title = "AI", 
        selectedIcon = Icons.Filled.AutoAwesome,
        unselectedIcon = Icons.Outlined.AutoAwesome
    )
    object Vault : MainTab(
        route = "vault", 
        title = "Vault", 
        selectedIcon = Icons.Filled.Lock,
        unselectedIcon = Icons.Outlined.Lock
    )
    object Profile : MainTab(
        route = "profile", 
        title = "Profile", 
        selectedIcon = Icons.Filled.Person,
        unselectedIcon = Icons.Outlined.Person
    )
}

@Composable
fun MainScreen(
    onSignOut: () -> Unit = {}
) {
    val navController = rememberNavController()
    val haptic = LocalHapticFeedback.current
    
    val items = listOf(
        MainTab.Vitals,
        MainTab.AI,
        MainTab.Vault,
        MainTab.Profile
    )

    Scaffold(
        containerColor = Color.Transparent, // Let the background show through
        bottomBar = {
            // Floating Glass Navigation Bar
            Box(
                modifier = Modifier
                    .padding(horizontal = 20.dp, vertical = 20.dp)
                    .glass(cornerRadius = 32.dp, opacity = 0.8f) // Use our glass modifier
            ) {
                NavigationBar(
                    containerColor = Color.Transparent,
                    tonalElevation = 0.dp,
                    windowInsets = NavigationBarDefaults.windowInsets,
                    modifier = Modifier.height(70.dp) // Slightly taller for floating look
                ) {
                    val navBackStackEntry by navController.currentBackStackEntryAsState()
                    val currentDestination = navBackStackEntry?.destination
                    
                    items.forEach { screen ->
                        val isSelected = currentDestination?.hierarchy?.any { it.route == screen.route } == true
                        val selectedColor = MaterialTheme.colorScheme.primary
                        val unselectedColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                        
                        NavigationBarItem(
                            icon = { 
                                Icon(
                                    imageVector = if (isSelected) screen.selectedIcon else screen.unselectedIcon,
                                    contentDescription = screen.title,
                                    modifier = Modifier.size(24.dp)
                                ) 
                            },
                            label = null, // Remove labels for cleaner "Apple-like" look
                            selected = isSelected,
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = selectedColor,
                                selectedTextColor = selectedColor,
                                indicatorColor = selectedColor.copy(alpha = 0.1f),
                                unselectedIconColor = unselectedColor,
                                unselectedTextColor = unselectedColor
                            ),
                            onClick = {
                                if (currentDestination?.route != screen.route) {
                                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                }
                                
                                navController.navigate(screen.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        )
                    }
                }
            }
        }
    ) { innerPadding ->
        // We want content to go behind the floating bar, so we ignore bottom padding mostly
        // but we add a spacer at the bottom of screens instead (already added in HomeScreen)
        NavHost(
            navController = navController,
            startDestination = MainTab.Vitals.route,
            modifier = Modifier.fillMaxSize() // Fill entire screen including behind bar
        ) {
            composable(MainTab.Vitals.route) { HomeScreen() }
            composable(MainTab.AI.route) { AIScreen() }
            composable(MainTab.Vault.route) { VaultScreen() }
            composable(MainTab.Profile.route) { 
                ProfileScreen(
                    onSignOut = onSignOut
                )
            }
        }
    }
}
