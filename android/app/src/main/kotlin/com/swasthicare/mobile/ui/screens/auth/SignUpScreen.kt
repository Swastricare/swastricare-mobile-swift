package com.swasthicare.mobile.ui.screens.auth

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
import com.swasthicare.mobile.ui.screens.auth.components.*

@Composable
fun SignUpScreen(
    viewModel: AuthViewModel,
    onNavigateBack: () -> Unit,
    onNavigateToHome: () -> Unit,
    modifier: Modifier = Modifier
) {
    val uiState by viewModel.uiState.collectAsState()
    val formState by viewModel.formState.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    var nameFocused by remember { mutableStateOf(false) }
    var emailFocused by remember { mutableStateOf(false) }
    var passwordFocused by remember { mutableStateOf(false) }
    var confirmPasswordFocused by remember { mutableStateOf(false) }

    val emailFocusRequester = remember { FocusRequester() }
    val passwordFocusRequester = remember { FocusRequester() }
    val confirmPasswordFocusRequester = remember { FocusRequester() }

    val snackbarHostState = remember { SnackbarHostState() }

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
                            keyboardActions = KeyboardActions(onNext = { emailFocusRequester.requestFocus() }),
                            isFocused = nameFocused,
                            modifier = Modifier.onFocusChanged { nameFocused = it.isFocused }
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
                            modifier = Modifier.focusRequester(emailFocusRequester).onFocusChanged { emailFocused = it.isFocused }
                        )

                        PremiumSecureField(
                            value = formState.password,
                            onValueChange = { viewModel.updatePassword(it) },
                            placeholder = "Password",
                            icon = Icons.Default.Lock,
                            imeAction = ImeAction.Next,
                            keyboardActions = KeyboardActions(onNext = { confirmPasswordFocusRequester.requestFocus() }),
                            isFocused = passwordFocused,
                            modifier = Modifier.focusRequester(passwordFocusRequester).onFocusChanged { passwordFocused = it.isFocused }
                        )

                        PremiumSecureField(
                            value = formState.confirmPassword,
                            onValueChange = { viewModel.updateConfirmPassword(it) },
                            placeholder = "Confirm Password",
                            icon = Icons.Default.CheckCircle,
                            imeAction = ImeAction.Done,
                            keyboardActions = KeyboardActions(onDone = { if (formState.isValidForSignUp) viewModel.signUp() }),
                            isFocused = confirmPasswordFocused,
                            modifier = Modifier.focusRequester(confirmPasswordFocusRequester).onFocusChanged { confirmPasswordFocused = it.isFocused }
                        )
                    }

                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        PremiumButton(
                            "Create Account",
                            onClick = { viewModel.signUp() },
                            enabled = formState.isValidForSignUp && !isLoading,
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
