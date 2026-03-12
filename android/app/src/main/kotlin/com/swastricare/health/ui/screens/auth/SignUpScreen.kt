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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.screens.auth.components.*

@Composable
fun SignUpScreen(
    viewModel: AuthViewModel,
    onNavigateBack: () -> Unit,
    onNavigateToHome: () -> Unit,
    onNavigateToEmailVerification: () -> Unit,
    modifier: Modifier = Modifier
) {
    val uiState by viewModel.uiState.collectAsState()
    val formState by viewModel.formState.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    var hasAttemptedSignUp by remember { mutableStateOf(false) }

    var nameFocused by remember { mutableStateOf(false) }
    var phoneFocused by remember { mutableStateOf(false) }
    var emailFocused by remember { mutableStateOf(false) }
    var passwordFocused by remember { mutableStateOf(false) }
    var confirmPasswordFocused by remember { mutableStateOf(false) }

    val phoneFocusRequester = remember { FocusRequester() }
    val emailFocusRequester = remember { FocusRequester() }
    val passwordFocusRequester = remember { FocusRequester() }
    val confirmPasswordFocusRequester = remember { FocusRequester() }

    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(uiState) {
        when (uiState) {
            is AuthUiState.Success -> onNavigateToHome()
            is AuthUiState.EmailVerificationRequired -> onNavigateToEmailVerification()
            else -> {}
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
            PremiumBackground()

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
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        "Create Account",
                        fontSize = 36.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.onBackground
                    )
                    Text(
                        "Start your health journey today",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Spacer(modifier = Modifier.height(30.dp))

                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(24.dp)
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        PremiumTextField(
                            value = formState.fullName,
                            onValueChange = { viewModel.updateFullName(it) },
                            placeholder = "Full Name",
                            icon = Icons.Default.Person,
                            keyboardType = KeyboardType.Text,
                            imeAction = ImeAction.Next,
                            keyboardActions = KeyboardActions(onNext = { phoneFocusRequester.requestFocus() }),
                            isFocused = nameFocused,
                            modifier = Modifier.onFocusChanged { nameFocused = it.isFocused },
                            isError = hasAttemptedSignUp && formState.fullName.isBlank(),
                            errorText = "Full name is required"
                        )

                        PremiumTextField(
                            value = formState.phone,
                            onValueChange = { viewModel.updatePhone(it) },
                            placeholder = "Phone Number (optional)",
                            icon = Icons.Default.Phone,
                            keyboardType = KeyboardType.Phone,
                            imeAction = ImeAction.Next,
                            keyboardActions = KeyboardActions(onNext = { emailFocusRequester.requestFocus() }),
                            isFocused = phoneFocused,
                            modifier = Modifier.focusRequester(phoneFocusRequester).onFocusChanged { phoneFocused = it.isFocused },
                            isError = hasAttemptedSignUp && !formState.isValidPhone,
                            errorText = "Enter a valid phone number"
                        )

                        PremiumTextField(
                            value = formState.email,
                            onValueChange = { viewModel.updateEmail(it) },
                            placeholder = "Email",
                            icon = Icons.Default.Email,
                            keyboardType = KeyboardType.Email,
                            imeAction = ImeAction.Next,
                            keyboardActions = KeyboardActions(onNext = { passwordFocusRequester.requestFocus() }),
                            isFocused = emailFocused,
                            modifier = Modifier.focusRequester(emailFocusRequester).onFocusChanged { emailFocused = it.isFocused },
                            isError = hasAttemptedSignUp && !formState.isValidEmail,
                            errorText = "Enter a valid email address"
                        )

                        PremiumSecureField(
                            value = formState.password,
                            onValueChange = { viewModel.updatePassword(it) },
                            placeholder = "Password",
                            icon = Icons.Default.Lock,
                            imeAction = ImeAction.Next,
                            keyboardActions = KeyboardActions(onNext = { confirmPasswordFocusRequester.requestFocus() }),
                            isFocused = passwordFocused,
                            modifier = Modifier.focusRequester(passwordFocusRequester).onFocusChanged { passwordFocused = it.isFocused },
                            isError = hasAttemptedSignUp && !formState.isValidPassword,
                            errorText = formState.passwordError
                        )

                        PremiumSecureField(
                            value = formState.confirmPassword,
                            onValueChange = { viewModel.updateConfirmPassword(it) },
                            placeholder = "Confirm Password",
                            icon = Icons.Default.CheckCircle,
                            imeAction = ImeAction.Done,
                            keyboardActions = KeyboardActions(onDone = {
                                hasAttemptedSignUp = true
                                if (formState.isValidForSignUp) viewModel.signUp()
                            }),
                            isFocused = confirmPasswordFocused,
                            modifier = Modifier.focusRequester(confirmPasswordFocusRequester).onFocusChanged { confirmPasswordFocused = it.isFocused },
                            isError = hasAttemptedSignUp && !formState.passwordsMatch,
                            errorText = if (formState.confirmPassword.isNotEmpty()) "Passwords do not match" else "Please confirm your password"
                        )
                    }

                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        PremiumButton(
                            "Create Account",
                            onClick = {
                                hasAttemptedSignUp = true
                                viewModel.signUp()
                            },
                            enabled = !isLoading,
                            isLoading = isLoading
                        )

                        Text(
                            "By signing up, you agree to our Terms of Service and Privacy Policy",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))

                Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth()) {
                    Text("Already have an account? ", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Sign In", style = MaterialTheme.typography.bodyMedium, color = PremiumColors.RoyalBlue, fontWeight = FontWeight.Bold, modifier = Modifier.clickable { onNavigateBack() })
                }

                Spacer(modifier = Modifier.height(30.dp))
            }

            IconButton(onClick = onNavigateBack, modifier = Modifier.padding(16.dp).align(Alignment.TopStart)) {
                @Suppress("DEPRECATION")
                Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = PremiumColors.RoyalBlue)
            }
        }
    }
}
