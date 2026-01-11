package com.swasthicare.mobile.ui.screens.auth

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.ui.screens.auth.components.*
import kotlinx.coroutines.delay

@Composable
fun LoginScreen(
    viewModel: AuthViewModel,
    onNavigateToSignUp: () -> Unit,
    onNavigateToHome: () -> Unit,
    onNavigateToResetPassword: () -> Unit,
    modifier: Modifier = Modifier
) {
    val uiState by viewModel.uiState.collectAsState()
    val formState by viewModel.formState.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    
    val snackbarHostState = remember { SnackbarHostState() }
    
    var isAnimating by remember { mutableStateOf(false) }
    var emailFocused by remember { mutableStateOf(false) }
    var passwordFocused by remember { mutableStateOf(false) }
    val passwordFocusRequester = remember { FocusRequester() }
    
    // Show validation errors only after first attempt
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
    
    LaunchedEffect(Unit) {
        delay(100)
        isAnimating = true
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
                    .imePadding(), // Handle keyboard
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.height(60.dp))
                
                AnimatedVisibility(
                    visible = isAnimating,
                    enter = fadeIn(tween(800, easing = EaseOut)) + slideInVertically(tween(800, easing = EaseOut)) { -20 }
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(20.dp)
                    ) {
                        AnimatedLogo()
                        
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(
                                "Welcome Back",
                                fontSize = 36.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = PremiumColors.TextDark
                            )
                            Text(
                                "Sign in to your health companion",
                                style = MaterialTheme.typography.bodyLarge,
                                color = PremiumColors.TextGrey
                            )
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(30.dp))
                
                AnimatedVisibility(
                    visible = isAnimating,
                    enter = fadeIn(tween(800, 200, easing = EaseOut)) + slideInVertically(tween(800, 200, easing = EaseOut)) { 20 }
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .shadow(
                                elevation = 25.dp, 
                                shape = RoundedCornerShape(30.dp),
                                spotColor = PremiumColors.RoyalBlue.copy(alpha = 0.2f),
                                ambientColor = PremiumColors.Cyan.copy(alpha = 0.1f)
                            )
                            .background(Color.White, RoundedCornerShape(30.dp))
                            .padding(30.dp),
                        verticalArrangement = Arrangement.spacedBy(25.dp)
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
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
                        }
                        
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                            Text("Forgot Password?", style = MaterialTheme.typography.bodySmall, color = PremiumColors.RoyalBlue, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable { onNavigateToResetPassword() })
                        }
                        
                        PremiumButton(
                            "Sign In", 
                            onClick = { 
                                hasAttemptedLogin = true
                                viewModel.signIn() 
                            }, 
                            enabled = !isLoading, 
                            isLoading = isLoading
                        )
                    }
                }
                
                Spacer(modifier = Modifier.height(20.dp))
                
                AnimatedVisibility(
                    visible = isAnimating,
                    enter = fadeIn(tween(800, 300, easing = EaseOut)) + slideInVertically(tween(800, 300, easing = EaseOut)) { 30 }
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
                        Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            HorizontalDivider(modifier = Modifier.weight(1f), color = PremiumColors.TextGrey.copy(alpha = 0.2f))
                            Text("Or continue with", style = MaterialTheme.typography.bodySmall, color = PremiumColors.TextGrey)
                            HorizontalDivider(modifier = Modifier.weight(1f), color = PremiumColors.TextGrey.copy(alpha = 0.2f))
                        }
                        
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                            SocialLoginButton(Icons.Default.Email, "Google", onClick = { viewModel.signInWithGoogle() }, modifier = Modifier.weight(1f), enabled = !isLoading)
                            SocialLoginButton(Icons.Default.AccountCircle, "Apple", onClick = { }, modifier = Modifier.weight(1f), enabled = !isLoading)
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(20.dp))
                
                AnimatedVisibility(
                    visible = isAnimating,
                    enter = fadeIn(tween(800, 400, easing = EaseOut)) + slideInVertically(tween(800, 400, easing = EaseOut)) { 40 }
                ) {
                    Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth()) {
                        Text("Don't have an account? ", style = MaterialTheme.typography.bodyMedium, color = PremiumColors.TextGrey)
                        Text("Sign Up", style = MaterialTheme.typography.bodyMedium, color = PremiumColors.RoyalBlue, fontWeight = FontWeight.Bold, modifier = Modifier.clickable { onNavigateToSignUp() })
                    }
                }
                
                Spacer(modifier = Modifier.height(30.dp))
            }
        }
    }
}
