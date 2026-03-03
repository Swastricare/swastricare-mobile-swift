package com.swasthicare.mobile.ui.screens.onboarding

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.ui.theme.PrimaryColor
import com.swasthicare.mobile.ui.theme.SecondaryColor

data class OnboardingPage(
    val title: String,
    val subtitle: String,
    val emoji: String,
    val accentColor: Color
)

private val pages = listOf(
    OnboardingPage("Track Your Health", "Monitor vitals, hydration, and medications all in one place.", "\uD83C\uDFE5", PrimaryColor),
    OnboardingPage("AI-Powered Insights", "Get personalized health advice from Swastri AI, powered by MedGemma.", "\uD83E\uDD16", SecondaryColor),
    OnboardingPage("Secure Health Vault", "Store prescriptions, lab reports, and medical documents safely.", "\uD83D\uDD12", Color(0xFF5856D6)),
    OnboardingPage("Your Family, Together", "Manage health for your entire family from one account.", "\uD83D\uDC68\u200D\uD83D\uDC69\u200D\uD83D\uDC67", Color(0xFFFF9500))
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun OnboardingScreen(onFinished: () -> Unit) {
    val pagerState = rememberPagerState(pageCount = { pages.size })
    val isLastPage = pagerState.currentPage == pages.size - 1

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize()
        ) { page ->
            val p = pages[page]
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(text = p.emoji, fontSize = 80.sp)
                Spacer(Modifier.height(32.dp))
                Text(
                    text = p.title,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                    color = p.accentColor
                )
                Spacer(Modifier.height(16.dp))
                Text(
                    text = p.subtitle,
                    fontSize = 16.sp,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                )
            }
        }

        // Page indicator dots
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 140.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(pages.size) { i ->
                val isSelected = pagerState.currentPage == i
                Box(
                    modifier = Modifier
                        .size(if (isSelected) 24.dp else 8.dp, 8.dp)
                        .clip(CircleShape)
                        .background(if (isSelected) PrimaryColor else Color.Gray.copy(alpha = 0.4f))
                )
            }
        }

        // Next / Get Started button
        Button(
            onClick = onFinished,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 32.dp, vertical = 48.dp)
                .fillMaxWidth()
                .height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
        ) {
            Text(
                text = if (isLastPage) "Get Started" else "Next",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}
