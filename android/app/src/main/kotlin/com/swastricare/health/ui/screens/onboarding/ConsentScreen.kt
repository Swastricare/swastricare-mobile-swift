package com.swastricare.health.ui.screens.onboarding

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Policy
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.screens.home.PremiumBackground
import com.swastricare.health.ui.screens.home.glass
import com.swastricare.health.ui.screens.home.lightBorder
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConsentScreen(onAccepted: () -> Unit) {
    var termsAccepted by remember { mutableStateOf(false) }
    var privacyAccepted by remember { mutableStateOf(false) }
    var dataProcessingAccepted by remember { mutableStateOf(false) }

    var showTermsSheet by remember { mutableStateOf(false) }
    var showPrivacySheet by remember { mutableStateOf(false) }

    val allAccepted = termsAccepted && privacyAccepted && dataProcessingAccepted

    // Staggered entrance animation
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { isVisible = true }

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(24.dp)
        ) {
            Spacer(Modifier.height(32.dp))

            Text(
                "Privacy & Consent",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onBackground
            )
            Spacer(Modifier.height(8.dp))
            Text(
                "Please review and accept the following to continue",
                fontSize = 14.sp,
                color = AppColors.onBackground.copy(alpha = 0.6f)
            )

            Spacer(Modifier.height(24.dp))

            // Three consent cards with staggered animation
            ConsentCard(
                icon = Icons.Default.Description,
                iconColor = Color(0xFF2196F3),
                title = "Terms of Service",
                description = "I agree to the SwastriCare Terms of Service governing app usage",
                isChecked = termsAccepted,
                onCheckedChange = { termsAccepted = it },
                onReadMore = { showTermsSheet = true },
                animDelay = 0,
                isVisible = isVisible
            )

            Spacer(Modifier.height(16.dp))

            ConsentCard(
                icon = Icons.Default.Policy,
                iconColor = Color(0xFF4CAF50),
                title = "Privacy Policy",
                description = "I have read and agree to the Privacy Policy regarding my personal data",
                isChecked = privacyAccepted,
                onCheckedChange = { privacyAccepted = it },
                onReadMore = { showPrivacySheet = true },
                animDelay = 150,
                isVisible = isVisible
            )

            Spacer(Modifier.height(16.dp))

            ConsentCard(
                icon = Icons.Default.Storage,
                iconColor = Color(0xFFFF9800),
                title = "Data Processing",
                description = "I consent to health data processing by AI for personalized insights",
                isChecked = dataProcessingAccepted,
                onCheckedChange = { dataProcessingAccepted = it },
                onReadMore = null,
                animDelay = 300,
                isVisible = isVisible
            )

            Spacer(Modifier.weight(1f))

            // Select All toggle
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) {
                        val newValue = !allAccepted
                        termsAccepted = newValue
                        privacyAccepted = newValue
                        dataProcessingAccepted = newValue
                    }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                val selectAllScale by animateFloatAsState(
                    targetValue = if (allAccepted) 1f else 0f,
                    animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
                    label = "selectAllCheck"
                )
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(
                            if (allAccepted) PrimaryColor else AppColors.onSurface.copy(alpha = 0.1f)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.Check,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier
                            .size(16.dp)
                            .scale(selectAllScale)
                    )
                }
                Text(
                    "Accept All",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface
                )
            }

            // Acceptance message
            Text(
                "By continuing, you agree to our Terms of Service, Privacy Policy, and consent to health data processing.",
                fontSize = 12.sp,
                color = AppColors.onBackground.copy(alpha = 0.5f),
                textAlign = TextAlign.Center,
                lineHeight = 16.sp,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .padding(bottom = 12.dp)
            )

            // Continue button
            Button(
                onClick = onAccepted,
                enabled = allAccepted,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = PrimaryColor,
                    disabledContainerColor = PrimaryColor.copy(alpha = 0.3f)
                ),
                shape = RoundedCornerShape(16.dp)
            ) {
                Text("Continue", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            }

            Spacer(Modifier.height(16.dp))
        }
    }

    // Terms of Service sheet
    if (showTermsSheet) {
        ModalBottomSheet(
            onDismissRequest = { showTermsSheet = false },
            containerColor = AppColors.surface
        ) {
            ConsentDetailContent(
                title = "Terms of Service",
                content = TERMS_TEXT,
                onDismiss = { showTermsSheet = false }
            )
        }
    }

    // Privacy Policy sheet
    if (showPrivacySheet) {
        ModalBottomSheet(
            onDismissRequest = { showPrivacySheet = false },
            containerColor = AppColors.surface
        ) {
            ConsentDetailContent(
                title = "Privacy Policy",
                content = PRIVACY_TEXT,
                onDismiss = { showPrivacySheet = false }
            )
        }
    }
}

@Composable
private fun ConsentCard(
    icon: ImageVector,
    iconColor: Color,
    title: String,
    description: String,
    isChecked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    onReadMore: (() -> Unit)?,
    animDelay: Int,
    isVisible: Boolean
) {
    val animAlpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500, delayMillis = animDelay),
        label = "cardAlpha"
    )
    val animOffset by animateIntAsState(
        targetValue = if (isVisible) 0 else 30,
        animationSpec = tween(500, delayMillis = animDelay),
        label = "cardOffset"
    )

    // Checkbox animation
    val checkScale by animateFloatAsState(
        targetValue = if (isChecked) 1f else 0f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "checkScale"
    )

    val borderColor = if (isChecked) iconColor else AppColors.onSurface.copy(alpha = 0.1f)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .alpha(animAlpha)
            .offset(y = animOffset.dp)
            .lightBorder(16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surfaceVariant.copy(alpha = 0.5f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onCheckedChange(!isChecked) }
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Custom animated checkbox
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(CircleShape)
                .background(
                    if (isChecked) iconColor else Color.Transparent
                )
                .then(
                    if (!isChecked) Modifier.background(
                        AppColors.onSurface.copy(alpha = 0.1f),
                        CircleShape
                    ) else Modifier
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.Check,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier
                    .size(16.dp)
                    .scale(checkScale)
            )
        }

        Column(modifier = Modifier.weight(1f)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(icon, null, tint = iconColor, modifier = Modifier.size(18.dp))
                Text(
                    title,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface
                )
            }
            Spacer(Modifier.height(4.dp))
            Text(
                description,
                fontSize = 12.sp,
                color = AppColors.onSurface.copy(alpha = 0.5f),
                lineHeight = 16.sp
            )
        }

        if (onReadMore != null) {
            IconButton(
                onClick = onReadMore,
                modifier = Modifier.size(32.dp)
            ) {
                Icon(
                    Icons.Default.ChevronRight, "Read More",
                    tint = AppColors.onSurface.copy(alpha = 0.4f)
                )
            }
        }
    }
}

@Composable
private fun ConsentDetailContent(
    title: String,
    content: String,
    onDismiss: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(bottom = 32.dp)
    ) {
        Text(
            title,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(bottom = 16.dp)
        )
        Column(
            modifier = Modifier
                .weight(1f, fill = false)
                .heightIn(max = 400.dp)
                .verticalScroll(rememberScrollState())
        ) {
            Text(
                content,
                fontSize = 14.sp,
                lineHeight = 20.sp,
                color = AppColors.onSurface.copy(alpha = 0.8f)
            )
        }
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = onDismiss,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
        ) {
            Text("Close")
        }
    }
}

// ─────────────────────────────────────
// MARK: - Content Text
// ─────────────────────────────────────

private const val TERMS_TEXT = """SwastriCare Terms of Service

Last updated: March 2026

1. ACCEPTANCE OF TERMS
By downloading, installing, or using SwastriCare, you agree to these Terms of Service.

2. USE OF SERVICE
SwastriCare is a personal health tracking app. You must be at least 13 years old to use this app. You are responsible for maintaining the confidentiality of your account.

3. HEALTH DISCLAIMER
SwastriCare provides general health information and tracking tools only. It is NOT a medical device and should NOT be used for medical diagnosis or treatment. Always consult a qualified healthcare professional for medical advice.

4. AI FEATURES
Swastri AI provides health insights using AI models. These are for informational purposes only and may not always be accurate. Never make medical decisions based solely on AI suggestions.

5. USER DATA
You retain ownership of all health data you enter. We process your data as described in our Privacy Policy.

6. TERMINATION
We may suspend or terminate your account for violation of these terms. You may delete your account at any time from Profile settings."""

private const val PRIVACY_TEXT = """SwastriCare Privacy Policy

Last updated: March 2026

DATA WE COLLECT
• Health data: steps, heart rate, calories, medication logs, diet entries, menstrual cycle data
• Profile data: name, date of birth, gender, height, weight, blood type
• Documents: medical records you upload to your Vault
• Usage data: app interactions for improving the experience

HOW WE USE YOUR DATA
• To display your health dashboard and trends
• To power Swastri AI health insights (processed by Google Gemini/MedGemma)
• To sync data across your devices via Supabase

DATA STORAGE
• All data is stored on Supabase servers (AWS ap-south-1 region, India)
• We comply with India's Digital Personal Data Protection Act (DPDPA) 2023
• Data is encrypted in transit and at rest

YOUR RIGHTS
• Access: View all your data in the app
• Delete: Delete your account and all data from Profile settings
• Export: Contact support for a data export
• Correction: Update your profile data at any time

THIRD PARTIES
• Google Gemini/MedGemma: processes AI queries (no data stored)
• Firebase: analytics and crash reporting
• Health Connect: syncs with Android health data (with your permission)

CONTACT
For privacy concerns, contact: privacy@swastricare.com"""
