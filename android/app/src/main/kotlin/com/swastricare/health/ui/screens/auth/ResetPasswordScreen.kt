package com.swastricare.health.ui.screens.auth

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.screens.auth.components.*

@Composable
fun ResetPasswordScreen(
    viewModel: AuthViewModel,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val formState by viewModel.formState.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(errorMessage) {
        errorMessage?.let {
            val isSuccess = it.contains("sent", ignoreCase = true)
            snackbarHostState.showSnackbar(
                message = it,
                actionLabel = "Dismiss",
                duration = if (isSuccess) SnackbarDuration.Long else SnackbarDuration.Short
            )
            if (!isSuccess) viewModel.clearError()
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
                        "Reset Password",
                        fontSize = 36.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.onBackground
                    )
                    Text(
                        "Enter your email and we'll send you\na link to reset your password",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )
                }

                Spacer(modifier = Modifier.height(30.dp))

                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(24.dp)
                ) {
                    PremiumTextField(
                        value = formState.email,
                        onValueChange = { viewModel.updateEmail(it) },
                        placeholder = "Email",
                        icon = Icons.Default.Email,
                        keyboardType = KeyboardType.Email,
                        imeAction = ImeAction.Done
                    )

                    PremiumButton(
                        "Send Reset Link",
                        onClick = { viewModel.resetPassword() },
                        enabled = formState.isValidEmail && !isLoading,
                        isLoading = isLoading
                    )
                }

                Spacer(modifier = Modifier.height(20.dp))

                Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth()) {
                    Text("Remember your password? ", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
