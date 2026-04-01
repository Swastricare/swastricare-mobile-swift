package com.swastricare.health.ui.screens.auth

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.auth.components.*

@Composable
fun LoginScreen(
    viewModel: AuthViewModel,
    onNavigateToSignUp: () -> Unit,
    onNavigateToHome: () -> Unit,
    onNavigateToResetPassword: () -> Unit,
    modifier: Modifier = Modifier
) {
    TrackScreen("Login")
    val context = LocalContext.current
    val uiState by viewModel.uiState.collectAsState()
    val formState by viewModel.formState.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    var emailFocused by remember { mutableStateOf(false) }
    var passwordFocused by remember { mutableStateOf(false) }
    val passwordFocusRequester = remember { FocusRequester() }

    var hasAttemptedLogin by remember { mutableStateOf(false) }

    // Entrance animation states
    var animateIn by remember { mutableStateOf(false) }

    val logoScale by animateFloatAsState(
        targetValue = if (animateIn) 1f else 0.6f,
        animationSpec = spring(dampingRatio = 0.65f, stiffness = Spring.StiffnessLow),
        label = "logoScale"
    )
    val logoAlpha by animateFloatAsState(
        targetValue = if (animateIn) 1f else 0f,
        animationSpec = spring(dampingRatio = 0.65f, stiffness = Spring.StiffnessLow),
        label = "logoAlpha"
    )
    val headerAlpha by animateFloatAsState(
        targetValue = if (animateIn) 1f else 0f,
        animationSpec = tween(600, delayMillis = 300),
        label = "headerAlpha"
    )
    val formAlpha by animateFloatAsState(
        targetValue = if (animateIn) 1f else 0f,
        animationSpec = tween(700, delayMillis = 500),
        label = "formAlpha"
    )
    val footerAlpha by animateFloatAsState(
        targetValue = if (animateIn) 1f else 0f,
        animationSpec = tween(400, delayMillis = 800),
        label = "footerAlpha"
    )

    LaunchedEffect(Unit) { animateIn = true }

    LaunchedEffect(uiState) {
        if (uiState is AuthUiState.Success) {
            onNavigateToHome()
        }
    }

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
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.height(20.dp))

                // Logo hero
                AnimatedLogo(
                    logoScale = logoScale,
                    glowBreathing = animateIn,
                    modifier = Modifier.alpha(logoAlpha)
                )

                Spacer(modifier = Modifier.height(4.dp))

                // Header text
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.alpha(headerAlpha)
                ) {
                    Text(
                        "SwastriCare",
                        style = TextStyle(
                            fontSize = 30.sp,
                            fontWeight = FontWeight.Bold,
                            brush = Brush.linearGradient(PremiumColors.TealGreenGradient)
                        )
                    )
                    Text(
                        "Your family's health companion",
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Spacer(modifier = Modifier.height(25.dp))

                // Form card
                GlassCard(
                    modifier = Modifier
                        .padding(horizontal = 20.dp)
                        .alpha(formAlpha)
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
                        // Input fields
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            PremiumTextField(
                                value = formState.email,
                                onValueChange = { viewModel.updateEmail(it) },
                                placeholder = "Email",
                                icon = Icons.Default.Email,
                                keyboardType = KeyboardType.Email,
                                imeAction = ImeAction.Next,
                                keyboardActions = KeyboardActions(onNext = { passwordFocusRequester.requestFocus() }),
                                isFocused = emailFocused,
                                modifier = Modifier.onFocusChanged { emailFocused = it.isFocused },
                                isError = hasAttemptedLogin && !formState.isValidEmail
                            )

                            PremiumSecureField(
                                value = formState.password,
                                onValueChange = { viewModel.updatePassword(it) },
                                placeholder = "Password",
                                icon = Icons.Default.Lock,
                                imeAction = ImeAction.Done,
                                keyboardActions = KeyboardActions(onDone = {
                                    hasAttemptedLogin = true
                                    if (formState.isValidForLogin) viewModel.signIn()
                                }),
                                isFocused = passwordFocused,
                                modifier = Modifier
                                    .focusRequester(passwordFocusRequester)
                                    .onFocusChanged { passwordFocused = it.isFocused },
                                isError = hasAttemptedLogin && !formState.isValidPassword
                            )
                        }

                        // Forgot password
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                            Text(
                                "Forgot Password?",
                                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
                                color = PremiumColors.Teal,
                                modifier = Modifier.clickable { onNavigateToResetPassword() }
                            )
                        }

                        // Error banner
                        if (errorMessage != null) {
                            AuthAlertBanner(message = errorMessage ?: "", isSuccess = false)
                        }

                        // Sign In button
                        PremiumButton(
                            "Sign In",
                            onClick = {
                                hasAttemptedLogin = true
                                viewModel.signIn()
                            },
                            enabled = !isLoading,
                            isLoading = isLoading
                        )

                        // Divider
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            HorizontalDivider(
                                modifier = Modifier.weight(1f),
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)
                            )
                            Text(
                                "or",
                                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            HorizontalDivider(
                                modifier = Modifier.weight(1f),
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)
                            )
                        }

                        // Social buttons - side by side like iOS
                        SocialLoginButton(
                            assetPath = "icons/google_icon.png",
                            label = "Sign in with Google",
                            onClick = { viewModel.signInWithGoogle(context) },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !isLoading && viewModel.isGoogleSignInConfigured
                        )
                    }
                }

                Spacer(modifier = Modifier.weight(1f))

                // Footer
                Row(
                    horizontalArrangement = Arrangement.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .alpha(footerAlpha)
                        .padding(bottom = 28.dp)
                ) {
                    Text(
                        "New here? ",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "Create Account",
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                        color = PremiumColors.Teal,
                        modifier = Modifier.clickable { onNavigateToSignUp() }
                    )
                }
            }
        }
        }
    }

