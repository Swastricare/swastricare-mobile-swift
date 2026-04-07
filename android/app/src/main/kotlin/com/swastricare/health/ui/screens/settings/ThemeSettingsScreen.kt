package com.swastricare.health.ui.screens.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.ThemeMode
import com.swastricare.health.ui.theme.ThemePreferenceManager
import com.swastricare.health.ui.components.TrackScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThemeSettingsScreen(
    themePreferenceManager: ThemePreferenceManager,
    onNavigateBack: () -> Unit
) {
    TrackScreen("ThemeSettings")
    val currentTheme by themePreferenceManager.themeMode.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Theme", fontWeight = FontWeight.SemiBold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = AppColors.onBackground,
                    navigationIconContentColor = AppColors.onBackground
                ),
                windowInsets = WindowInsets(0, 0, 0, 0)
            )
        },
        containerColor = Color.Transparent
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(bottom = 24.dp)
        ) {
            item { SettingsSectionHeader("Appearance") }
            item {
                SettingsSectionCard {
                    ThemeMode.entries.forEachIndexed { index, mode ->
                        if (index > 0) SettingsCleanDivider()
                        Row(
                            modifier = Modifier.fillMaxWidth()
                                .clickable { themePreferenceManager.setTheme(mode) }
                                .padding(vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(mode.displayName, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = AppColors.onBackground)
                                Text(mode.description, fontSize = 12.sp, color = AppColors.onBackground.copy(alpha = 0.45f))
                            }
                            RadioButton(
                                selected = mode == currentTheme,
                                onClick = { themePreferenceManager.setTheme(mode) },
                                colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF22C55E))
                            )
                        }
                    }
                }
            }

            item {
                Text(
                    "Auto mode switches between light and dark based on time of day (light 6 AM – 6 PM).",
                    fontSize = 12.sp,
                    color = AppColors.onBackground.copy(alpha = 0.4f),
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp)
                )
            }
        }
    }
}
