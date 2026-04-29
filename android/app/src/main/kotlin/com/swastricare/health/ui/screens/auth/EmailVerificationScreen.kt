package com.swastricare.health.ui.screens.auth

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.components.TrackScreen
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

    BackHandler { onNavigateBack() }

    LaunchedEffect(resendCooldown) {
        if (resendCooldown > 0) {
            delay(1000)
            resendCooldown--
        }
    }

    LaunchedEffect(uiState) {
        if (uiState is AuthUiState.Success) {
            showSuccess = true
            delay(1200)
            onNavigateToHome()
        }
    }

    LaunchedEffect(errorMessage) {
        errorMessage?.let {
            snackbarHostState.showSnackbar(message = it, duration = SnackbarDuration.Short)
            viewModel.clearError()
        }
    }

    val pageBg = Color.White

    val brandLogoBitmap = remember {
        runCatching {
            val s = context.assets.open("icons/swastricare icon.png")
            android.graphics.BitmapFactory.decodeStream(s)
        }.getOrNull()
    }
    val illustrationBitmap = remember {
        runCatching {
            val s = context.assets.open("images/verify email.png")
            android.graphics.BitmapFactory.decodeStream(s)
        }.getOrNull()
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = pageBg
    ) { paddingValues ->
        Box(modifier = modifier.fillMaxSize().padding(paddingValues)) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .imePadding(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.height(56.dp))

                // Brand logo + wordmark + tagline
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (brandLogoBitmap != null) {
                        Image(
                            bitmap = brandLogoBitmap.asImageBitmap(),
                            contentDescription = "SwasthiCare logo",
                            modifier = Modifier.size(36.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                    }
                    Text(
                        buildAnnotatedString {
                            withStyle(SpanStyle(color = PremiumColors.Teal, fontWeight = FontWeight.Bold)) {
                                append("Swasthi")
                            }
                            withStyle(SpanStyle(color = Color(0xFF0A8F7A), fontWeight = FontWeight.Bold)) {
                                append("Care")
                            }
                        },
                        fontSize = 22.sp
                    )
                }
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    "Your Family, Our Care",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF6B7280)
                )

                Spacer(modifier = Modifier.height(24.dp))

                // Illustration
                if (illustrationBitmap != null) {
                    Image(
                        bitmap = illustrationBitmap.asImageBitmap(),
                        contentDescription = "Verify email illustration",
                        contentScale = ContentScale.Fit,
                        modifier = Modifier
                            .size(200.dp)
                            .padding(8.dp)
                    )
                } else {
                    Spacer(modifier = Modifier.height(200.dp))
                }

                Spacer(modifier = Modifier.height(20.dp))

                // Title
                Text(
                    if (showSuccess) "Email Verified!" else "Check Your Email",
                    fontSize = 26.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF0F172A),
                    textAlign = TextAlign.Center
                )

                Spacer(modifier = Modifier.height(10.dp))

                if (showSuccess) {
                    Text(
                        "Redirecting you to the app...",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color(0xFF6B7280),
                        textAlign = TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(24.dp))
                } else {
                    Text(
                        "We've sent a verification link to",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color(0xFF6B7280),
                        textAlign = TextAlign.Center
                    )

                    Spacer(modifier = Modifier.height(4.dp))

                    Text(
                        verificationEmail,
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = PremiumColors.Teal,
                        textAlign = TextAlign.Center
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        "Tap the link in the email to verify your account and continue.",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF6B7280),
                        textAlign = TextAlign.Center,
                        lineHeight = 20.sp,
                        modifier = Modifier.padding(horizontal = 32.dp)
                    )

                    Spacer(modifier = Modifier.height(28.dp))

                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 24.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
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
                    }

                    Spacer(modifier = Modifier.height(20.dp))

                    Text(
                        "Check your spam folder if you don't see the email",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF6B7280).copy(alpha = 0.7f),
                        textAlign = TextAlign.Center
                    )

                    Spacer(modifier = Modifier.height(20.dp))

                    Row(
                        horizontalArrangement = Arrangement.Center,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            "Wrong email? ",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color(0xFF6B7280)
                        )
                        Text(
                            "Use a different email",
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                            color = PremiumColors.Teal,
                            modifier = Modifier.clickable { onNavigateBack() }
                        )
                    }

                    Spacer(modifier = Modifier.height(24.dp))
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
                            color = Color.Black.copy(alpha = 0.04f),
                            shape = CircleShape
                        )
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = Color(0xFF0F172A),
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }
    }
}
