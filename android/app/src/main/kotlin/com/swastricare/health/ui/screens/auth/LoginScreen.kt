package com.swastricare.health.ui.screens.auth

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
import com.swastricare.health.ui.theme.AppColors

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

    val snackbarHostState = remember { SnackbarHostState() }

    var emailFocused by remember { mutableStateOf(false) }
    var passwordFocused by remember { mutableStateOf(false) }
    val passwordFocusRequester = remember { FocusRequester() }

    var hasAttemptedLogin by remember { mutableStateOf(false) }

    LaunchedEffect(uiState) {
        if (uiState is AuthUiState.Success) {
            onNavigateToHome()
        }
    }

    LaunchedEffect(errorMessage) {
        errorMessage?.let {
            snackbarHostState.showSnackbar(
                message = it,
                actionLabel = "Dismiss",
                duration = SnackbarDuration.Short
            )
            viewModel.clearError()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = Color.Transparent
    ) { paddingValues ->
        Box(modifier = modifier.fillMaxSize().padding(paddingValues)) {

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp)
                    .imePadding(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            "Welcome Back",
                            fontSize = 36.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = MaterialTheme.colorScheme.onBackground
                        )
                        Text(
                            "Sign in to your health companion",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Spacer(modifier = Modifier.height(30.dp))

                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(24.dp)
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
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
                            modifier = Modifier.focusRequester(passwordFocusRequester).onFocusChanged { passwordFocused = it.isFocused },
                            isError = hasAttemptedLogin && !formState.isValidPassword
                        )

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                            Text(
                                "Forgot Password?",
                                style = MaterialTheme.typography.bodySmall,
                                color = PremiumColors.RoyalBlue,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.clickable { onNavigateToResetPassword() }
                            )
                        }
                    }

                    if (errorMessage != null) {
                        Text(
                            errorMessage ?: "",
                            style = MaterialTheme.typography.bodySmall,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.error,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }

                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        PremiumButton(
                            "Sign In",
                            onClick = {
                                hasAttemptedLogin = true
                                viewModel.signIn()
                            },
                            enabled = !isLoading,
                            isLoading = isLoading
                        )

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            HorizontalDivider(modifier = Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f))
                            Text("OR", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            HorizontalDivider(modifier = Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f))
                        }

                        SocialLoginButton(
                            icon = Icons.Default.Email,
                            label = "Continue with Google",
                            onClick = { viewModel.signInWithGoogle(context) },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !isLoading && viewModel.isGoogleSignInConfigured
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))

                Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth()) {
                    Text("Don't have an account? ", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Sign Up", style = MaterialTheme.typography.bodyMedium, color = PremiumColors.RoyalBlue, fontWeight = FontWeight.Bold, modifier = Modifier.clickable { onNavigateToSignUp() })
                }

                Spacer(modifier = Modifier.height(30.dp))
            }
        }
    }
}
