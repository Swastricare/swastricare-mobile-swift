package com.swasthicare.mobile.ui.screens.main

import androidx.compose.foundation.layout.padding
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
fun MainScreen() {
    val navController = rememberNavController()
    val haptic = LocalHapticFeedback.current
    
    val items = listOf(
        MainTab.Vitals,
        MainTab.AI,
        MainTab.Vault,
        MainTab.Profile
    )

    Scaffold(
        bottomBar = {
            // Semi-transparent navigation bar to mimic glass effect
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f),
                tonalElevation = 0.dp,
            ) {
                val navBackStackEntry by navController.currentBackStackEntryAsState()
                val currentDestination = navBackStackEntry?.destination
                
                items.forEach { screen ->
                    val isSelected = currentDestination?.hierarchy?.any { it.route == screen.route } == true
                    
                    NavigationBarItem(
                        icon = { 
                            Icon(
                                imageVector = if (isSelected) screen.selectedIcon else screen.unselectedIcon,
                                contentDescription = screen.title
                            ) 
                        },
                        label = { 
                            Text(
                                text = screen.title,
                                fontWeight = if (isSelected) FontWeight.Medium else FontWeight.Normal,
                                fontSize = 12.sp
                            ) 
                        },
                        selected = isSelected,
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MaterialTheme.colorScheme.primary,
                            selectedTextColor = MaterialTheme.colorScheme.primary,
                            indicatorColor = Color.Transparent,
                            unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant
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
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = MainTab.Vitals.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(MainTab.Vitals.route) { HomeScreen() }
            composable(MainTab.AI.route) { AIScreen() }
            composable(MainTab.Vault.route) { VaultScreen() }
            composable(MainTab.Profile.route) { ProfileScreen() }
        }
    }
}
