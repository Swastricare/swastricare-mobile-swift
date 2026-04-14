package com.swastricare.health.ui.navigation

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor

private val CapsuleShape = RoundedCornerShape(50)

@Composable
fun SwastriCareNavBar(
    navController: NavController,
    currentRoute: String?
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(start = 16.dp, end = 16.dp, bottom = 12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp)
                .shadow(elevation = 38.dp, shape = CapsuleShape)
                .background(AppColors.navBar, shape = CapsuleShape),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            BottomNavTab.items.forEach { tab ->
                val selected = currentRoute == tab.route
                val onClick = remember(tab.route, currentRoute) {
                    {
                        if (currentRoute != tab.route) {
                            navController.navigate(tab.route) {
                                popUpTo(navController.graph.startDestinationId) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    }
                }
                NavBarTabItem(
                    tab = tab,
                    selected = selected,
                    modifier = Modifier.weight(1f),
                    onClick = onClick
                )
            }
        }
    }
}

@Composable
private fun NavBarTabItem(
    tab: BottomNavTab,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val hapticFeedback = LocalHapticFeedback.current
    val isDark = isSystemInDarkTheme()

    // Pill background: primary in light, white in dark
    val pillColor = if (isDark) Color.White else PrimaryColor
    // Icon on pill: white in light, dark in dark
    val selectedIconTint = if (isDark) Color(0xFF1C1C1E) else Color.White
    // Unselected tint: muted in both themes
    val unselectedTint by animateColorAsState(
        targetValue = AppColors.onSurfaceVariant,
        animationSpec = tween(durationMillis = 250),
        label = "unselectedTint"
    )

    Column(
        modifier = modifier
            .semantics {
                role = Role.Tab
                this.selected = selected
            }
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = {
                    hapticFeedback.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    onClick()
                }
            )
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Pill bubble behind selected icon
        Box(
            modifier = if (selected) {
                Modifier
                    .clip(CapsuleShape)
                    .background(pillColor)
                    .padding(horizontal = 16.dp, vertical = 5.dp)
            } else {
                Modifier.padding(horizontal = 16.dp, vertical = 5.dp)
            },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = tab.icon,
                contentDescription = tab.title,
                tint = if (selected) selectedIconTint else unselectedTint,
                modifier = Modifier.size(18.dp)
            )
        }
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = tab.title,
            fontSize = 10.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) pillColor else unselectedTint,
            maxLines = 1
        )
    }
}
