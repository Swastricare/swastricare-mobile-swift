package com.swastricare.health.ui.screens.auth

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Email
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.auth.components.AuthGradientBackground
import com.swastricare.health.ui.screens.auth.components.PremiumButton
import com.swastricare.health.ui.screens.auth.components.PremiumButtonStyle
import com.swastricare.health.ui.screens.auth.components.PremiumColors
import kotlinx.coroutines.delay

@Composable
fun EmailVerificationScreen(
    viewModel: AuthViewModel,
    onNavigateToHome: () -> Unit,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    TrackScreen("EmailVerification")
    val context = LocalContext.current
    val uiState by viewModel.uiState.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val verificationEmail by viewModel.verificationEmail.collectAsState()

    var resendCooldown by remember { mutableIntStateOf(0) }
    var showSuccess by remember { mutableStateOf(false) }

    val snackbarHostState = remember { SnackbarHostState() }
    val isDark = isSystemInDarkTheme()

    // Resend cooldown timer
    LaunchedEffect(resendCooldown) {
        if (resendCooldown > 0) {
            delay(1000)
            resendCooldown--
        }
    }

    // Handle success
    LaunchedEffect(uiState) {
        if (uiState is AuthUiState.Success) {
            showSuccess = true
            delay(1200)
            onNavigateToHome()
        }
    }

    // Show messages
    LaunchedEffect(errorMessage) {
        errorMessage?.let {
            snackbarHostState.showSnackbar(
                message = it,
                duration = SnackbarDuration.Short
            )
            viewModel.clearError()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = Color.Transparent
    ) { paddingValues ->
        Box(
            modifier = modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            AuthGradientBackground()

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                // Email icon with teal styling
                Box(
                    modifier = Modifier.size(100.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        modifier = Modifier
                            .size(80.dp)
                            .blur(40.dp)
                            .background(PremiumColors.Teal.copy(alpha = 0.25f))
                    )

                    Box(
                        modifier = Modifier
                            .size(88.dp)
                            .shadow(
                                elevation = 16.dp,
                                shape = CircleShape,
                                spotColor = PremiumColors.Teal.copy(alpha = 0.3f)
                            )
                            .background(
                                brush = Brush.linearGradient(
                                    listOf(
                                        PremiumColors.Teal.copy(alpha = 0.12f),
                                        PremiumColors.NeonGreen.copy(alpha = 0.08f)
                                    )
                                ),
                                shape = CircleShape
                            )
                            .border(
                                width = 1.dp,
                                color = PremiumColors.Teal.copy(alpha = 0.15f),
                                shape = CircleShape
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        if (showSuccess) {
                            Icon(
                                Icons.Default.CheckCircle,
                                contentDescription = null,
                                tint = Color(0xFF22C55E),
                                modifier = Modifier.size(44.dp)
                            )
                        } else {
                            Icon(
                                Icons.Default.Email,
                                contentDescription = null,
                                tint = PremiumColors.Teal,
                                modifier = Modifier.size(40.dp)
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(28.dp))

                Text(
                    if (showSuccess) "Email Verified!" else "Check Your Email",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onBackground,
                    textAlign = TextAlign.Center
                )

                Spacer(modifier = Modifier.height(12.dp))

                if (showSuccess) {
                    Text(
                        "Redirecting you to the app...",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )
                } else {
                    Text(
                        "We've sent a verification link to",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )

                    Spacer(modifier = Modifier.height(4.dp))

                    Text(
                        verificationEmail,
                        style = MaterialTheme.typography.bodyMedium.copy(
                            fontWeight = FontWeight.SemiBold
                        ),
                        color = PremiumColors.Teal,
                        textAlign = TextAlign.Center
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        "Tap the link in the email to verify\nyour account and continue.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        lineHeight = 20.sp
                    )

                    Spacer(modifier = Modifier.height(36.dp))

                    // Open Email App button
                    PremiumButton(
                        text = "Open Email App",
                        onClick = {
                            val emailIntent = Intent(Intent.ACTION_MAIN).apply {
                                addCategory(Intent.CATEGORY_APP_EMAIL)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            val resolveInfo = context.packageManager.queryIntentActivities(
                                emailIntent,
                                PackageManager.MATCH_DEFAULT_ONLY
                            )
                            if (resolveInfo.isNotEmpty()) {
                                context.startActivity(emailIntent)
                            } else {
                                try {
                                    context.startActivity(
                                        Intent(Intent.ACTION_VIEW, Uri.parse("https://mail.google.com"))
                                    )
                                } catch (_: Exception) { }
                            }
                        }
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    // Resend button
                    PremiumButton(
                        text = if (resendCooldown > 0) "Resend in ${resendCooldown}s" else "Resend Verification Email",
                        onClick = {
                            viewModel.resendVerificationEmail()
                            resendCooldown = 60
                        },
                        style = PremiumButtonStyle.SECONDARY,
                        enabled = resendCooldown == 0 && !isLoading,
                        isLoading = isLoading
                    )

                    Spacer(modifier = Modifier.height(28.dp))

                    Text(
                        "Check your spam folder if you don't see the email",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                        textAlign = TextAlign.Center
                    )

                    Spacer(modifier = Modifier.height(24.dp))

                    Text(
                        "Use a different email",
                        style = MaterialTheme.typography.bodyMedium,
                        color = PremiumColors.Teal,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.clickable { onNavigateBack() }
                    )
                }
            }

            // Back button
            if (!showSuccess) {
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
    }

