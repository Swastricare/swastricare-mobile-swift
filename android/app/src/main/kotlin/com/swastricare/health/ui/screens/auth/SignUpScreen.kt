package com.swastricare.health.ui.screens.auth

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.graphics.Brush
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
    val context = LocalContext.current

    var currentStep by remember { mutableStateOf(1) }
    var hasAttemptedStep1 by remember { mutableStateOf(false) }
    var hasAttemptedStep2 by remember { mutableStateOf(false) }

    var firstNameFocused by remember { mutableStateOf(false) }
    var lastNameFocused by remember { mutableStateOf(false) }
    var phoneFocused by remember { mutableStateOf(false) }
    var emailFocused by remember { mutableStateOf(false) }
    var passwordFocused by remember { mutableStateOf(false) }
    var confirmPasswordFocused by remember { mutableStateOf(false) }

    val lastNameFocusRequester = remember { FocusRequester() }
    val phoneFocusRequester = remember { FocusRequester() }
    val emailFocusRequester = remember { FocusRequester() }
    val confirmPasswordFocusRequester = remember { FocusRequester() }

    val isStep1Valid = formState.firstName.isNotBlank() &&
        formState.lastName.isNotBlank() &&
        formState.isValidPhone &&
        formState.isValidEmail

    val step1ErrorMessage: String? = when {
        !hasAttemptedStep1 -> null
        formState.firstName.isBlank() -> "Please enter your first name"
        formState.lastName.isBlank() -> "Please enter your last name"
        !formState.isValidPhone -> "Enter a valid 10-digit phone number"
        !formState.isValidEmail -> "Enter a valid email address"
        else -> null
    }

    val step2ErrorMessage: String? = when {
        !hasAttemptedStep2 -> null
        formState.password.isEmpty() -> "Password is required"
        !formState.isValidPassword -> formState.passwordError ?: "Password does not meet requirements"
        formState.confirmPassword.isEmpty() -> "Please confirm your password"
        !formState.passwordsMatch -> "Passwords do not match"
        !formState.agreedToTerms -> "Please accept the Terms and Privacy Policy"
        else -> null
    }

    LaunchedEffect(Unit) { viewModel.clearError() }

    BackHandler {
        if (currentStep == 2) currentStep = 1
        else onNavigateBack()
    }

    LaunchedEffect(uiState) {
        when (uiState) {
            is AuthUiState.Success -> onNavigateToHome()
            is AuthUiState.EmailVerificationRequired -> onNavigateToEmailVerification()
            else -> {}
        }
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
                        if (currentStep == 1) "Create your account" else "Create a password",
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF0F172A),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth()
                    )
                    Text(
                        if (currentStep == 1) "Tell us a bit about you" else "Almost done — set a strong password",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color(0xFF6B7280),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(modifier = Modifier.height(2.dp))

                    if (currentStep == 1) {
                        Step1Fields(
                            formState = formState,
                            viewModel = viewModel,
                            hasAttempted = hasAttemptedStep1,
                            firstNameFocused = firstNameFocused,
                            lastNameFocused = lastNameFocused,
                            phoneFocused = phoneFocused,
                            emailFocused = emailFocused,
                            onFirstNameFocusChange = { firstNameFocused = it },
                            onLastNameFocusChange = { lastNameFocused = it },
                            onPhoneFocusChange = { phoneFocused = it },
                            onEmailFocusChange = { emailFocused = it },
                            lastNameFocusRequester = lastNameFocusRequester,
                            phoneFocusRequester = phoneFocusRequester,
                            emailFocusRequester = emailFocusRequester,
                            onNext = {
                                hasAttemptedStep1 = true
                                if (isStep1Valid) {
                                    viewModel.clearError()
                                    currentStep = 2
                                }
                            }
                        )

                        val displayedStep1Error = errorMessage ?: step1ErrorMessage
                        if (displayedStep1Error != null) {
                            AuthAlertBanner(message = displayedStep1Error, isSuccess = false)
                        }

                        PremiumButton(
                            "Next",
                            onClick = {
                                hasAttemptedStep1 = true
                                if (isStep1Valid) {
                                    viewModel.clearError()
                                    currentStep = 2
                                }
                            },
                            enabled = !isLoading
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
                                "Already have an account? ",
                                style = MaterialTheme.typography.bodyMedium,
                                color = Color(0xFF6B7280)
                            )
                            Text(
                                "Sign In",
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                color = PremiumColors.Teal,
                                modifier = Modifier.clickable { onNavigateBack() }
                            )
                        }
                    } else {
                        Step2Fields(
                            formState = formState,
                            viewModel = viewModel,
                            hasAttempted = hasAttemptedStep2,
                            passwordFocused = passwordFocused,
                            confirmPasswordFocused = confirmPasswordFocused,
                            onPasswordFocusChange = { passwordFocused = it },
                            onConfirmPasswordFocusChange = { confirmPasswordFocused = it },
                            confirmPasswordFocusRequester = confirmPasswordFocusRequester,
                            onSubmit = {
                                hasAttemptedStep2 = true
                                if (formState.isValidForSignUp) {
                                    viewModel.clearError()
                                    viewModel.signUp()
                                }
                            }
                        )

                        val displayedStep2Error = errorMessage ?: step2ErrorMessage
                        if (displayedStep2Error != null) {
                            AuthAlertBanner(message = displayedStep2Error, isSuccess = false)
                        }

                        PremiumButton(
                            "Sign Up",
                            onClick = {
                                hasAttemptedStep2 = true
                                if (formState.isValidForSignUp) {
                                    viewModel.clearError()
                                    viewModel.signUp()
                                }
                            },
                            enabled = !isLoading,
                            isLoading = isLoading
                        )
                    }
                }
            }

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
                    .background(Color.White.copy(alpha = 0.7f), CircleShape)
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

@Composable
private fun Step1Fields(
    formState: AuthFormState,
    viewModel: AuthViewModel,
    hasAttempted: Boolean,
    firstNameFocused: Boolean,
    lastNameFocused: Boolean,
    phoneFocused: Boolean,
    emailFocused: Boolean,
    onFirstNameFocusChange: (Boolean) -> Unit,
    onLastNameFocusChange: (Boolean) -> Unit,
    onPhoneFocusChange: (Boolean) -> Unit,
    onEmailFocusChange: (Boolean) -> Unit,
    lastNameFocusRequester: FocusRequester,
    phoneFocusRequester: FocusRequester,
    emailFocusRequester: FocusRequester,
    onNext: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        PremiumTextField(
            value = formState.firstName,
            onValueChange = { viewModel.updateFirstName(it) },
            placeholder = "First Name",
            icon = Icons.Default.Person,
            keyboardType = KeyboardType.Text,
            imeAction = ImeAction.Next,
            keyboardActions = KeyboardActions(onNext = { lastNameFocusRequester.requestFocus() }),
            isFocused = firstNameFocused,
            modifier = Modifier
                .weight(1f)
                .onFocusChanged { onFirstNameFocusChange(it.isFocused) },
            isError = hasAttempted && formState.firstName.isBlank()
        )
        PremiumTextField(
            value = formState.lastName,
            onValueChange = { viewModel.updateLastName(it) },
            placeholder = "Last Name",
            icon = Icons.Default.Person,
            keyboardType = KeyboardType.Text,
            imeAction = ImeAction.Next,
            keyboardActions = KeyboardActions(onNext = { phoneFocusRequester.requestFocus() }),
            isFocused = lastNameFocused,
            modifier = Modifier
                .weight(1f)
                .focusRequester(lastNameFocusRequester)
                .onFocusChanged { onLastNameFocusChange(it.isFocused) },
            isError = hasAttempted && formState.lastName.isBlank()
        )
    }

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
            .onFocusChanged { onPhoneFocusChange(it.isFocused) },
        isError = hasAttempted && !formState.isValidPhone
    )

    PremiumTextField(
        value = formState.email,
        onValueChange = { viewModel.updateEmail(it) },
        placeholder = "Email Address",
        icon = Icons.Default.Email,
        keyboardType = KeyboardType.Email,
        imeAction = ImeAction.Done,
        keyboardActions = KeyboardActions(onDone = { onNext() }),
        isFocused = emailFocused,
        modifier = Modifier
            .focusRequester(emailFocusRequester)
            .onFocusChanged { onEmailFocusChange(it.isFocused) },
        isError = hasAttempted && !formState.isValidEmail
    )
}

@Composable
private fun Step2Fields(
    formState: AuthFormState,
    viewModel: AuthViewModel,
    hasAttempted: Boolean,
    passwordFocused: Boolean,
    confirmPasswordFocused: Boolean,
    onPasswordFocusChange: (Boolean) -> Unit,
    onConfirmPasswordFocusChange: (Boolean) -> Unit,
    confirmPasswordFocusRequester: FocusRequester,
    onSubmit: () -> Unit
) {
    PremiumSecureField(
        value = formState.password,
        onValueChange = { viewModel.updatePassword(it) },
        placeholder = "Password",
        icon = Icons.Default.Lock,
        imeAction = ImeAction.Next,
        keyboardActions = KeyboardActions(onNext = { confirmPasswordFocusRequester.requestFocus() }),
        isFocused = passwordFocused,
        modifier = Modifier.onFocusChanged { onPasswordFocusChange(it.isFocused) },
        isError = hasAttempted && !formState.isValidPassword
    )

    PremiumSecureField(
        value = formState.confirmPassword,
        onValueChange = { viewModel.updateConfirmPassword(it) },
        placeholder = "Confirm Password",
        icon = Icons.Default.Lock,
        imeAction = ImeAction.Done,
        keyboardActions = KeyboardActions(onDone = { onSubmit() }),
        isFocused = confirmPasswordFocused,
        modifier = Modifier
            .focusRequester(confirmPasswordFocusRequester)
            .onFocusChanged { onConfirmPasswordFocusChange(it.isFocused) },
        isError = hasAttempted && !formState.passwordsMatch
    )

    TermsCheckboxRow(
        checked = formState.agreedToTerms,
        onCheckedChange = { viewModel.updateAgreedToTerms(it) }
    )
}
