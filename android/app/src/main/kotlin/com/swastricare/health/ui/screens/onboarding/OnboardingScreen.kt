package com.swastricare.health.ui.screens.onboarding

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.ui.theme.PrimaryColor
import kotlinx.coroutines.launch

// Per-page accent colors
private val pageAccents = listOf(
    Color(0xFF7C3AED), // Purple — AI
    Color(0xFF0EA5E9), // Sky Blue — Vault
    Color(0xFF22C55E)  // Green — Activity
)

private data class OnboardingPageData(
    val title: String,
    val highlight: String,
    val subtitle: String
)

private val pages = listOf(
    OnboardingPageData(
        title = "Your health AI,",
        highlight = "always ready",
        subtitle = "Ask about symptoms, medications, or diet in English or Hindi. Powered by medical AI."
    ),
    OnboardingPageData(
        title = "Your reports,",
        highlight = "safe forever",
        subtitle = "Store prescriptions, lab results, and X-rays. Share with any doctor in seconds."
    ),
    OnboardingPageData(
        title = "Track your activity,",
        highlight = "every step counts",
        subtitle = "Monitor your daily steps, distance, and calories to build a healthier routine."
    )
)

@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun OnboardingScreen(onFinished: () -> Unit) {
    val pagerState = rememberPagerState(pageCount = { pages.size })
    val currentPage = pagerState.currentPage
    val scope = rememberCoroutineScope()

    var controlsVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { controlsVisible = true }
    val controlsAlpha by animateFloatAsState(
        targetValue = if (controlsVisible) 1f else 0f,
        animationSpec = tween(400, delayMillis = 800),
        label = "controlsAlpha"
    )

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Column(modifier = Modifier.fillMaxSize()) {
            // Top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 24.dp, vertical = 12.dp)
                    .alpha(controlsAlpha),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "${currentPage + 1} of ${pages.size}",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.Gray
                )
                if (currentPage < pages.size - 1) {
                    TextButton(onClick = onFinished) {
                        Text("Skip", fontSize = 15.sp, fontWeight = FontWeight.Medium, color = Color.Gray)
                    }
                } else {
                    Spacer(Modifier.width(48.dp))
                }
            }

            // Pager
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.weight(1f)
            ) { pageIndex ->
                OnboardingPageContent(
                    data = pages[pageIndex],
                    accentColor = pageAccents[pageIndex],
                    isActive = currentPage == pageIndex,
                    pageIndex = pageIndex
                )
            }

            // Bottom controls
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(bottom = 50.dp)
                    .alpha(controlsAlpha),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                // Capsule dot indicators
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    repeat(pages.size) { i ->
                        val isSelected = currentPage == i
                        val width by animateDpAsState(
                            targetValue = if (isSelected) 20.dp else 6.dp,
                            animationSpec = spring(stiffness = Spring.StiffnessMedium),
                            label = "dotWidth$i"
                        )
                        Box(
                            modifier = Modifier
                                .size(width, 6.dp)
                                .clip(CircleShape)
                                .background(
                                    if (isSelected) pageAccents[currentPage]
                                    else Color.Gray.copy(alpha = 0.3f)
                                )
                        )
                    }
                }

                // Next / Get Started
                if (currentPage < pages.size - 1) {
                    Button(
                        onClick = {
                            scope.launch { pagerState.animateScrollToPage(currentPage + 1) }
                        },
                        modifier = Modifier
                            .width(180.dp)
                            .height(52.dp),
                        shape = CircleShape,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = pageAccents[currentPage]
                        )
                    ) {
                        Text("Next", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    }
                } else {
                    GetStartedButton(onFinished = onFinished)
                    Text(
                        "Your data stays on your device. We never sell your information.",
                        fontSize = 10.sp,
                        color = Color.Gray,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 32.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun OnboardingPageContent(
    data: OnboardingPageData,
    accentColor: Color,
    isActive: Boolean,
    pageIndex: Int
) {
    var triggered by remember { mutableStateOf(false) }

    LaunchedEffect(isActive) {
        if (isActive) {
            kotlinx.coroutines.delay(50)
            triggered = true
        } else {
            triggered = false
        }
    }

    val headlineOffsetY by animateDpAsState(
        targetValue = if (triggered) 0.dp else 20.dp,
        animationSpec = spring(dampingRatio = 0.8f, stiffness = 300f),
        label = "headlineY"
    )
    val headlineAlpha by animateFloatAsState(
        targetValue = if (triggered) 1f else 0f,
        animationSpec = spring(dampingRatio = 0.8f, stiffness = 300f),
        label = "headlineAlpha"
    )
    val subtitleOffsetY by animateDpAsState(
        targetValue = if (triggered) 0.dp else 15.dp,
        animationSpec = spring(dampingRatio = 0.8f, stiffness = 250f),
        label = "subtitleY"
    )
    val subtitleAlpha by animateFloatAsState(
        targetValue = if (triggered) 1f else 0f,
        animationSpec = tween(400, delayMillis = 100),
        label = "subtitleAlpha"
    )
    val cardOffsetY by animateDpAsState(
        targetValue = if (triggered) 0.dp else 30.dp,
        animationSpec = spring(dampingRatio = 0.8f, stiffness = 200f),
        label = "cardY"
    )
    val cardAlpha by animateFloatAsState(
        targetValue = if (triggered) 1f else 0f,
        animationSpec = tween(400, delayMillis = 200),
        label = "cardAlpha"
    )
    val cardScale by animateFloatAsState(
        targetValue = if (triggered) 1f else 0.95f,
        animationSpec = spring(dampingRatio = 0.8f, stiffness = 200f),
        label = "cardScale"
    )
    val underlineWidth by animateDpAsState(
        targetValue = if (triggered) 60.dp else 0.dp,
        animationSpec = tween(500, delayMillis = 300, easing = FastOutSlowInEasing),
        label = "underlineWidth"
    )

    Box(
        modifier = Modifier.fillMaxSize()
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
        ) {
            Spacer(Modifier.height(16.dp))

            // Headline block
            Column(
                modifier = Modifier
                    .offset(y = headlineOffsetY)
                    .alpha(headlineAlpha)
                    .padding(bottom = 8.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(data.title, fontSize = 26.sp, fontWeight = FontWeight.Bold)
                Text(data.highlight, fontSize = 26.sp, fontWeight = FontWeight.Bold, color = accentColor)
                Box(
                    modifier = Modifier
                        .padding(top = 4.dp)
                        .width(underlineWidth)
                        .height(3.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(accentColor.copy(alpha = 0.5f))
                )
            }

            // Subtitle
            Text(
                data.subtitle,
                fontSize = 13.sp,
                lineHeight = 20.sp,
                color = Color.Gray,
                modifier = Modifier
                    .offset(y = subtitleOffsetY)
                    .alpha(subtitleAlpha)
                    .padding(bottom = 24.dp)
            )

            // Preview card
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .offset(y = cardOffsetY)
                    .alpha(cardAlpha)
                    .scale(cardScale)
            ) {
                when (pageIndex) {
                    0 -> AIPreviewCard(isActive = isActive)
                    1 -> VaultPreviewCard(isActive = isActive)
                    2 -> ActivityPreviewCard(isActive = isActive)
                }
            }

            Spacer(Modifier.height(16.dp))
        }
    }
}

@Composable
private fun GetStartedButton(onFinished: () -> Unit) {
    val infiniteTransition = rememberInfiniteTransition(label = "glow")
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.2f,
        targetValue = 0.5f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "glowAlpha"
    )
    val scale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.02f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "glowScale"
    )

    Button(
        onClick = onFinished,
        modifier = Modifier
            .width(180.dp)
            .height(52.dp)
            .scale(scale)
            .shadow(
                elevation = 16.dp,
                shape = CircleShape,
                ambientColor = PrimaryColor.copy(alpha = glowAlpha),
                spotColor = PrimaryColor.copy(alpha = glowAlpha)
            ),
        shape = CircleShape,
        colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
        contentPadding = PaddingValues(0.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.horizontalGradient(listOf(PrimaryColor, Color(0xFF0EA5E9))),
                    CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Text("Get Started", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White)
        }
    }
}

@Composable
private fun PremiumBackground() {
    val isDark = isSystemInDarkTheme()
    Canvas(modifier = Modifier.fillMaxSize()) {
        drawRect(if (isDark) Color.Black else Color.White)
        // Top-right orb — indigo
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    Color(0xFF4F46E5).copy(alpha = if (isDark) 0.25f else 0.12f),
                    Color.Transparent
                ),
                center = Offset(size.width * 0.85f, size.height * 0.1f),
                radius = size.width * 0.55f
            ),
            center = Offset(size.width * 0.85f, size.height * 0.1f),
            radius = size.width * 0.55f
        )
        // Bottom-left orb — purple
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    Color(0xFF7C3AED).copy(alpha = if (isDark) 0.2f else 0.09f),
                    Color.Transparent
                ),
                center = Offset(size.width * 0.15f, size.height * 0.85f),
                radius = size.width * 0.6f
            ),
            center = Offset(size.width * 0.15f, size.height * 0.85f),
            radius = size.width * 0.6f
        )
    }
}
