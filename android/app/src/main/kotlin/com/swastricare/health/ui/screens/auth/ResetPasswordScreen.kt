package com.swastricare.health.ui.screens.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.auth.components.*

@Composable
fun ResetPasswordScreen(
    viewModel: AuthViewModel,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    TrackScreen("ResetPassword")
    val formState by viewModel.formState.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    var emailFocused by remember { mutableStateOf(false) }
    val isDark = isSystemInDarkTheme()

    Scaffold(
        containerColor = Color.Transparent
    ) { paddingValues ->
        Box(modifier = modifier.fillMaxSize().padding(paddingValues)) {
            AuthGradientBackground()

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .imePadding(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {

                // Lock icon in teal circle (matching iOS)
                Box(
                    modifier = Modifier.size(64.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        modifier = Modifier
                            .size(64.dp)
                            .background(
                                color = PremiumColors.Teal.copy(alpha = 0.12f),
                                shape = CircleShape
                            )
                    )
                    Icon(
                        imageVector = Icons.Default.Lock,
                        contentDescription = null,
                        tint = PremiumColors.Teal,
                        modifier = Modifier.size(28.dp)
                    )
                }

                Spacer(modifier = Modifier.height(14.dp))

                // Header
                Text(
                    "Reset Password",
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onBackground
                )

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    "Enter your email and we'll send you a reset link",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 40.dp)
                )

                Spacer(modifier = Modifier.height(28.dp))

                // Form card
                GlassCard(modifier = Modifier.padding(horizontal = 20.dp)) {
                    Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
                        PremiumTextField(
                            value = formState.email,
                            onValueChange = { viewModel.updateEmail(it) },
                            placeholder = "Email",
                            icon = Icons.Default.Email,
                            keyboardType = KeyboardType.Email,
                            imeAction = ImeAction.Done,
                            isFocused = emailFocused,
                            modifier = Modifier.onFocusChanged { emailFocused = it.isFocused }
                        )

                        // Error/Success banner
                        if (errorMessage != null) {
                            val isSuccess = errorMessage?.contains("sent", ignoreCase = true) == true
                            AuthAlertBanner(
                                message = errorMessage ?: "",
                                isSuccess = isSuccess
                            )
                        }

                        PremiumButton(
                            "Send Reset Link",
                            onClick = { viewModel.resetPassword() },
                            enabled = formState.isValidEmail && !isLoading,
                            isLoading = isLoading
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))

                // Footer
                Row(
                    horizontalArrangement = Arrangement.Center,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        "Remember your password? ",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "Sign In",
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                        color = PremiumColors.Teal,
                        modifier = Modifier.clickable { onNavigateBack() }
                    )
                }

                Spacer(modifier = Modifier.height(30.dp))
            }

            // Back button - circular glass style
            IconButton(
                onClick = onNavigateBack,
                modifier = Modifier
                    .padding(16.dp)
                    .align(Alignment.TopStart)
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(
                        color = if (isDark) Color.White.copy(alpha = 0.06f) else Color.Black.copy(alpha = 0.035f),
                        shape = CircleShape
                    )
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        }
    }

