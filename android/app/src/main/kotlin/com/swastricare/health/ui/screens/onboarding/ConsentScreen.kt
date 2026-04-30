package com.swastricare.health.ui.screens.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.Spring
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.auth.components.PremiumColors

private val DarkText = Color(0xFF0F172A)
private val MutedText = Color(0xFF6B7280)
private val SubtleBorder = Color.Black.copy(alpha = 0.06f)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun ConsentScreen(
    onAccepted: () -> Unit,
    onBack: () -> Unit = {}
) {
    TrackScreen("Consent")
    var agreed by remember { mutableStateOf(false) }
    var showTermsSheet by remember { mutableStateOf(false) }
    var showPrivacySheet by remember { mutableStateOf(false) }

    BackHandler { onBack() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .windowInsetsPadding(WindowInsets.safeDrawing)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
        ) {
            // Top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp, bottom = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                CircleIconButton(
                    icon = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    background = Color.White,
                    border = SubtleBorder,
                    iconTint = DarkText,
                    onClick = onBack
                )
            }

            Spacer(Modifier.height(8.dp))

            // Hero illustration
            HeroIllustration()

            Spacer(Modifier.height(8.dp))

            Text(
                "Terms & Conditions",
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                color = DarkText,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(6.dp))

            Text(
                buildAnnotatedString {
                    withStyle(SpanStyle(color = MutedText)) {
                        append("Please read and accept the terms to continue using ")
                    }
                    withStyle(SpanStyle(color = PremiumColors.Teal, fontWeight = FontWeight.SemiBold)) {
                        append("SwasthiCare")
                    }
                    withStyle(SpanStyle(color = MutedText)) { append(".") }
                },
                fontSize = 13.sp,
                lineHeight = 18.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp)
            )

            Spacer(Modifier.height(20.dp))

            // List items
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                ConsentListItem(
                    icon = Icons.Default.Shield,
                    title = "Privacy Policy",
                    description = "Learn how we collect, use and protect your data.",
                    onClick = { showPrivacySheet = true }
                )
                ConsentListItem(
                    icon = Icons.Default.Description,
                    title = "Terms of Use",
                    description = "Understand the rules and guidelines for using our app.",
                    onClick = { showTermsSheet = true }
                )
            }

            Spacer(Modifier.height(18.dp))

            // Agreement row
            AgreementRow(
                checked = agreed,
                onToggle = { agreed = !agreed },
                onTermsClick = { showTermsSheet = true },
                onPrivacyClick = { showPrivacySheet = true }
            )

            Spacer(Modifier.height(14.dp))

            // Accept & Continue
            AcceptContinueButton(
                enabled = agreed,
                onClick = onAccepted
            )

            Spacer(Modifier.height(10.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.Lock,
                    contentDescription = null,
                    tint = MutedText,
                    modifier = Modifier.size(13.dp)
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    "Your data is safe with us",
                    fontSize = 12.sp,
                    color = MutedText
                )
            }

            Spacer(Modifier.height(8.dp))
        }
    }

    if (showTermsSheet) {
        ModalBottomSheet(
            onDismissRequest = { showTermsSheet = false },
            containerColor = Color.White
        ) {
            ConsentDetailContent(
                title = "Terms of Service",
                content = TERMS_TEXT,
                onDismiss = { showTermsSheet = false }
            )
        }
    }
    if (showPrivacySheet) {
        ModalBottomSheet(
            onDismissRequest = { showPrivacySheet = false },
            containerColor = Color.White
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
private fun CircleIconButton(
    icon: ImageVector,
    contentDescription: String?,
    background: Color,
    border: Color,
    iconTint: Color,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(background, CircleShape)
            .border(1.dp, border, CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            icon,
            contentDescription = contentDescription,
            tint = iconTint,
            modifier = Modifier.size(18.dp)
        )
    }
}

@Composable
private fun HeroIllustration() {
    val context = LocalContext.current
    val bitmap = remember {
        runCatching {
            context.assets.open("images/terms and condition icon.png").use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 160.dp, max = 200.dp),
        contentAlignment = Alignment.Center
    ) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 200.dp)
            )
        }
    }
}

@Composable
private fun ConsentListItem(
    icon: ImageVector,
    title: String,
    description: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White, RoundedCornerShape(14.dp))
            .border(1.dp, SubtleBorder, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(38.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(PremiumColors.Teal.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = PremiumColors.Teal,
                modifier = Modifier.size(18.dp)
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = DarkText
            )
            Spacer(Modifier.height(2.dp))
            Text(
                description,
                fontSize = 11.sp,
                lineHeight = 14.sp,
                color = MutedText
            )
        }
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = MutedText,
            modifier = Modifier.size(20.dp)
        )
    }
}

@Composable
private fun AgreementRow(
    checked: Boolean,
    onToggle: () -> Unit,
    onTermsClick: () -> Unit,
    onPrivacyClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onToggle
            )
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        val checkScale by animateFloatAsState(
            targetValue = if (checked) 1f else 0f,
            animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
            label = "checkScale"
        )
        Box(
            modifier = Modifier
                .size(22.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(
                    if (checked) PremiumColors.Teal else Color.Transparent,
                    RoundedCornerShape(6.dp)
                )
                .border(
                    1.5.dp,
                    if (checked) PremiumColors.Teal else MutedText.copy(alpha = 0.5f),
                    RoundedCornerShape(6.dp)
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.Check,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier
                    .size(14.dp)
                    .scale(checkScale)
            )
        }

        val annotated = buildAnnotatedString {
            withStyle(SpanStyle(color = DarkText)) {
                append("I have read and agree to the ")
            }
            withStyle(SpanStyle(color = PremiumColors.Teal, fontWeight = FontWeight.SemiBold)) {
                append("Terms of Use")
            }
            withStyle(SpanStyle(color = DarkText)) { append("\nand ") }
            withStyle(SpanStyle(color = PremiumColors.Teal, fontWeight = FontWeight.SemiBold)) {
                append("Privacy Policy")
            }
        }
        Text(
            text = annotated,
            fontSize = 13.sp,
            lineHeight = 18.sp,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun AcceptContinueButton(enabled: Boolean, onClick: () -> Unit) {
    val containerAlpha = if (enabled) 1f else 0.45f
    val haptics = LocalHapticFeedback.current
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp)
            .shadow(
                elevation = if (enabled) 12.dp else 0.dp,
                shape = RoundedCornerShape(28.dp),
                spotColor = PremiumColors.Teal.copy(alpha = 0.35f)
            )
            .background(
                brush = Brush.horizontalGradient(
                    PremiumColors.TealGreenGradient.map { it.copy(alpha = containerAlpha) }
                ),
                shape = RoundedCornerShape(28.dp)
            )
            .clip(RoundedCornerShape(28.dp))
            .clickable(enabled = enabled) {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onClick()
            },
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Text(
                "Accept & Continue",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Spacer(Modifier.width(10.dp))
            Icon(
                Icons.AutoMirrored.Filled.ArrowForward,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(18.dp)
            )
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
            color = DarkText,
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
                color = DarkText.copy(alpha = 0.8f)
            )
        }
        Spacer(Modifier.height(16.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(PremiumColors.Teal)
                .clickable(onClick = onDismiss),
            contentAlignment = Alignment.Center
        ) {
            Text(
                "Close",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
        }
    }
}

private const val TERMS_TEXT = """SwastriCare Terms of Service

Last updated: April 2026

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

Last updated: April 2026

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
