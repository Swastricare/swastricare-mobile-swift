package com.swasthicare.mobile.ui.screens.hydration

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.*
import com.swasthicare.mobile.ui.theme.AppColors
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.PI
import kotlin.math.sin

// Brand color for hydration accent
val HydrationCyan = Color(0xFF64D2FF)

// ─────────────────────────────────────
// MARK: - WaterGlassView
// ─────────────────────────────────────

/**
 * Glass-shaped water container with animated wave fill.
 * Draws a trapezoid glass outline and clips two sine waves inside.
 */
@Composable
fun WaterGlassView(
    progress: Float,
    modifier: Modifier = Modifier
) {
    val animatedProgress by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 600, easing = FastOutSlowInEasing),
        label = "glassProgress"
    )

    val infiniteTransition = rememberInfiniteTransition(label = "glassWave")
    val phase1 by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 2f * PI.toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(2500, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "phase1"
    )
    val phase2 by infiniteTransition.animateFloat(
        initialValue = PI.toFloat(),
        targetValue = 3f * PI.toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "phase2"
    )

    val percentText = "${(animatedProgress * 100).toInt()}%"

    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height

        // Glass shape: trapezoid (wider rim, narrower base)
        val rimInset = w * 0.08f
        val baseInset = w * 0.18f
        val topY = h * 0.05f
        val bottomY = h * 0.95f

        val glassPath = Path().apply {
            moveTo(rimInset, topY)
            lineTo(w - rimInset, topY)
            lineTo(w - baseInset, bottomY)
            lineTo(baseInset, bottomY)
            close()
        }

        // Glass outline
        drawPath(
            path = glassPath,
            color = Color.White.copy(alpha = 0.3f),
            style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round)
        )

        // Clip waves inside the glass
        clipPath(glassPath) {
            val glassHeight = bottomY - topY
            val waterTop = bottomY - (glassHeight * animatedProgress)
            val amplitude = glassHeight * 0.03f

            // Wave 1 (back)
            val wavePath1 = Path().apply {
                moveTo(0f, h)
                for (x in 0..w.toInt() step 4) {
                    val xf = x.toFloat()
                    val angle = (xf / w) * 2 * PI.toFloat() + phase1
                    val yf = waterTop + sin(angle) * amplitude
                    lineTo(xf, yf)
                }
                lineTo(w, h)
                close()
            }
            drawPath(wavePath1, HydrationCyan.copy(alpha = 0.25f), style = Fill)

            // Wave 2 (front)
            val wavePath2 = Path().apply {
                moveTo(0f, h)
                for (x in 0..w.toInt() step 4) {
                    val xf = x.toFloat()
                    val angle = (xf / w) * 2.5f * PI.toFloat() + phase2
                    val yf = waterTop + sin(angle) * amplitude * 1.3f
                    lineTo(xf, yf)
                }
                lineTo(w, h)
                close()
            }
            drawPath(wavePath2, HydrationCyan.copy(alpha = 0.4f), style = Fill)
        }

        // Percentage text in center
        val textPaint = android.graphics.Paint().apply {
            color = android.graphics.Color.WHITE
            textSize = (h * 0.12f)
            textAlign = android.graphics.Paint.Align.CENTER
            isFakeBoldText = true
            isAntiAlias = true
        }
        drawContext.canvas.nativeCanvas.drawText(
            percentText,
            w / 2,
            h / 2 + textPaint.textSize / 3,
            textPaint
        )
    }
}

// ─────────────────────────────────────
// MARK: - HydrationCalendarStrip
// ─────────────────────────────────────

@Composable
fun HydrationCalendarStrip(
    selectedDate: LocalDate,
    onDateSelected: (LocalDate) -> Unit,
    modifier: Modifier = Modifier
) {
    val today = LocalDate.now()
    val dates = (-3..3).map { today.plusDays(it.toLong()) }

    LazyRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(horizontal = 20.dp)
    ) {
        items(dates) { date ->
            HydrationCalendarDay(
                date = date,
                isToday = date == today,
                isSelected = date == selectedDate,
                onClick = { onDateSelected(date) }
            )
        }
    }
}

@Composable
private fun HydrationCalendarDay(
    date: LocalDate,
    isToday: Boolean,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val isDark = isSystemInDarkTheme()
    val dayAbbr = date.dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault()).take(3)
    val todayBg = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)

    Box(
        modifier = Modifier
            .width(50.dp)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .background(
                if (isToday && !isSelected) todayBg else Color.Transparent,
                RoundedCornerShape(12.dp)
            )
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = dayAbbr,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = if (isSelected) Color.White
                else AppColors.onSurface.copy(alpha = 0.5f)
            )
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(
                        if (isSelected) HydrationCyan else Color.Transparent,
                        CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = date.dayOfMonth.toString(),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (isSelected) Color.White
                    else AppColors.onSurface
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - HydrationStatPill
// ─────────────────────────────────────

@Composable
fun HydrationStatPill(
    icon: ImageVector,
    iconColor: Color,
    value: String,
    label: String,
    modifier: Modifier = Modifier
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(iconColor.copy(alpha = 0.08f))
            .padding(vertical = 10.dp, horizontal = 8.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconColor,
            modifier = Modifier.size(14.dp)
        )
        Text(
            text = value,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )
        Text(
            text = label,
            fontSize = 11.sp,
            color = AppColors.onSurface.copy(alpha = 0.5f),
            maxLines = 1,
            textAlign = TextAlign.Center
        )
    }
}

// ─────────────────────────────────────
// MARK: - DrinkTypePicker
// ─────────────────────────────────────

@Composable
fun DrinkTypePicker(
    selectedType: DrinkType,
    onTypeSelected: (DrinkType) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(horizontal = 20.dp)
    ) {
        items(DrinkType.entries.toList()) { type ->
            val isSelected = type == selectedType
            val bgColor by animateColorAsState(
                targetValue = if (isSelected) HydrationCyan else Color.Transparent,
                label = "drinkChip"
            )
            val textColor = if (isSelected) Color.White
            else AppColors.onSurface

            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(bgColor)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) { onTypeSelected(type) }
                    .then(
                        if (!isSelected) Modifier.background(
                            AppColors.onSurface.copy(alpha = 0.06f),
                            RoundedCornerShape(20.dp)
                        ) else Modifier
                    )
                    .padding(horizontal = 14.dp, vertical = 8.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(type.icon, fontSize = 16.sp)
                    Text(
                        type.displayName,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        color = textColor
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - QuickAddButton
// ─────────────────────────────────────

@Composable
fun QuickAddButton(
    preset: QuickAddPreset,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(HydrationCyan.copy(alpha = 0.1f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .padding(horizontal = 16.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(preset.icon, fontSize = 14.sp)
            Text(
                preset.label,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = HydrationCyan
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - HydrationEntryCard
// ─────────────────────────────────────

@Composable
fun HydrationEntryCard(
    entry: HydrationEntry,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    val drinkType = entry.drinkTypeEnum

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Drink emoji
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(HydrationCyan.copy(alpha = 0.1f)),
            contentAlignment = Alignment.Center
        ) {
            Text(drinkType.icon, fontSize = 22.sp)
        }

        // Details
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                text = drinkType.displayName,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = "${entry.amountMl}ml · ${entry.effectiveMl}ml effective · ${entry.formattedTime}",
                fontSize = 12.sp,
                color = AppColors.onSurface.copy(alpha = 0.5f)
            )
        }

        // Delete button
        IconButton(onClick = onDelete, modifier = Modifier.size(32.dp)) {
            Icon(
                Icons.Default.RemoveCircleOutline,
                contentDescription = "Delete",
                tint = Color(0xFFFF3B30).copy(alpha = 0.6f),
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - HydrationInsightsCard
// ─────────────────────────────────────

@Composable
fun HydrationInsightsCard(
    insights: HydrationInsights,
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(cardBg)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(Icons.Default.TrendingUp, null, tint = HydrationCyan, modifier = Modifier.size(20.dp))
            Text("Insights", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            InsightItem("${insights.streakDays}", "Day Streak", Icons.Default.LocalFireDepartment, Color(0xFFFF9500))
            InsightItem("${insights.avgDailyIntake}ml", "Avg/Day", Icons.Default.BarChart, HydrationCyan)
        }

        insights.mostCommonDrink?.let { drink ->
            HorizontalDivider(color = AppColors.onSurface.copy(alpha = 0.08f))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(Icons.Default.WaterDrop, null, tint = HydrationCyan, modifier = Modifier.size(16.dp))
                Text(
                    "Most common: $drink",
                    fontSize = 13.sp,
                    color = AppColors.onSurface.copy(alpha = 0.6f)
                )
            }
        }

        if (insights.caffeineCount > 0) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(Icons.Default.LocalCafe, null, tint = Color(0xFF8B6914), modifier = Modifier.size(16.dp))
                Text(
                    "Caffeine today: ${insights.caffeineAmountMl}ml (${insights.caffeineCount} drinks)",
                    fontSize = 13.sp,
                    color = AppColors.onSurface.copy(alpha = 0.6f)
                )
            }
        }
    }
}

@Composable
private fun InsightItem(
    value: String,
    label: String,
    icon: ImageVector,
    color: Color
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Icon(icon, null, tint = color, modifier = Modifier.size(22.dp))
        Text(value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.onSurface)
        Text(label, fontSize = 12.sp, color = AppColors.onSurface.copy(alpha = 0.5f))
    }
}

// ─────────────────────────────────────
// MARK: - UrineColorGuideSheet
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UrineColorGuideSheet(
    onDismiss: () -> Unit,
    onLogWater: (Int) -> Unit = {}
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var selectedLevel by remember { mutableStateOf<Int?>(null) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = AppColors.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                "Urine Color Guide",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 8.dp)
            )

            Text(
                "Tap a color to check your hydration level",
                fontSize = 14.sp,
                color = AppColors.onSurface.copy(alpha = 0.6f),
                modifier = Modifier.padding(bottom = 12.dp)
            )

            UrineColorLevel.guide.forEach { level ->
                val isSelected = selectedLevel == level.level
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(
                            if (isSelected) AppColors.primaryContainer
                            else AppColors.surfaceVariant.copy(alpha = 0.3f)
                        )
                        .clickable { selectedLevel = if (isSelected) null else level.level }
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Color swatch
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(Color(level.colorHex))
                            .then(
                                if (isSelected) Modifier.border(2.dp, AppColors.primary, RoundedCornerShape(8.dp))
                                else Modifier
                            )
                    )

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            level.name,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.onSurface
                        )
                        Text(
                            level.status,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = when {
                                level.level <= 2 -> Color(0xFF34C759)
                                level.level <= 4 -> Color(0xFFFF9500)
                                else -> Color(0xFFFF3B30)
                            }
                        )
                        Text(
                            level.recommendation,
                            fontSize = 11.sp,
                            color = AppColors.onSurface.copy(alpha = 0.5f),
                            maxLines = if (isSelected) Int.MAX_VALUE else 2,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }

                if (isSelected && level.level > 2) {
                    Button(
                        onClick = {
                            onLogWater(250)
                            onDismiss()
                        },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF00C7BE)),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("Log 250ml Water", fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - HydrationProgressRing
// ─────────────────────────────────────

@Composable
fun HydrationProgressRing(
    progress: Float,
    modifier: Modifier = Modifier
) {
    val animatedProgress by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 800, easing = FastOutSlowInEasing),
        label = "hydrationRing"
    )
    val ringColor = when {
        progress >= 1f -> Color(0xFF34C759)   // Goal met: green
        progress >= 0.7f -> HydrationCyan      // Nearly there
        else -> HydrationCyan
    }

    Canvas(modifier = modifier.size(140.dp)) {
        val strokeWidth = 14.dp.toPx()
        val diameter = size.minDimension - strokeWidth
        val topLeft = Offset((size.width - diameter) / 2f, (size.height - diameter) / 2f)
        val arcSize = Size(diameter, diameter)

        drawArc(
            color = Color.Gray.copy(alpha = 0.15f),
            startAngle = -90f,
            sweepAngle = 360f,
            useCenter = false,
            topLeft = topLeft,
            size = arcSize,
            style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
        )
        drawArc(
            color = ringColor,
            startAngle = -90f,
            sweepAngle = 360f * animatedProgress,
            useCenter = false,
            topLeft = topLeft,
            size = arcSize,
            style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Weather Adjustment Banner
// ─────────────────────────────────────

@Composable
fun WeatherAdjustmentBanner(
    temperature: Double,
    city: String,
    baseGoal: Int,
    adjustedGoal: Int,
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()
    val bannerBg = if (isDark) Color(0xFF2C1810) else Color(0xFFFFF3E0)
    val accentColor = Color(0xFFFF9500)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bannerBg)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // Sun icon
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(accentColor.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.WbSunny, null,
                tint = accentColor,
                modifier = Modifier.size(20.dp)
            )
        }

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "It's ${String.format("%.0f", temperature)}\u00B0C in $city",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
            Text(
                text = "Your hydration goal has been increased by 20% (${baseGoal}ml \u2192 ${adjustedGoal}ml)",
                fontSize = 11.sp,
                color = AppColors.onSurface.copy(alpha = 0.6f)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Skeleton Loading
// ─────────────────────────────────────

@Composable
fun HydrationSkeletonContent() {
    val shimmer = AppColors.onSurface.copy(alpha = 0.07f)
    Column(
        modifier = Modifier.fillMaxSize().padding(top = 8.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(7) {
                Box(Modifier.weight(1f).height(56.dp).clip(RoundedCornerShape(12.dp)).background(shimmer))
            }
        }
        Box(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp)
                .height(260.dp).clip(RoundedCornerShape(16.dp)).background(shimmer)
        )
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(5) {
                Box(Modifier.weight(1f).height(40.dp).clip(RoundedCornerShape(12.dp)).background(shimmer))
            }
        }
        Box(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp)
                .height(140.dp).clip(RoundedCornerShape(16.dp)).background(shimmer)
        )
    }
}
