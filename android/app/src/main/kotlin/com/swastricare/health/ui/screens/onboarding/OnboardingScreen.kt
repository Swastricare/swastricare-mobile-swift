package com.swastricare.health.ui.screens.onboarding

import androidx.compose.animation.core.*
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.Dp
import com.swastricare.health.ui.components.TrackScreen
import com.swastricare.health.ui.screens.auth.components.PremiumColors
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch

private val DarkText = Color(0xFF0F172A)
private val MutedText = Color(0xFF6B7280)

private data class FeatureCardData(
    val iconAsset: String,
    val title: String,
    val description: String
)

private data class OnboardingPageData(
    val illustrationAsset: String,
    val titlePrefix: String,
    val titleItalic: String,
    val titleSeparator: String,
    val titleHighlight: String,
    val subtitle: String,
    val features: List<FeatureCardData> = emptyList()
)

private val pages = listOf(
    OnboardingPageData(
        illustrationAsset = "images/onboarding illustration.png",
        titlePrefix = "Your family's ",
        titleItalic = "health",
        titleSeparator = ",\n",
        titleHighlight = "all in one place",
        subtitle = "Track health records, manage appointments, get reminders and care better—together.",
        features = listOf(
            FeatureCardData(
                iconAsset = "images/smart health records.png",
                title = "Smart Health Records",
                description = "Store and access your family's health records securely."
            ),
            FeatureCardData(
                iconAsset = "images/appoinments made easy.png",
                title = "Appointments Made Easy",
                description = "Book, manage and get reminders for all your appointments."
            ),
            FeatureCardData(
                iconAsset = "images/secure & private.png",
                title = "Secure & Private",
                description = "Your data is encrypted and 100% private. Always protected."
            )
        )
    ),
    OnboardingPageData(
        illustrationAsset = "images/onboarding 1.png",
        titlePrefix = "Your ",
        titleItalic = "Health",
        titleSeparator = ",\n",
        titleHighlight = "All in One Place",
        subtitle = "Track, manage, and improve your health with personalized insights and smart tools."
    ),
    OnboardingPageData(
        illustrationAsset = "images/onboarding2.png",
        titlePrefix = "Smarter ",
        titleItalic = "Insights",
        titleSeparator = ",\n",
        titleHighlight = "Better You",
        subtitle = "Get AI-powered insights, reminders, and support that help you build healthy habits effortlessly."
    )
)

@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class, ExperimentalLayoutApi::class)
@Composable
fun OnboardingScreen(
    onFinished: () -> Unit,
    onSignIn: () -> Unit = onFinished
) {
    TrackScreen("Onboarding")
    val pagerState = rememberPagerState(pageCount = { pages.size })
    val currentPage = pagerState.currentPage
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current

    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage }
            .drop(1)
            .collect { haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove) }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .windowInsetsPadding(WindowInsets.safeDrawing)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopBar(
                showSkip = currentPage < pages.size - 1,
                onSkip = onFinished
            )

            HorizontalPager(
                state = pagerState,
                modifier = Modifier.weight(1f)
            ) { pageIndex ->
                OnboardingPageContent(data = pages[pageIndex])
            }

            BottomControls(
                pageCount = pages.size,
                currentPage = currentPage,
                isLast = currentPage == pages.size - 1,
                onContinue = {
                    if (currentPage == pages.size - 1) onFinished()
                    else scope.launch { pagerState.animateScrollToPage(currentPage + 1) }
                },
                onSignIn = onSignIn
            )
        }
    }
}

@Composable
private fun TopBar(showSkip: Boolean, onSkip: () -> Unit) {
    val context = LocalContext.current
    val logoBitmap = remember {
        runCatching {
            context.assets.open("icons/swastricare icon.png").use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (logoBitmap != null) {
                Image(
                    bitmap = logoBitmap.asImageBitmap(),
                    contentDescription = "SwasthiCare",
                    modifier = Modifier.size(36.dp)
                )
                Spacer(Modifier.width(8.dp))
            }
            Column {
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        "Swasthi",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = DarkText
                    )
                    Text(
                        "Care",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = PremiumColors.Teal
                    )
                }
                Text(
                    "Your Family, Our Care",
                    fontSize = 11.sp,
                    color = MutedText
                )
            }
        }

        Box(
            modifier = Modifier
                .alpha(if (showSkip) 1f else 0f)
                .clip(CircleShape)
                .clickable(enabled = showSkip, onClick = onSkip)
                .padding(horizontal = 18.dp, vertical = 8.dp)
        ) {
            Text(
                "Skip",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = PremiumColors.Teal
            )
        }
    }
}

@Composable
private fun OnboardingPageContent(data: OnboardingPageData) {
    val context = LocalContext.current
    val illustrationBitmap = remember(data.illustrationAsset) {
        runCatching {
            context.assets.open(data.illustrationAsset).use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }

    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        val isFamilyHero = data.features.isNotEmpty()

        // Hero illustration
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .clipToBounds(),
            contentAlignment = Alignment.Center
        ) {
            if (illustrationBitmap != null) {
                if (isFamilyHero) {
                    // Page 1: exact image with horizontal-edge fade applied to the image itself
                    Image(
                        bitmap = illustrationBitmap.asImageBitmap(),
                        contentDescription = null,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 320.dp)
                            .align(Alignment.Center)
                            .drawWithContent {
                                drawContent()
                                drawRect(
                                    brush = Brush.horizontalGradient(
                                        colorStops = arrayOf(
                                            0f to Color.White,
                                            0.28f to Color.Transparent,
                                            0.72f to Color.Transparent,
                                            1f to Color.White
                                        )
                                    )
                                )
                            }
                    )
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(56.dp)
                            .align(Alignment.TopCenter)
                            .background(
                                Brush.verticalGradient(
                                    listOf(Color.White, Color.Transparent)
                                )
                            )
                    )
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(56.dp)
                            .align(Alignment.BottomCenter)
                            .background(
                                Brush.verticalGradient(
                                    listOf(Color.Transparent, Color.White)
                                )
                            )
                    )
                } else {
                    // Pages 2/3: simple centered illustration, no blend, no crop
                    Image(
                        bitmap = illustrationBitmap.asImageBitmap(),
                        contentDescription = null,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 24.dp)
                    )
                }
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                buildAnnotatedString {
                    withStyle(SpanStyle(color = DarkText, fontWeight = FontWeight.Bold)) {
                        append(data.titlePrefix)
                    }
                    withStyle(SpanStyle(color = DarkText, fontWeight = FontWeight.Bold, fontStyle = FontStyle.Italic)) {
                        append(data.titleItalic)
                    }
                    withStyle(SpanStyle(color = DarkText, fontWeight = FontWeight.Bold)) {
                        append(data.titleSeparator)
                    }
                    withStyle(SpanStyle(color = PremiumColors.Teal, fontWeight = FontWeight.Bold)) {
                        append(data.titleHighlight)
                    }
                },
                fontSize = 24.sp,
                lineHeight = 30.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(10.dp))

            Text(
                data.subtitle,
                fontSize = 13.sp,
                lineHeight = 19.sp,
                color = MutedText,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp)
            )

            if (data.features.isNotEmpty()) {
                Spacer(Modifier.height(18.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(IntrinsicSize.Max),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    data.features.forEach { feature ->
                        FeatureCard(
                            data = feature,
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                        )
                    }
                }
            }

            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
private fun FeatureCard(data: FeatureCardData, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val iconBitmap = remember(data.iconAsset) {
        runCatching {
            context.assets.open(data.iconAsset).use {
                android.graphics.BitmapFactory.decodeStream(it)
            }
        }.getOrNull()
    }

    Column(
        modifier = modifier
            .background(Color.White, RoundedCornerShape(16.dp))
            .border(1.dp, Color.Black.copy(alpha = 0.05f), RoundedCornerShape(16.dp))
            .padding(horizontal = 10.dp, vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        if (iconBitmap != null) {
            Image(
                bitmap = iconBitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.size(44.dp)
            )
        } else {
            Spacer(Modifier.size(44.dp))
        }
        Spacer(Modifier.height(10.dp))
        Text(
            data.title,
            fontSize = 12.sp,
            lineHeight = 15.sp,
            fontWeight = FontWeight.Bold,
            color = DarkText,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(6.dp))
        Text(
            data.description,
            fontSize = 10.sp,
            lineHeight = 14.sp,
            color = MutedText,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun BottomControls(
    pageCount: Int,
    currentPage: Int,
    isLast: Boolean,
    onContinue: () -> Unit,
    onSignIn: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .padding(bottom = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            repeat(pageCount) { i ->
                val selected = currentPage == i
                val width: Dp by animateDpAsState(
                    targetValue = if (selected) 18.dp else 6.dp,
                    animationSpec = spring(stiffness = Spring.StiffnessMedium),
                    label = "dotWidth$i"
                )
                Box(
                    modifier = Modifier
                        .size(width = width, height = 6.dp)
                        .clip(CircleShape)
                        .background(
                            if (selected) PremiumColors.Teal
                            else PremiumColors.Teal.copy(alpha = 0.18f)
                        )
                )
            }
        }

        PrimaryActionButton(
            label = if (isLast) "Get Started" else "Continue",
            onClick = onContinue
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                "Already have an account? ",
                fontSize = 13.sp,
                color = MutedText
            )
            Text(
                "Sign In",
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = PremiumColors.Teal,
                modifier = Modifier.clickable { onSignIn() }
            )
        }
    }
}

@Composable
private fun PrimaryActionButton(label: String, onClick: () -> Unit) {
    val haptics = LocalHapticFeedback.current
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp)
            .shadow(
                elevation = 12.dp,
                shape = RoundedCornerShape(28.dp),
                spotColor = PremiumColors.Teal.copy(alpha = 0.35f)
            )
            .background(
                brush = Brush.horizontalGradient(PremiumColors.TealGreenGradient),
                shape = RoundedCornerShape(28.dp)
            )
            .clip(RoundedCornerShape(28.dp))
            .clickable {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onClick()
            },
        contentAlignment = Alignment.Center
    ) {
        Text(
            label,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
    }
}
