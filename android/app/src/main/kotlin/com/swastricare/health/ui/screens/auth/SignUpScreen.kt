package com.swastricare.health.ui.screens.auth

import androidx.activity.compose.BackHandler
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.auth.components.*

@Composable
fun SignUpScreen(
    viewModel: AuthViewModel,
    onNavigateBack: () -> Unit,
    onNavigateToHome: () -> Unit,
    onNavigateToEmailVerification: () -> Unit,
    modifier: Modifier = Modifier
) {
    TrackScreen("SignUp")
    val uiState by viewModel.uiState.collectAsState()
    val formState by viewModel.formState.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    var currentStep by remember { mutableIntStateOf(1) }
    var hasAttemptedStep1 by remember { mutableStateOf(false) }
    var hasAttemptedStep2 by remember { mutableStateOf(false) }

    var nameFocused by remember { mutableStateOf(false) }
    var phoneFocused by remember { mutableStateOf(false) }
    var emailFocused by remember { mutableStateOf(false) }
    var passwordFocused by remember { mutableStateOf(false) }
    var confirmPasswordFocused by remember { mutableStateOf(false) }

    val phoneFocusRequester = remember { FocusRequester() }
    val emailFocusRequester = remember { FocusRequester() }
    val passwordFocusRequester = remember { FocusRequester() }
    val confirmPasswordFocusRequester = remember { FocusRequester() }

    val isDark = isSystemInDarkTheme()

    val isStep1Valid = formState.fullName.isNotBlank() && formState.isValidEmail && formState.isValidPhone

    // Handle back on step 2 → go to step 1
    BackHandler(enabled = currentStep == 2) {
        currentStep = 1
    }

    LaunchedEffect(uiState) {
        when (uiState) {
            is AuthUiState.Success -> onNavigateToHome()
            is AuthUiState.EmailVerificationRequired -> onNavigateToEmailVerification()
            else -> {}
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
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {

                // Header
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        "Create Account",
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onBackground
                    )
                    Text(
                        if (currentStep == 1) "Start your health journey today"
                        else "Secure your account",
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Step indicator dots
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    for (step in 1..2) {
                        Box(
                            modifier = Modifier
                                .size(if (step == currentStep) 10.dp else 8.dp)
                                .clip(CircleShape)
                                .background(
                                    if (step == currentStep) PremiumColors.Teal
                                    else if (step < currentStep) PremiumColors.Teal.copy(alpha = 0.5f)
                                    else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
                                )
                        )
                    }
                }
                Text(
                    "Step $currentStep of 2",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp)
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Form card
                GlassCard(modifier = Modifier.padding(horizontal = 20.dp)) {
                    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
                        AnimatedContent(
                            targetState = currentStep,
                            transitionSpec = {
                                if (targetState > initialState) {
                                    slideInHorizontally { it } + fadeIn() togetherWith
                                            slideOutHorizontally { -it } + fadeOut()
                                } else {
                                    slideInHorizontally { -it } + fadeIn() togetherWith
                                            slideOutHorizontally { it } + fadeOut()
                                }
                            },
                            label = "step_transition"
                        ) { step ->
                            when (step) {
                                1 -> Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
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
                                        isError = hasAttemptedStep1 && formState.fullName.isBlank(),
                                        errorText = "Full name is required"
                                    )

                                    PremiumTextField(
                                        value = formState.phone,
                                        onValueChange = { if (it.length <= 10 && it.all { c -> c.isDigit() }) viewModel.updatePhone(it) },
                                        placeholder = "Phone Number",
                                        icon = Icons.Default.Phone,
                                        keyboardType = KeyboardType.Phone,
                                        imeAction = ImeAction.Next,
                                        keyboardActions = KeyboardActions(onNext = { emailFocusRequester.requestFocus() }),
                                        isFocused = phoneFocused,
                                        modifier = Modifier
                                            .focusRequester(phoneFocusRequester)
                                            .onFocusChanged { phoneFocused = it.isFocused },
                                        isError = hasAttemptedStep1 && !formState.isValidPhone,
                                        errorText = if (formState.phone.isEmpty()) "Phone number is required" else "Phone number must be 10 digits"
                                    )

                                    PremiumTextField(
                                        value = formState.email,
                                        onValueChange = { viewModel.updateEmail(it) },
                                        placeholder = "Email",
                                        icon = Icons.Default.Email,
                                        keyboardType = KeyboardType.Email,
                                        imeAction = ImeAction.Done,
                                        keyboardActions = KeyboardActions(onDone = {
                                            hasAttemptedStep1 = true
                                            if (isStep1Valid) currentStep = 2
                                        }),
                                        isFocused = emailFocused,
                                        modifier = Modifier
                                            .focusRequester(emailFocusRequester)
                                            .onFocusChanged { emailFocused = it.isFocused },
                                        isError = hasAttemptedStep1 && !formState.isValidEmail,
                                        errorText = "Enter a valid email address"
                                    )
                                }

                                2 -> Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                                    PremiumSecureField(
                                        value = formState.password,
                                        onValueChange = { viewModel.updatePassword(it) },
                                        placeholder = "Password",
                                        icon = Icons.Default.Lock,
                                        imeAction = ImeAction.Next,
                                        keyboardActions = KeyboardActions(onNext = { confirmPasswordFocusRequester.requestFocus() }),
                                        isFocused = passwordFocused,
                                        modifier = Modifier
                                            .focusRequester(passwordFocusRequester)
                                            .onFocusChanged { passwordFocused = it.isFocused },
                                        isError = hasAttemptedStep2 && !formState.isValidPassword,
                                        errorText = if (formState.password.isEmpty()) "Password is required" else formState.passwordError
                                    )

                                    PremiumSecureField(
                                        value = formState.confirmPassword,
                                        onValueChange = { viewModel.updateConfirmPassword(it) },
                                        placeholder = "Confirm Password",
                                        icon = Icons.Default.CheckCircle,
                                        imeAction = ImeAction.Done,
                                        keyboardActions = KeyboardActions(onDone = {
                                            hasAttemptedStep2 = true
                                            if (formState.isValidForSignUp) viewModel.signUp()
                                        }),
                                        isFocused = confirmPasswordFocused,
                                        modifier = Modifier
                                            .focusRequester(confirmPasswordFocusRequester)
                                            .onFocusChanged { confirmPasswordFocused = it.isFocused },
                                        isError = hasAttemptedStep2 && !formState.passwordsMatch,
                                        errorText = if (formState.confirmPassword.isNotEmpty()) "Passwords do not match" else "Please confirm your password"
                                    )
                                }
                            }
                        }

                        // Error banner
                        if (errorMessage != null) {
                            AuthAlertBanner(message = errorMessage ?: "", isSuccess = false)
                        }

                        if (currentStep == 1) {
                            PremiumButton(
                                "Continue",
                                onClick = {
                                    hasAttemptedStep1 = true
                                    if (isStep1Valid) {
                                        viewModel.clearError()
                                        currentStep = 2
                                    }
                                },
                                enabled = true,
                                isLoading = false
                            )
                        } else {
                            PremiumButton(
                                "Create Account",
                                onClick = {
                                    hasAttemptedStep2 = true
                                    if (formState.isValidForSignUp) viewModel.signUp()
                                },
                                enabled = !isLoading,
                                isLoading = isLoading
                            )

                            Text(
                                "By signing up, you agree to our Terms & Privacy Policy",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))

                // Footer
                Row(
                    horizontalArrangement = Arrangement.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 24.dp)
                ) {
                    Text(
                        "Already have an account? ",
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
            }

            // Back button - circular glass style like iOS
            IconButton(
                onClick = {
                    if (currentStep == 2) currentStep = 1
                    else onNavigateBack()
                },
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

