package com.swastricare.health.ui.screens.onboarding

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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor
import com.swastricare.health.ui.theme.SecondaryColor

data class OnboardingPage(
    val title: String,
    val subtitle: String,
    val illustrationAsset: String,
    val accentColor: Color
)

private val pages = listOf(
    OnboardingPage(
        title = "Stay Hydrated",
        subtitle = "Track your daily water intake and hit your hydration goals.",
        illustrationAsset = "illustrations/drinking water 2.png",
        accentColor = PrimaryColor
    ),
    OnboardingPage(
        title = "Manage Medications",
        subtitle = "Never miss a dose with smart reminders and adherence tracking.",
        illustrationAsset = "illustrations/medication - holding pill bottle .png",
        accentColor = SecondaryColor
    ),
    OnboardingPage(
        title = "Track Your Diet",
        subtitle = "Log meals, scan food, and hit your daily nutrition targets.",
        illustrationAsset = "illustrations/eating food.png",
        accentColor = Color(0xFF5856D6)
    ),
    OnboardingPage(
        title = "Rest & Recover",
        subtitle = "Monitor sleep and recovery to feel your best every day.",
        illustrationAsset = "illustrations/sleeping 2.png",
        accentColor = Color(0xFFFF9500)
    )
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun OnboardingScreen(onFinished: () -> Unit) {
    val pagerState = rememberPagerState(pageCount = { pages.size })
    val isLastPage = pagerState.currentPage == pages.size - 1

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.background)
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
                AsyncImage(
                    model = "file:///android_asset/${p.illustrationAsset}",
                    contentDescription = null,
                    modifier = Modifier.size(280.dp),
                    contentScale = ContentScale.Fit
                )
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
                    color = AppColors.onSurface.copy(alpha = 0.7f)
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
