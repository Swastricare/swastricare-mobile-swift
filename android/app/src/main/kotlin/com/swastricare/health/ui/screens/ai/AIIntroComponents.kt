package com.swastricare.health.ui.screens.ai

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Coffee
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Insights
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.SelfImprovement
import androidx.compose.material.icons.filled.Snooze
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.AIPersonality
import com.swastricare.health.data.models.QuickAction
import com.swastricare.health.ui.theme.AppColors
import java.util.Calendar

// ─────────────────────────────────────
// Icon resolver: maps iOS SF Symbol tokens → Material icons.
// Keeps the data layer platform-agnostic while letting the UI stay strongly typed.
// ─────────────────────────────────────

internal fun resolveSfIcon(token: String): ImageVector = when (token) {
    "sparkles" -> Icons.Filled.AutoAwesome
    "figure.run", "figure.cooldown" -> Icons.Filled.DirectionsRun
    "figure.walk" -> Icons.Filled.DirectionsWalk
    "leaf.fill" -> Icons.Filled.Spa
    "brain.head.profile" -> Icons.Filled.Psychology
    "moon.stars.fill" -> Icons.Filled.NightsStay
    "moon.zzz.fill" -> Icons.Filled.Snooze
    "bed.double.fill" -> Icons.Filled.Bedtime
    "sunrise.fill" -> Icons.Filled.WbSunny
    "cup.and.saucer.fill" -> Icons.Filled.Coffee
    "heart.text.square.fill" -> Icons.Filled.Insights
    "heart.fill" -> Icons.Rounded.Favorite
    "chart.bar.fill" -> Icons.Filled.BarChart
    "fork.knife" -> Icons.Filled.Restaurant
    "calendar" -> Icons.Filled.CalendarToday
    "drop.fill" -> Icons.Filled.WaterDrop
    "flame.fill" -> Icons.Filled.LocalFireDepartment
    "waveform.path.ecg" -> Icons.Filled.Insights
    else -> Icons.Filled.AutoAwesome
}

// ─────────────────────────────────────
// Greeting — time-aware, matches iOS AIView.greeting/greetingSubtitle.
// ─────────────────────────────────────

@Composable
fun AIGreetingBlock(userName: String?, modifier: Modifier = Modifier) {
    val firstName = userName?.substringBefore(' ')?.takeIf { it.isNotBlank() } ?: "there"
    val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
    val (title, subtitle) = when (hour) {
        in 5..11 -> "Good morning, $firstName" to
            "How are you feeling today?\nLet's check in on your health."
        in 12..16 -> "Good afternoon, $firstName" to
            "Need a midday health check?\nI'm here to help."
        in 17..21 -> "Good evening, $firstName" to
            "Let's review your day.\nAsk me anything about your health."
        else -> "Hey, $firstName" to
            "Can't sleep?\nI'm here if you need health advice."
    }
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(
            text = title,
            fontSize = 26.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = Poppins,
            color = AppColors.onBackground
        )
        Text(
            text = subtitle,
            fontSize = 14.sp,
            fontFamily = Poppins,
            color = AppColors.onSurfaceVariant,
            lineHeight = 19.sp,
            modifier = Modifier.padding(horizontal = 32.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
    }
}

// ─────────────────────────────────────
// Health Vitals Strip — steps / BPM / kcal pills on a glass pill.
// Tapping a pill seeds a prompt and sends the message (iOS: onTapMetric).
// ─────────────────────────────────────

@Composable
fun HealthVitalsStrip(
    steps: Int,
    heartRate: Int,
    calories: Int,
    onAskAbout: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.surface)
            .padding(vertical = 6.dp, horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        VitalPill(
            icon = Icons.Filled.DirectionsWalk,
            tint = Color(0xFF22C55E),
            value = if (steps >= 1000) String.format("%.1fk", steps / 1000f) else steps.toString(),
            label = "Steps",
            modifier = Modifier.weight(1f),
            onClick = { onAskAbout("How are my steps today? Am I on track?") }
        )
        Divider(
            modifier = Modifier
                .height(22.dp)
                .width(1.dp),
            color = AppColors.divider.copy(alpha = 0.4f)
        )
        VitalPill(
            icon = Icons.Rounded.Favorite,
            tint = Color(0xFFEF4444),
            value = if (heartRate > 0) heartRate.toString() else "--",
            label = "BPM",
            modifier = Modifier.weight(1f),
            onClick = { onAskAbout("Analyze my heart rate. Is it healthy?") }
        )
        Divider(
            modifier = Modifier
                .height(22.dp)
                .width(1.dp),
            color = AppColors.divider.copy(alpha = 0.4f)
        )
        VitalPill(
            icon = Icons.Filled.LocalFireDepartment,
            tint = Color(0xFFF97316),
            value = calories.toString(),
            label = "kcal",
            modifier = Modifier.weight(1f),
            onClick = { onAskAbout("Review my calorie burn today. How can I improve?") }
        )
    }
}

@Composable
private fun VitalPill(
    icon: ImageVector,
    tint: Color,
    value: String,
    label: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val haptic = LocalHapticFeedback.current
    // Outer Box centers the icon+text group within each weight(1f) cell so
    // short values ("0") don't hug the left edge.
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .clickable {
                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                onClick()
            }
            .padding(horizontal = 4.dp, vertical = 2.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(14.dp)
            )
            Column(horizontalAlignment = Alignment.Start) {
                Text(
                    text = value,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = Poppins,
                    color = AppColors.onBackground
                )
                Text(
                    text = label,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Medium,
                    fontFamily = Poppins,
                    color = AppColors.onSurfaceVariant
                )
            }
        }
    }
}

// ─────────────────────────────────────
// AI Roster Picker — Swastri / Coach / Nutri / Zen / Luna
// ─────────────────────────────────────

@Composable
fun AIRosterPicker(
    selected: AIPersonality,
    onSelect: (AIPersonality) -> Unit,
    modifier: Modifier = Modifier
) {
    val haptic = LocalHapticFeedback.current
    // Plain Row (not LazyRow) so the 5 items can be centered within the
    // full screen width instead of left-aligned with edge padding.
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.Top
    ) {
        AIPersonality.values().forEach { personality ->
            val isSelected = personality == selected
            val color = Color(personality.colorHex)
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier
                    .width(64.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .clickable {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onSelect(personality)
                    }
                    .padding(vertical = 4.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(color.copy(alpha = if (isSelected) 0.18f else 0.08f))
                        .then(
                            if (isSelected) Modifier.border(
                                2.dp,
                                color.copy(alpha = 0.4f),
                                CircleShape
                            ) else Modifier
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = resolveSfIcon(personality.icon),
                        contentDescription = personality.displayName,
                        tint = color,
                        modifier = Modifier.size(18.dp)
                    )
                }
                Text(
                    text = personality.displayName,
                    fontSize = 11.sp,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                    fontFamily = Poppins,
                    color = if (isSelected) color else AppColors.onSurfaceVariant
                )
            }
        }
    }
}

// ─────────────────────────────────────
// Quick Action Grid — 2-column layout with icon + title (iOS QuickActionGrid)
// ─────────────────────────────────────

@Composable
fun AIQuickActionGrid(
    actions: List<QuickAction>,
    onAction: (QuickAction) -> Unit,
    modifier: Modifier = Modifier
) {
    val haptic = LocalHapticFeedback.current
    val primary = Color(0xFF2E3192)
    // Render up to 4 items in a 2×2 grid.
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        actions.take(4).chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { action ->
                    QuickActionCard(
                        action = action,
                        primary = primary,
                        modifier = Modifier.weight(1f),
                        onClick = {
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            onAction(action)
                        }
                    )
                }
                // Fill the trailing column if an odd item-count leaves a gap.
                if (row.size == 1) {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun QuickActionCard(
    action: QuickAction,
    primary: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.surface)
            .clickable { onClick() }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(primary.copy(alpha = 0.1f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = resolveSfIcon(action.icon),
                contentDescription = null,
                tint = primary,
                modifier = Modifier.size(16.dp)
            )
        }
        Text(
            text = action.title,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = Poppins,
            color = AppColors.onBackground,
            maxLines = 1
        )
    }
}

