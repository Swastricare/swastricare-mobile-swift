package com.swastricare.health.ui.screens.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.graphics.Brush
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
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

    LaunchedEffect(Unit) { viewModel.clearError() }

    LaunchedEffect(uiState) {
        if (uiState is AuthUiState.Success) onNavigateToHome()
    }

    val pageBg = Color(0xFFF6FAFC)
    val gradient = Brush.verticalGradient(
        colorStops = arrayOf(
            0f to pageBg,
            0.35f to pageBg,
            0.55f to Color.White,
            1f to Color.White
        )
    )

    Scaffold(containerColor = Color.Transparent) { paddingValues ->
        Box(modifier = modifier.fillMaxSize().padding(paddingValues).background(gradient)) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .imePadding()
                    .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                BrandAuthHeader()

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                        Text(
                            "Welcome back!",
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF0F172A),
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Text(
                            "Login to continue",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color(0xFF6B7280),
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth()
                        )

                        Spacer(modifier = Modifier.height(2.dp))

                        PremiumTextField(
                            value = formState.email,
                            onValueChange = { viewModel.updateEmail(it) },
                            placeholder = "Email or Phone Number",
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

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End
                        ) {
                            Text(
                                "Forgot Password?",
                                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                                color = PremiumColors.Teal,
                                modifier = Modifier.clickable { onNavigateToResetPassword() }
                            )
                        }

                        if (errorMessage != null) {
                            AuthAlertBanner(message = errorMessage ?: "", isSuccess = false)
                        }

                        PremiumButton(
                            "Login",
                            onClick = {
                                hasAttemptedLogin = true
                                viewModel.signIn()
                            },
                            enabled = !isLoading,
                            isLoading = isLoading
                        )

                        OrDividerRow(text = "or continue with")

                        BrandSocialButton(
                            label = "Continue with Google",
                            onClick = { viewModel.signInWithGoogle(context) },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !isLoading && viewModel.isGoogleSignInConfigured
                        ) { GoogleIcon() }

                        Row(
                            horizontalArrangement = Arrangement.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 4.dp)
                        ) {
                            Text(
                                "Don't have an account? ",
                                style = MaterialTheme.typography.bodyMedium,
                                color = Color(0xFF6B7280)
                            )
                            Text(
                                "Sign Up",
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                color = PremiumColors.Teal,
                                modifier = Modifier.clickable { onNavigateToSignUp() }
                            )
                        }
                    }
            }
        }
    }
}
