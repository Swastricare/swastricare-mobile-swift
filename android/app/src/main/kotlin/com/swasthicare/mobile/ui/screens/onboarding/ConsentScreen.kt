package com.swasthicare.mobile.ui.screens.onboarding

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.ui.theme.PrimaryColor

@Composable
fun ConsentScreen(onAccepted: () -> Unit) {
    var hasScrolledToBottom by remember { mutableStateOf(false) }
    val scrollState = rememberScrollState()

    // Enable button after user scrolls to near-bottom
    LaunchedEffect(scrollState.value) {
        if (scrollState.maxValue > 0 && scrollState.value >= scrollState.maxValue * 0.8f) {
            hasScrolledToBottom = true
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp)
    ) {
        Text(
            "Privacy & Consent",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 48.dp, bottom = 24.dp)
        )

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(scrollState)
        ) {
            Text(
                text = """
SwasthiCare Privacy Policy (Summary)

Last updated: March 2026

DATA WE COLLECT
${"\u2022"} Health data: steps, heart rate, calories, medication logs, diet entries
${"\u2022"} Profile data: name, date of birth, gender, height, weight, blood type
${"\u2022"} Documents: medical records you upload to your Vault
${"\u2022"} Usage data: app interactions for improving the experience

HOW WE USE YOUR DATA
${"\u2022"} To display your health dashboard and trends
${"\u2022"} To power Swastri AI health insights (processed by Google Gemini/MedGemma)
${"\u2022"} To sync data across your devices via Supabase

DATA STORAGE
${"\u2022"} All data is stored on Supabase servers (AWS ap-south-1 region, India)
${"\u2022"} We comply with India's Digital Personal Data Protection Act (DPDPA) 2023

YOUR RIGHTS
${"\u2022"} Access: View all your data in the app
${"\u2022"} Delete: Delete your account and all data from Profile settings
${"\u2022"} Export: Contact support for a data export

AI DISCLAIMER
${"\u2022"} Swastri AI provides general health information only
${"\u2022"} It is NOT a substitute for professional medical advice
${"\u2022"} Always consult a qualified doctor for medical decisions

By tapping "I Agree", you consent to this privacy policy and terms of service.
                """.trimIndent(),
                fontSize = 14.sp,
                lineHeight = 20.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f)
            )
        }

        Spacer(Modifier.height(16.dp))

        if (!hasScrolledToBottom) {
            Text(
                "Scroll down to read and accept",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)
            )
        }

        Button(
            onClick = onAccepted,
            enabled = hasScrolledToBottom,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
        ) {
            Text("I Agree & Continue", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }

        Spacer(Modifier.height(16.dp))
    }
}
