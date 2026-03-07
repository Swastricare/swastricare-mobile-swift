package com.swasthicare.mobile.ui.screens.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.ui.screens.auth.components.*

@Composable
fun ResetPasswordScreen(
    viewModel: AuthViewModel,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val formState by viewModel.formState.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    Box(modifier = modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .imePadding(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(60.dp))

            Icon(
                Icons.Default.Lock,
                contentDescription = null,
                tint = PremiumColors.RoyalBlue,
                modifier = Modifier.size(60.dp)
            )

            Spacer(modifier = Modifier.height(20.dp))

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    "Reset Password",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = MaterialTheme.colorScheme.onBackground
                )
                Text(
                    "Enter your email and we'll send you a link to reset your password",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .shadow(
                        elevation = 25.dp,
                        shape = RoundedCornerShape(30.dp),
                        spotColor = PremiumColors.RoyalBlue.copy(alpha = 0.2f),
                        ambientColor = PremiumColors.Cyan.copy(alpha = 0.1f)
                    )
                    .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(30.dp))
                    .padding(25.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                PremiumTextField(
                    value = formState.email,
                    onValueChange = { viewModel.updateEmail(it) },
                    placeholder = "Email",
                    icon = Icons.Default.Email,
                    keyboardType = KeyboardType.Email,
                    imeAction = ImeAction.Done
                )

                errorMessage?.let {
                    val isSuccess = it.contains("sent", ignoreCase = true)
                    Text(
                        it,
                        style = MaterialTheme.typography.bodySmall,
                        color = if (isSuccess) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                PremiumButton(
                    "Send Reset Link",
                    onClick = { viewModel.resetPassword() },
                    enabled = formState.isValidEmail && !isLoading,
                    isLoading = isLoading
                )
            }

            Spacer(modifier = Modifier.height(30.dp))
        }

        IconButton(onClick = onNavigateBack, modifier = Modifier.padding(16.dp).align(Alignment.TopStart)) {
            @Suppress("DEPRECATION")
            Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = PremiumColors.RoyalBlue)
        }
    }
}
