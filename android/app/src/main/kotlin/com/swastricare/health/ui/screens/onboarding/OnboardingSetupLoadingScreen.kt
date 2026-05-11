package com.swastricare.health.ui.screens.onboarding

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.AppColors
import kotlinx.coroutines.delay

// ─────────────────────────────────────
// MARK: - Onboarding Setup Loading Screen
// ─────────────────────────────────────

@Composable
internal fun OnboardingSetupLoadingScreen(
    state: SubmitState,
    errorMessage: String?,
    onRetry: () -> Unit,
    onComplete: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = Color.White
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                when (state) {
                    SubmitState.SUBMITTING, SubmitState.IDLE -> {
                        CircularProgressIndicator(
                            modifier = Modifier.size(64.dp),
                            color = AITeal,
                            strokeWidth = 5.dp
                        )
                        Text(
                            text = "Setting up your profile…",
                            style = MaterialTheme.typography.titleMedium,
                            color = AppColors.onSurface
                        )
                    }

                    SubmitState.SUCCESS -> {
                        Icon(
                            imageVector = Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = AITeal,
                            modifier = Modifier.size(64.dp)
                        )
                        Text(
                            text = "All set!",
                            style = MaterialTheme.typography.titleMedium,
                            color = AppColors.onSurface
                        )
                        LaunchedEffect(Unit) {
                            delay(800)
                            onComplete()
                        }
                    }

                    SubmitState.ERROR -> {
                        Icon(
                            imageVector = Icons.Default.ErrorOutline,
                            contentDescription = null,
                            tint = Color(0xFFEF4444),
                            modifier = Modifier.size(64.dp)
                        )
                        Text(
                            text = errorMessage ?: "Something went wrong",
                            style = MaterialTheme.typography.bodyLarge,
                            color = AppColors.onSurface,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.padding(horizontal = 32.dp)
                        )
                        Spacer(Modifier.height(8.dp))
                        Button(
                            onClick = onRetry,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 24.dp)
                                .height(56.dp),
                            shape = RoundedCornerShape(16.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = AITeal,
                                contentColor = Color.White
                            )
                        ) {
                            Text("Retry")
                        }
                    }
                }
            }
        }
    }
}
