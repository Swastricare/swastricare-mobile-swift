package com.swasthicare.mobile.ui.screens.auth

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.draw.shadow
import androidx.compose.foundation.border
import androidx.compose.ui.graphics.Brush
import com.swasthicare.mobile.ui.screens.auth.components.*
import kotlinx.coroutines.delay

@Composable
fun ResetPasswordScreen(
    viewModel: AuthViewModel,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val formState by viewModel.formState.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    
    var isAnimating by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        delay(100)
        isAnimating = true
    }
    
    Box(modifier = modifier.fillMaxSize()) {
        PremiumBackground()
        
        Column(
            modifier = Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            AnimatedVisibility(
                visible = isAnimating,
                enter = fadeIn(tween(800, easing = EaseOut))
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(30.dp)
                ) {
                    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
                    val scale by infiniteTransition.animateFloat(
                        initialValue = 1f,
                        targetValue = 1.1f,
                        animationSpec = infiniteRepeatable(tween(1000, easing = EaseInOut), RepeatMode.Reverse),
                        label = "pulse_scale"
                    )
                    
                    Icon(Icons.Default.Lock, contentDescription = null, tint = PremiumColors.RoyalBlue, modifier = Modifier.size(60.dp).scale(scale))
                    
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Reset Password", fontSize = 24.sp, fontWeight = FontWeight.ExtraBold, color = PremiumColors.TextDark)
                        Text("Enter your email and we'll send you a link to reset your password", style = MaterialTheme.typography.bodyMedium, color = PremiumColors.TextGrey, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 16.dp))
                    }
                    
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
                            Text(it, style = MaterialTheme.typography.bodySmall, color = if (it.contains("sent")) Color.Green else Color.Red, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                        }
                        
                        PremiumButton("Send Reset Link", onClick = { viewModel.resetPassword() }, enabled = formState.isValidEmail && !isLoading, isLoading = isLoading)
                    }
                }
            }
        }
        
        IconButton(onClick = onNavigateBack, modifier = Modifier.padding(16.dp).align(Alignment.TopStart)) {
            @Suppress("DEPRECATION")
            Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = PremiumColors.RoyalBlue)
        }
    }
}
