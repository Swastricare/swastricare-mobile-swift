package com.swastricare.health.ui.screens.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor
import com.swastricare.health.ui.theme.ThemeMode
import com.swastricare.health.ui.theme.ThemePreferenceManager

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThemeSettingsScreen(
    themePreferenceManager: ThemePreferenceManager,
    onNavigateBack: () -> Unit
) {
    val currentTheme by themePreferenceManager.themeMode.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Theme") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = AppColors.background,
                    titleContentColor = AppColors.onBackground,
                    navigationIconContentColor = AppColors.onBackground
                )
            )
        }
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize()) {
            PremiumBackground()

            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                items(ThemeMode.entries.toList()) { mode ->
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        shape = MaterialTheme.shapes.medium,
                        color = if (mode == currentTheme)
                            PrimaryColor.copy(alpha = 0.1f)
                        else
                            AppColors.surface,
                        tonalElevation = 2.dp
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { themePreferenceManager.setTheme(mode) }
                                .padding(horizontal = 16.dp, vertical = 16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = mode.displayName,
                                    style = MaterialTheme.typography.bodyLarge,
                                    fontWeight = FontWeight.Medium,
                                    color = AppColors.onSurface
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = mode.description,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = AppColors.onSurfaceVariant
                                )
                            }

                            RadioButton(
                                selected = mode == currentTheme,
                                onClick = { themePreferenceManager.setTheme(mode) },
                                colors = RadioButtonDefaults.colors(
                                    selectedColor = PrimaryColor
                                )
                            )
                        }
                    }
                }

                item {
                    Text(
                        text = "Auto mode switches between light and dark based on time of day (light 6 AM – 6 PM).",
                        style = MaterialTheme.typography.bodySmall,
                        color = AppColors.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
                    )
                }
            }
        }
    }
}
