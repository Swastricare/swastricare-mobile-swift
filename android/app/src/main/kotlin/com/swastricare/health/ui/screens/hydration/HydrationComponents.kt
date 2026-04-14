package com.swastricare.health.ui.screens.hydration

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PageSize
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.input.pointer.PointerEventTimeoutCancellationException
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.graphics.BitmapFactory
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.VibrationEffect
import android.os.Vibrator
import com.swastricare.health.data.models.*
import com.swastricare.health.ui.screens.home.lightBorder
import com.swastricare.health.ui.theme.AppColors
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.PI
import kotlin.math.sin

// Brand color for hydration accent
val HydrationCyan = Color(0xFF64D2FF)

// Accent color per drink type (used for water fill inside progress ring)
val drinkAccentColors = mapOf(
    DrinkType.WATER  to Color(0xFF38BDF8),
    DrinkType.COFFEE to Color(0xFFC48A2A),
    DrinkType.TEA    to Color(0xFF8BC34A),
    DrinkType.JUICE  to Color(0xFFFF9800),
    DrinkType.MILK   to Color(0xFFB0BEC5)
)

// Asset icon file per drink type
private val drinkIconAssets = mapOf(
    DrinkType.WATER to "icons/glass-water.png",
    DrinkType.TEA to "icons/tea.png",
    DrinkType.COFFEE to "icons/coffee.png",
    DrinkType.JUICE to "icons/Juice.png",
    DrinkType.MILK to "icons/milk.png",
    DrinkType.SPORTS_DRINK to "icons/energy-drink.png",
    DrinkType.OTHER to "icons/glass-water.png"
)

/**
 * Loads and displays the PNG asset icon for a given DrinkType.
 */
@Composable
fun DrinkIcon(
    drinkType: DrinkType,
    modifier: Modifier = Modifier,
    size: androidx.compose.ui.unit.Dp = 24.dp
) {
    val context = LocalContext.current
    val assetPath = drinkIconAssets[drinkType] ?: "icons/glass-water.png"
    val bitmap = remember(assetPath) {
        context.assets.open(assetPath).use { BitmapFactory.decodeStream(it) }.asImageBitmap()
    }
    Image(
        bitmap = bitmap,
        contentDescription = drinkType.displayName,
        modifier = modifier.size(size)
    )
}

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
    val isDark = isSystemInDarkTheme()
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

        // Empty glass background fill
        drawPath(
            path = glassPath,
            color = if (isDark) Color.White.copy(alpha = 0.04f) else HydrationCyan.copy(alpha = 0.07f),
            style = Fill
        )

        // Animated waves clipped to glass interior
        clipPath(glassPath) {
            val glassHeight = bottomY - topY
            val waterTop = bottomY - (glassHeight * animatedProgress)
            val amplitude = glassHeight * 0.05f  // visible waves

            // Wave 1 — back layer
            val wavePath1 = Path().apply {
                moveTo(0f, h)
                for (x in 0..w.toInt() step 4) {
                    val xf = x.toFloat()
                    val angle = (xf / w) * 2f * PI.toFloat() + phase1
                    lineTo(xf, waterTop + sin(angle) * amplitude)
                }
                lineTo(w, h)
                close()
            }
            drawPath(wavePath1, HydrationCyan.copy(alpha = 0.45f), style = Fill)

            // Wave 2 — front layer (more opaque, different freq)
            val wavePath2 = Path().apply {
                moveTo(0f, h)
                for (x in 0..w.toInt() step 4) {
                    val xf = x.toFloat()
                    val angle = (xf / w) * 2.4f * PI.toFloat() + phase2
                    lineTo(xf, waterTop + sin(angle) * amplitude * 1.4f)
                }
                lineTo(w, h)
                close()
            }
            drawPath(wavePath2, HydrationCyan.copy(alpha = 0.75f), style = Fill)
        }

        // Glass outline drawn on top of waves
        drawPath(
            path = glassPath,
            color = if (isDark) Color.White.copy(alpha = 0.35f) else HydrationCyan,
            style = Stroke(width = 2.5.dp.toPx(), cap = StrokeCap.Round)
        )

        // Percentage text — always white when water covers it, adaptive otherwise
        val waterY = bottomY - ((bottomY - topY) * animatedProgress)
        val textY = h / 2f
        val textColor = if (textY > waterY) {
            // text is inside the water — always white
            android.graphics.Color.WHITE
        } else {
            if (isDark) android.graphics.Color.WHITE else android.graphics.Color.parseColor("#1C1C1E")
        }
        val textPaint = android.graphics.Paint().apply {
            color = textColor
            textSize = h * 0.13f
            textAlign = android.graphics.Paint.Align.CENTER
            isFakeBoldText = true
            isAntiAlias = true
        }
        drawContext.canvas.nativeCanvas.drawText(
            percentText,
            w / 2,
            textY + textPaint.textSize / 3,
            textPaint
        )
    }
}

// ─────────────────────────────────────
// MARK: - HydrationCalendarStrip
// ─────────────────────────────────────

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun HydrationCalendarStrip(
    selectedDate: LocalDate,
    onDateSelected: (LocalDate) -> Unit,
    modifier: Modifier = Modifier
) {
    val today = LocalDate.now()
    val baseDate = remember { today.minusDays(500) }
    val todayPageIndex = remember { (today.toEpochDay() - baseDate.toEpochDay()).toInt() }
    // Include 3 future dates so they're visible, but scrolling to them is blocked
    val totalDays = remember { todayPageIndex + 4 }

    val selectedPageIndex = remember(selectedDate) {
        (selectedDate.toEpochDay() - baseDate.toEpochDay()).toInt().coerceIn(0, todayPageIndex)
    }

    val pagerState = rememberPagerState(
        initialPage = selectedPageIndex,
        pageCount = { totalDays }
    )

    val view = LocalView.current

    // Block scrolling past today - snap back immediately
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage to pagerState.currentPageOffsetFraction }
            .collect { (page, fraction) ->
                if (page > todayPageIndex || (page == todayPageIndex && fraction > 0.01f)) {
                    pagerState.scrollToPage(todayPageIndex)
                }
            }
    }

    // Haptic + update selected date when page settles
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.settledPage }
            .collect { page ->
                if (page <= todayPageIndex) {
                    val newDate = baseDate.plusDays(page.toLong())
                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                    onDateSelected(newDate)
                }
            }
    }

    // When selected date changes externally, animate pager
    LaunchedEffect(selectedDate) {
        if (pagerState.settledPage != selectedPageIndex) {
            pagerState.animateScrollToPage(selectedPageIndex)
        }
    }

    BoxWithConstraints(modifier = modifier.fillMaxWidth()) {
        val itemWidth = maxWidth / 7

        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxWidth(),
            pageSize = PageSize.Fixed(itemWidth),
            contentPadding = PaddingValues(horizontal = (maxWidth - itemWidth) / 2),
            beyondViewportPageCount = 3,
            pageSpacing = 0.dp,
            userScrollEnabled = true
        ) { page ->
            val date = baseDate.plusDays(page.toLong())
            val isFuture = page > todayPageIndex
            val rawOffset = (pagerState.currentPage - page).toFloat() + pagerState.currentPageOffsetFraction
            val pageOffset = kotlin.math.abs(rawOffset).coerceIn(0f, 3f)
            val scale = 1f - pageOffset * 0.08f
            val alpha = if (isFuture) 0.35f else 1f - pageOffset * 0.185f

            HydrationCalendarDay(
                date = date,
                isSelected = page == pagerState.currentPage && !isFuture,
                isFuture = isFuture,
                scale = scale,
                alpha = alpha,
                onClick = { if (!isFuture) onDateSelected(date) }
            )
        }
    }
}

@Composable
private fun HydrationCalendarDay(
    date: LocalDate,
    isSelected: Boolean,
    isFuture: Boolean,
    scale: Float,
    alpha: Float,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val view = LocalView.current
    val dayAbbr = date.dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault()).take(3)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .graphicsLayer(
                scaleX = scale,
                scaleY = scale,
                alpha = alpha
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                enabled = !isFuture
            ) {
                view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                onClick()
            }
            .padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        // Day name
        Text(
            text = dayAbbr,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = if (isSelected) Color.White else Color.White.copy(alpha = 0.75f)
        )
        // Date number with subtle white highlight if selected
        Box(
            modifier = Modifier
                .size(40.dp)
                .then(
                    if (isSelected) Modifier
                        .background(Color.White.copy(alpha = 0.25f), CircleShape)
                        .border(1.dp, Color.White.copy(alpha = 0.6f), CircleShape)
                    else Modifier
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = date.dayOfMonth.toString(),
                fontSize = if (isSelected) 17.sp else 16.sp,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                color = Color.White
            )
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
            .lightBorder(12.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.surfaceVariant)
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
// MARK: - QuickAddDrinkChips
// ─────────────────────────────────────

@Composable
fun QuickAddDrinkChips(
    onAddDrink: (DrinkType) -> Unit,
    modifier: Modifier = Modifier
) {
    val view = LocalView.current
    val isDark = isSystemInDarkTheme()
    val drinkTypes = listOf(
        DrinkType.WATER,
        DrinkType.TEA,
        DrinkType.COFFEE,
        DrinkType.JUICE,
        DrinkType.MILK,
        DrinkType.SPORTS_DRINK
    )

    var draggedChip by remember { mutableStateOf<DrinkType?>(null) }
    var dragOffset by remember { mutableStateOf(Offset.Zero) }
    var dragStartPosition by remember { mutableStateOf(Offset.Zero) }
    val chipPositions = remember { mutableMapOf<DrinkType, Offset>() }
    var parentBoxPosition by remember { mutableStateOf(Offset.Zero) }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .onGloballyPositioned { coordinates ->
                // Track parent Box position
                parentBoxPosition = Offset(
                    coordinates.positionInRoot().x,
                    coordinates.positionInRoot().y
                )
            }
    ) {
        LazyRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(horizontal = 16.dp)
        ) {
            items(drinkTypes) { drinkType ->
                val isDragging = draggedChip == drinkType

                Box(
                    modifier = Modifier
                        .onGloballyPositioned { coordinates ->
                            // Track chip position in root space
                            chipPositions[drinkType] = Offset(
                                coordinates.positionInRoot().x,
                                coordinates.positionInRoot().y
                            )
                        }
                        .graphicsLayer {
                            alpha = if (isDragging) 0.3f else 1f
                        }
                        .pointerInput(drinkType) {
                            detectDragGesturesAfterLongPress(
                                onDragStart = { offset ->
                                    draggedChip = drinkType
                                    // Convert chip position to parent Box coordinate space
                                    val chipRootPos = chipPositions[drinkType] ?: Offset.Zero
                                    val chipLocalPos = chipRootPos - parentBoxPosition
                                    dragStartPosition = chipLocalPos + offset
                                    dragOffset = Offset.Zero
                                    view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                                },
                                onDrag = { change, dragAmount ->
                                    change.consume()
                                    dragOffset += dragAmount
                                },
                                onDragEnd = {
                                    if (draggedChip != null) {
                                        // If dragged significantly upward, add the drink
                                        if (dragOffset.y < -100f) {
                                            view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                                            onAddDrink(drinkType)
                                        }
                                        draggedChip = null
                                    }
                                    dragOffset = Offset.Zero
                                    dragStartPosition = Offset.Zero
                                },
                                onDragCancel = {
                                    draggedChip = null
                                    dragOffset = Offset.Zero
                                    dragStartPosition = Offset.Zero
                                }
                            )
                        }
                        .clip(RoundedCornerShape(20.dp))
                        .background(
                            if (isDark)
                                Brush.linearGradient(
                                    listOf(
                                        Color.White.copy(alpha = 0.12f),
                                        Color.White.copy(alpha = 0.08f)
                                    )
                                )
                            else
                                Brush.linearGradient(
                                    listOf(
                                        Color.White.copy(alpha = 0.25f),
                                        Color.White.copy(alpha = 0.18f)
                                    )
                                )
                        )
                        .border(
                            width = 1.dp,
                            color = Color.White.copy(alpha = if (isDark) 0.15f else 0.25f),
                            shape = RoundedCornerShape(20.dp)
                        )
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null
                        ) {
                            view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                            onAddDrink(drinkType)
                        }
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                ) {
                    DrinkChipContent(drinkType = drinkType, isDark = isDark)
                }
            }
        }

        // Overlay for dragged chip
        if (draggedChip != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .pointerInput(Unit) { } // Block touches
            ) {
                Box(
                    modifier = Modifier
                        .offset {
                            IntOffset(
                                (dragStartPosition.x + dragOffset.x).toInt(),
                                (dragStartPosition.y + dragOffset.y).toInt()
                            )
                        }
                        .graphicsLayer {
                            scaleX = 1.1f
                            scaleY = 1.1f
                            shadowElevation = 32f
                        }
                        .clip(RoundedCornerShape(20.dp))
                        .background(
                            Brush.linearGradient(
                                listOf(
                                    drinkAccentColors[draggedChip] ?: HydrationCyan,
                                    (drinkAccentColors[draggedChip] ?: HydrationCyan).copy(alpha = 0.8f)
                                )
                            )
                        )
                        .border(
                            width = 2.dp,
                            color = Color.White.copy(alpha = 0.5f),
                            shape = RoundedCornerShape(20.dp)
                        )
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                ) {
                    DrinkChipContent(drinkType = draggedChip!!, isDark = isDark)
                }
            }
        }
    }
}

@Composable
private fun DrinkChipContent(drinkType: DrinkType, isDark: Boolean) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            DrinkIcon(drinkType = drinkType, size = 20.dp)
        }
        Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(
                drinkType.displayName,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
            Text(
                "+100ml",
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.75f)
            )
        }
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
                            AppColors.surfaceVariant,
                            RoundedCornerShape(20.dp)
                        ) else Modifier
                    )
                    .padding(horizontal = 14.dp, vertical = 8.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    DrinkIcon(drinkType = type, size = 18.dp)
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
            .lightBorder(16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surfaceVariant)
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
    val view = LocalView.current
    val drinkType = entry.drinkTypeEnum

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Drink icon
        Box(
            modifier = Modifier.size(44.dp),
            contentAlignment = Alignment.Center
        ) {
            DrinkIcon(drinkType = drinkType, size = 26.dp)
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
        IconButton(onClick = {
            view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
            onDelete()
        }, modifier = Modifier.size(32.dp)) {
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
    Column(
        modifier = modifier
            .fillMaxWidth()
            .lightBorder(16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.surface)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(HydrationCyan.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                DrinkIcon(drinkType = DrinkType.WATER, size = 22.dp)
            }
            Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                Text("Insights", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = AppColors.onSurface)
                Text("Your hydration patterns", fontSize = 12.sp, color = AppColors.onSurface.copy(alpha = 0.45f))
            }
        }

        // Stat cards — side by side
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            InsightStatCard(
                value = "${insights.streakDays}",
                unit = "days",
                label = "Streak",
                assetIcon = "icons/fire.png",
                color = Color(0xFFFF9500),
                modifier = Modifier.weight(1f)
            )
            InsightStatCard(
                value = "${insights.avgDailyIntake}",
                unit = "ml",
                label = "Daily avg",
                assetIcon = "icons/statistics.png",
                color = HydrationCyan,
                modifier = Modifier.weight(1f)
            )
        }

        // Most common drink
        insights.mostCommonDrink?.let { drink ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .lightBorder(10.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(AppColors.surfaceVariant)
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(HydrationCyan.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    DrinkIcon(drinkType = DrinkType.WATER, size = 18.dp)
                }
                Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text("Favourite drink", fontSize = 11.sp, color = AppColors.onSurface.copy(alpha = 0.45f))
                    Text(drink, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.onSurface)
                }
            }
        }

        // Caffeine info
        if (insights.caffeineCount > 0) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .lightBorder(10.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(AppColors.surfaceVariant)
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color(0xFFFF9500).copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    DrinkIcon(drinkType = DrinkType.COFFEE, size = 18.dp)
                }
                Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text("Caffeine today", fontSize = 11.sp, color = AppColors.onSurface.copy(alpha = 0.45f))
                    Text(
                        "${insights.caffeineAmountMl}ml · ${insights.caffeineCount} drinks",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.onSurface
                    )
                }
            }
        }
    }
}

@Composable
private fun InsightStatCard(
    value: String,
    unit: String,
    label: String,
    assetIcon: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val bitmap = remember(assetIcon) {
        context.assets.open(assetIcon).use { BitmapFactory.decodeStream(it) }.asImageBitmap()
    }
    Column(
        modifier = modifier
            .lightBorder(12.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.surfaceVariant)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(color.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Image(bitmap = bitmap, contentDescription = null, modifier = Modifier.size(18.dp))
        }
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(value, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = AppColors.onSurface)
            Text(unit, fontSize = 12.sp, color = AppColors.onSurface.copy(alpha = 0.5f), modifier = Modifier.padding(bottom = 3.dp))
        }
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
        containerColor = if (isSystemInDarkTheme()) Color(0xFF0A0A0A) else Color.White,
        tonalElevation = 0.dp
    ) {
        // Fixed header
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 4.dp)
        ) {
            Text(
                "Urine Color Guide",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(4.dp))
            Text(
                "Tap a color to check your hydration level",
                fontSize = 14.sp,
                color = AppColors.onSurface.copy(alpha = 0.55f)
            )
            Spacer(Modifier.height(12.dp))
            HorizontalDivider(color = AppColors.outline.copy(alpha = 0.3f))
        }

        // Scrollable level cards
        LazyColumn(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(UrineColorLevel.guide) { level ->
                val isSelected = selectedLevel == level.level
                val levelColor = Color(level.colorHex)
                val statusColor = when {
                    level.level <= 2 -> Color(0xFF34C759)
                    level.level <= 4 -> Color(0xFFFF9500)
                    else -> Color(0xFFFF3B30)
                }

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .lightBorder(14.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(AppColors.surfaceVariant)
                        .then(
                            if (isSelected) Modifier.border(
                                width = 2.dp,
                                color = levelColor,
                                shape = RoundedCornerShape(14.dp)
                            ) else Modifier
                        )
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null
                        ) { selectedLevel = if (isSelected) null else level.level }
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        // Color swatch with level number
                        Box(
                            modifier = Modifier
                                .size(52.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(levelColor),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                "${level.level}",
                                fontSize = 20.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White.copy(alpha = 0.9f)
                            )
                        }

                        // Name + status + recommendation
                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    level.name,
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = AppColors.onSurface
                                )
                                // Status chip
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(20.dp))
                                        .background(statusColor.copy(alpha = 0.15f))
                                        .padding(horizontal = 8.dp, vertical = 3.dp)
                                ) {
                                    Text(
                                        level.status,
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = statusColor
                                    )
                                }
                            }
                            Text(
                                level.recommendation,
                                fontSize = 12.sp,
                                color = AppColors.onSurface.copy(alpha = 0.55f),
                                maxLines = if (isSelected) Int.MAX_VALUE else 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }

                    // Expanded: log water button for dehydrated levels
                    if (isSelected && level.level > 2) {
                        Button(
                            onClick = { onLogWater(250); onDismiss() },
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 12.dp)
                                .padding(bottom = 12.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF00C7BE)),
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Icon(
                                Icons.Default.WaterDrop, null,
                                tint = Color.White,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(Modifier.width(8.dp))
                            Text("Log 250ml Water", fontWeight = FontWeight.SemiBold, color = Color.White)
                        }
                    }
                }
            }

            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Gravity Sensor
// ─────────────────────────────────────

/**
 * Reads accelerometer and returns smoothed (tiltX, tiltY) in range roughly -1..1.
 * tiltX: positive = device tilted right, tiltY: positive = device tilted forward.
 */
@Composable
private fun rememberGravity(): State<Pair<Float, Float>> {
    val context = LocalContext.current
    val tilt = remember { mutableStateOf(0f to 0f) }

    DisposableEffect(Unit) {
        val sensorManager = context.getSystemService(android.content.Context.SENSOR_SERVICE) as SensorManager
        val vibrator = context.getSystemService(android.content.Context.VIBRATOR_SERVICE) as? Vibrator
        val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY)
            ?: sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        if (sensor == null) return@DisposableEffect onDispose {}

        var smoothX = 0f
        var smoothY = 0f
        val alpha = 0.15f // smoothing factor
        var lastHapticTiltX = 0f
        var lastHapticTime = 0L
        val hapticCooldownMs = 150L   // min ms between haptic ticks
        val hapticThreshold = 0.08f    // min tilt change to trigger

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                // Normalize: gravity ~9.8, map to -1..1
                val rawX = (event.values[0] / 9.8f).coerceIn(-1f, 1f)
                val rawY = (event.values[1] / 9.8f).coerceIn(-1f, 1f)
                smoothX += alpha * (rawX - smoothX)
                smoothY += alpha * (rawY - smoothY)
                tilt.value = smoothX to smoothY

                // Haptic tick when tilt changes enough
                val now = System.currentTimeMillis()
                val delta = kotlin.math.abs(smoothX - lastHapticTiltX)
                if (delta > hapticThreshold && now - lastHapticTime > hapticCooldownMs) {
                    lastHapticTiltX = smoothX
                    lastHapticTime = now
                    vibrator?.vibrate(
                        VibrationEffect.createOneShot(
                            (10 + (delta * 30).toInt().coerceAtMost(25)).toLong(),
                            (40 + (delta * 150).toInt().coerceAtMost(80))
                        )
                    )
                }
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        sensorManager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_GAME)
        onDispose { sensorManager.unregisterListener(listener) }
    }

    return tilt
}

// ─────────────────────────────────────
// MARK: - HydrationHeroRing
// ─────────────────────────────────────

@Composable
fun HydrationHeroRing(
    intakeMl: Int,
    goalMl: Int,
    progress: Float,
    drinkAccentColor: Color = HydrationCyan,
    streakDays: Int = 0,
    onDragAddMl: ((Int) -> Unit)? = null,
    onTap: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val view = LocalView.current

    var dragAddMl by remember { mutableIntStateOf(0) }
    var isDragging by remember { mutableStateOf(false) }

    val totalProgress = if (isDragging && goalMl > 0) {
        ((intakeMl + dragAddMl).toFloat() / goalMl).coerceIn(0f, 1f)
    } else {
        progress.coerceIn(0f, 1f)
    }

    val animatedProgress by animateFloatAsState(
        targetValue = totalProgress,
        animationSpec = tween(durationMillis = if (isDragging) 100 else 900, easing = FastOutSlowInEasing),
        label = "heroRing"
    )

    // Gravity-based tilt
    val gravity = rememberGravity()
    val (tiltX, _) = gravity.value

    // Continuous wave animation
    val infiniteTransition = rememberInfiniteTransition(label = "heroWave")
    val wavePhase1 by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 2f * PI.toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(2200, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "wavePhase1"
    )
    val wavePhase2 by infiniteTransition.animateFloat(
        initialValue = PI.toFloat(),
        targetValue = 3f * PI.toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(2800, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "wavePhase2"
    )

    val isDark = isSystemInDarkTheme()
    val ringColor = if (progress >= 1f) Color(0xFF34C759) else Color.White
    val waterColor = if (progress >= 1f) Color(0xFF34C759) else drinkAccentColor
    val trackAlpha = if (isDark) 0.3f else 0.2f
    val percent = (progress * 100).toInt().coerceIn(0, 100)

    var lastHapticStep by remember { mutableIntStateOf(0) }

    Box(
        modifier = modifier
            .then(
                if (onTap != null) {
                    Modifier.clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) {
                        view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                        onTap()
                    }
                } else Modifier
            )
            .then(
                if (onDragAddMl != null) {
                    Modifier.pointerInput(goalMl) {
                        detectVerticalDragGestures(
                            onDragStart = {
                                isDragging = true
                                dragAddMl = 0
                                lastHapticStep = 0
                            },
                            onDragEnd = {
                                isDragging = false
                                if (dragAddMl > 0) {
                                    val snapped = ((dragAddMl + 25) / 50) * 50
                                    if (snapped > 0) onDragAddMl(snapped)
                                }
                                dragAddMl = 0
                            },
                            onDragCancel = {
                                isDragging = false
                                dragAddMl = 0
                            },
                            onVerticalDrag = { _, dragAmount ->
                                val mlPerPx = (goalMl.toFloat() / size.height).coerceAtLeast(1f)
                                dragAddMl = (dragAddMl + (-dragAmount * mlPerPx).toInt()).coerceIn(0, goalMl)
                                val step = dragAddMl / 50
                                if (step != lastHapticStep) {
                                    lastHapticStep = step
                                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                }
                            }
                        )
                    }
                } else Modifier
            ),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val strokeWidth = 14.dp.toPx()
            val diameter = size.minDimension - strokeWidth * 2
            val radius = diameter / 2f
            val center = Offset(size.width / 2f, size.height / 2f)
            val topLeft = Offset(center.x - radius, center.y - radius)
            val arcSize = Size(diameter, diameter)

            // Track ring (background)
            drawArc(
                color = Color.White.copy(alpha = trackAlpha),
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )

            // Water fill clipped to inner circle
            val innerRadius = radius - strokeWidth * 0.6f
            val circleClipPath = Path().apply {
                addOval(Rect(center = center, radius = innerRadius))
            }

            clipPath(circleClipPath) {
                val circleBottom = center.y + innerRadius
                val circleHeight = innerRadius * 2f
                val waterTop = circleBottom - (circleHeight * animatedProgress)
                val amplitude = circleHeight * 0.04f
                val waveWidth = innerRadius * 2f + 20f
                val waveStartX = center.x - innerRadius - 10f

                // Gravity tilt: tiltX shifts water level across the width
                // Max tilt offset = 30% of circle height so it looks dramatic but stays visible
                val tiltOffset = -tiltX * circleHeight * 0.3f

                // Wave 1 — back layer (with gravity tilt)
                val wavePath1 = Path().apply {
                    moveTo(waveStartX, circleBottom)
                    var x = 0f
                    while (x <= waveWidth) {
                        val xf = waveStartX + x
                        // Linear interpolation: left edge gets +tiltOffset, right edge gets -tiltOffset
                        val normalizedX = x / waveWidth
                        val gravityShift = tiltOffset * (1f - 2f * normalizedX)
                        val angle = (x / waveWidth) * 2f * PI.toFloat() + wavePhase1
                        lineTo(xf, waterTop + gravityShift + sin(angle) * amplitude)
                        x += 3f
                    }
                    lineTo(waveStartX + waveWidth, circleBottom)
                    close()
                }
                drawPath(wavePath1, waterColor.copy(alpha = 0.35f))

                // Wave 2 — front layer (with gravity tilt)
                val wavePath2 = Path().apply {
                    moveTo(waveStartX, circleBottom)
                    var x = 0f
                    while (x <= waveWidth) {
                        val xf = waveStartX + x
                        val normalizedX = x / waveWidth
                        val gravityShift = tiltOffset * (1f - 2f * normalizedX)
                        val angle = (x / waveWidth) * 2.5f * PI.toFloat() + wavePhase2
                        lineTo(xf, waterTop + gravityShift + sin(angle) * amplitude * 1.3f)
                        x += 3f
                    }
                    lineTo(waveStartX + waveWidth, circleBottom)
                    close()
                }
                drawPath(wavePath2, waterColor.copy(alpha = 0.6f))
            }

            // Progress arc drawn on top of the water fill
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

        // Text overlay
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            if (isDragging && dragAddMl > 0) {
                val snapped = ((dragAddMl + 25) / 50) * 50
                Text(
                    text = "+${snapped}ml",
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "Release to add",
                    fontSize = 13.sp,
                    color = Color.White.copy(alpha = 0.85f)
                )
            } else {
                Text(
                    text = "${intakeMl}ml",
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "of ${goalMl}ml",
                    fontSize = 13.sp,
                    color = Color.White.copy(alpha = 0.75f)
                )
                Spacer(Modifier.height(2.dp))
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(Color.White.copy(alpha = 0.2f))
                        .padding(horizontal = 10.dp, vertical = 3.dp)
                ) {
                    Text(
                        text = "$percent%",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
                if (streakDays > 0) {
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "\uD83D\uDD25 $streakDays day streak",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                }
            }
        }

    }
}

// ─────────────────────────────────────
// MARK: - HydrationHeroPager
// ─────────────────────────────────────

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun HydrationHeroPager(
    uiState: HydrationUiState,
    onDragAddMl: ((Int) -> Unit)? = null,
    onTapAnalytics: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val pagerState = rememberPagerState(pageCount = { 2 })

    Column(modifier = modifier) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .fillMaxWidth()
                .height(260.dp)
        ) { page ->
            when (page) {
                0 -> {
                    // Progress ring page
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        HydrationHeroRing(
                            intakeMl = uiState.effectiveIntake,
                            goalMl = uiState.effectiveGoalMl,
                            progress = uiState.progress,
                            drinkAccentColor = drinkAccentColors[uiState.dominantDrinkType] ?: HydrationCyan,
                            streakDays = uiState.insights?.streakDays ?: 0,
                            onDragAddMl = onDragAddMl,
                            onTap = onTapAnalytics,
                            modifier = Modifier.size(220.dp)
                        )
                    }
                }
                1 -> {
                    // Insights page
                    val insights = uiState.insights
                    val context = LocalContext.current
                    val fireIcon = remember {
                        context.assets.open("icons/fire.png").use { BitmapFactory.decodeStream(it) }.asImageBitmap()
                    }
                    val statisticsIcon = remember {
                        context.assets.open("icons/statistics.png").use { BitmapFactory.decodeStream(it) }.asImageBitmap()
                    }
                    val glassWaterIcon = remember {
                        context.assets.open("icons/glass-water.png").use { BitmapFactory.decodeStream(it) }.asImageBitmap()
                    }
                    val coffeeIcon = remember {
                        context.assets.open("icons/coffee.png").use { BitmapFactory.decodeStream(it) }.asImageBitmap()
                    }
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 24.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        if (insights != null) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                HeroInsightTile(
                                    icon = fireIcon,
                                    value = "${insights.streakDays}",
                                    label = "day streak",
                                    modifier = Modifier.weight(1f)
                                )
                                HeroInsightTile(
                                    icon = statisticsIcon,
                                    value = "${insights.avgDailyIntake}ml",
                                    label = "7-day avg",
                                    modifier = Modifier.weight(1f)
                                )
                            }
                            Spacer(Modifier.height(12.dp))
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                HeroInsightTile(
                                    icon = glassWaterIcon,
                                    value = insights.mostCommonDrink ?: "—",
                                    label = "fav drink",
                                    modifier = Modifier.weight(1f)
                                )
                                HeroInsightTile(
                                    icon = coffeeIcon,
                                    value = "${insights.caffeineCount}",
                                    label = "caffeine today",
                                    modifier = Modifier.weight(1f)
                                )
                            }
                        } else {
                            Text(
                                "Log drinks to see insights",
                                color = Color.White.copy(alpha = 0.7f),
                                fontSize = 14.sp,
                                textAlign = TextAlign.Center
                            )
                        }
                    }
                }
                else -> {}
            }
        }

        // Pagination dots
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 4.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            repeat(2) { index ->
                val isSelected = pagerState.currentPage == index
                Box(
                    modifier = Modifier
                        .padding(horizontal = 3.dp)
                        .size(if (isSelected) 8.dp else 6.dp)
                        .clip(CircleShape)
                        .background(
                            if (isSelected) Color.White
                            else Color.White.copy(alpha = 0.4f)
                        )
                )
            }
        }
    }
}

@Composable
private fun HeroInsightTile(
    icon: androidx.compose.ui.graphics.ImageBitmap,
    value: String,
    label: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.15f))
            .padding(vertical = 14.dp, horizontal = 12.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Image(
                bitmap = icon,
                contentDescription = null,
                modifier = Modifier.size(24.dp)
            )
            Text(
                text = value,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = label,
                fontSize = 11.sp,
                color = Color.White.copy(alpha = 0.7f)
            )
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

    val isDarkRing = isSystemInDarkTheme()
    Canvas(modifier = modifier.size(140.dp)) {
        val strokeWidth = 14.dp.toPx()
        val diameter = size.minDimension - strokeWidth
        val topLeft = Offset((size.width - diameter) / 2f, (size.height - diameter) / 2f)
        val arcSize = Size(diameter, diameter)

        drawArc(
            color = if (isDarkRing) Color.White.copy(alpha = 0.15f) else Color.Gray.copy(alpha = 0.15f),
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

// ─────────────────────────────────────
// MARK: - AddDrinkBottomSheet
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddDrinkBottomSheet(
    onDismiss: () -> Unit,
    onAddDrink: (DrinkType, Int) -> Unit,
    onShowUrineGuide: () -> Unit
) {
    val view = LocalView.current
    val isDark = isSystemInDarkTheme()
    var selectedDrinkType by remember { mutableStateOf(DrinkType.WATER) }
    var customAmountText by remember { mutableStateOf("") }
    val focusManager = androidx.compose.ui.platform.LocalFocusManager.current
    val sheetState = rememberModalBottomSheetState()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = if (isSystemInDarkTheme()) Color(0xFF0A0A0A) else Color.White,
        tonalElevation = 0.dp,
        dragHandle = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp, bottom = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .width(40.dp)
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(AppColors.onSurface.copy(alpha = 0.3f))
                )
            }
        }
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(0.dp)
        ) {
            // Title
            Text(
                "Add a drink",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface,
                modifier = Modifier.padding(start = 24.dp, end = 24.dp, top = 8.dp)
            )

            Spacer(Modifier.height(24.dp))

            // Drink type selector - horizontal scroll
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                contentPadding = PaddingValues(horizontal = 24.dp)
            ) {
                items(DrinkType.entries.toList()) { type ->
                    val selected = type == selectedDrinkType

                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier
                            .width(72.dp)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null
                            ) {
                                view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                selectedDrinkType = type
                            }
                    ) {
                        Box(
                            modifier = Modifier
                                .size(64.dp)
                                .clip(CircleShape)
                                .background(
                                    if (selected)
                                        Brush.linearGradient(
                                            listOf(
                                                HydrationCyan.copy(alpha = 0.2f),
                                                HydrationCyan.copy(alpha = 0.1f)
                                            )
                                        )
                                    else
                                        Brush.linearGradient(
                                            listOf(
                                                AppColors.surfaceVariant,
                                                AppColors.surfaceVariant
                                            )
                                        )
                                )
                                .border(
                                    width = if (selected) 2.dp else 0.dp,
                                    color = if (selected) HydrationCyan else Color.Transparent,
                                    shape = CircleShape
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            DrinkIcon(drinkType = type, size = 36.dp)
                        }
                        Text(
                            type.displayName,
                            fontSize = 11.sp,
                            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                            color = if (selected) HydrationCyan else AppColors.onSurface.copy(alpha = 0.7f),
                            textAlign = TextAlign.Center,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
            }

            Spacer(Modifier.height(28.dp))

            // Custom amount
            Column(
                modifier = Modifier.padding(horizontal = 24.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    "Custom Amount",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface.copy(alpha = 0.5f),
                    letterSpacing = 0.5.sp
                )

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(56.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(
                                if (isDark) Color(0xFF1C1C1E)
                                else Color(0xFFF8F9FA)
                            )
                            .padding(horizontal = 16.dp),
                        contentAlignment = Alignment.CenterStart
                    ) {
                        androidx.compose.foundation.text.BasicTextField(
                            value = customAmountText,
                            onValueChange = { v -> customAmountText = v.filter { it.isDigit() } },
                            textStyle = androidx.compose.ui.text.TextStyle(
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Medium,
                                color = AppColors.onSurface
                            ),
                            keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
                                keyboardType = androidx.compose.ui.text.input.KeyboardType.Number,
                                imeAction = androidx.compose.ui.text.input.ImeAction.Done
                            ),
                            keyboardActions = androidx.compose.foundation.text.KeyboardActions(
                                onDone = { focusManager.clearFocus() }
                            ),
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            decorationBox = { innerTextField ->
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Box(modifier = Modifier.weight(1f)) {
                                        if (customAmountText.isEmpty()) {
                                            Text(
                                                "Enter amount (ml)",
                                                fontSize = 15.sp,
                                                color = AppColors.onSurface.copy(alpha = 0.4f)
                                            )
                                        }
                                        innerTextField()
                                    }
                                    Text(
                                        "ml",
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = AppColors.onSurface.copy(alpha = 0.4f)
                                    )
                                }
                            }
                        )
                    }

                    Button(
                        onClick = {
                            val amount = customAmountText.toIntOrNull()
                            if (amount != null && amount > 0) {
                                view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                                onAddDrink(selectedDrinkType, amount)
                                customAmountText = ""
                                focusManager.clearFocus()
                                onDismiss()
                            }
                        },
                        enabled = customAmountText.isNotEmpty(),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = HydrationCyan,
                            contentColor = Color.White,
                            disabledContainerColor = AppColors.surfaceVariant,
                            disabledContentColor = AppColors.onSurface.copy(alpha = 0.3f)
                        ),
                        shape = RoundedCornerShape(16.dp),
                        modifier = Modifier.size(56.dp),
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Icon(
                            Icons.Default.Add,
                            contentDescription = "Add",
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
            }

            Spacer(Modifier.height(20.dp))

            // Urine guide footer
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp))
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                HydrationCyan.copy(alpha = 0.08f),
                                HydrationCyan.copy(alpha = 0.12f)
                            )
                        )
                    )
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) { onShowUrineGuide() }
                    .padding(vertical = 20.dp, horizontal = 24.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                            .background(HydrationCyan.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.Colorize,
                            contentDescription = null,
                            tint = HydrationCyan,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            "Check Hydration Level",
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.onSurface
                        )
                        Text(
                            "Use urine color guide",
                            fontSize = 12.sp,
                            color = AppColors.onSurface.copy(alpha = 0.6f)
                        )
                    }
                    Icon(
                        Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = AppColors.onSurface.copy(alpha = 0.3f),
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            Spacer(Modifier.height(20.dp))
        }
    }
}

// ─────────────────────────────────────
// MARK: - HydrationAnalyticsSheet
// ─────────────────────────────────────

// ─────────────────────────────────────
// MARK: - Overview Sheet (tap progress ring)
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HydrationOverviewSheet(
    uiState: HydrationUiState,
    onDismiss: () -> Unit
) {
    val isDark = isSystemInDarkTheme()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val insights = uiState.insights
    val context = LocalContext.current

    // State for period selection and drink filter
    var selectedPeriod by remember { mutableStateOf("Today") }
    var selectedFilter by remember { mutableStateOf<DrinkType?>(null) }

    // Load icons
    val fireIcon = remember {
        context.assets.open("icons/fire.png").use { BitmapFactory.decodeStream(it) }.asImageBitmap()
    }
    val statisticsIcon = remember {
        context.assets.open("icons/statistics.png").use { BitmapFactory.decodeStream(it) }.asImageBitmap()
    }
    val glassWaterIcon = remember {
        context.assets.open("icons/glass-water.png").use { BitmapFactory.decodeStream(it) }.asImageBitmap()
    }
    val coffeeIcon = remember {
        context.assets.open("icons/coffee.png").use { BitmapFactory.decodeStream(it) }.asImageBitmap()
    }

    // Calculate period data
    val daysToShow = when (selectedPeriod) {
        "Today" -> 1
        "7 Days" -> 7
        "30 Days" -> 30
        else -> 1
    }

    val periodEntries = remember(uiState.entries, selectedPeriod) {
        if (selectedPeriod == "Today") {
            uiState.todaysEntries
        } else {
            val today = LocalDate.now()
            uiState.entries.filter { entry ->
                try {
                    val entryDate = LocalDate.parse(entry.consumedAt.substring(0, 10))
                    !entryDate.isBefore(today.minusDays(daysToShow.toLong() - 1))
                } catch (e: Exception) {
                    false
                }
            }
        }
    }

    // Chart data for 7D/30D
    val chartData = remember(uiState.entries, selectedPeriod) {
        if (selectedPeriod != "Today") {
            val today = LocalDate.now()
            (0 until daysToShow).reversed().map { daysAgo ->
                val date = today.minusDays(daysAgo.toLong())
                val dateStr = date.toString()
                val dayEntries = uiState.entries.filter { it.consumedAt.startsWith(dateStr) }
                val totalMl = dayEntries.sumOf { it.effectiveMl }
                AnalyticsDataPoint(date = date, ml = totalMl, goalMet = totalMl >= uiState.effectiveGoalMl)
            }
        } else {
            emptyList()
        }
    }

    // Summary stats for selected period
    val periodAvg = if (chartData.isNotEmpty()) chartData.sumOf { it.ml } / chartData.size else 0
    val periodBest = chartData.maxOfOrNull { it.ml } ?: 0
    val goalMetDays = chartData.count { it.goalMet }
    val totalPeriodMl = chartData.sumOf { it.ml }

    // Hourly distribution data
    val hourlyData = remember(periodEntries) {
        val hourCounts = IntArray(24) { 0 }
        periodEntries.forEach { entry ->
            try {
                val hour = entry.consumedAt.substring(11, 13).toIntOrNull()
                if (hour != null && hour in 0..23) {
                    hourCounts[hour] += entry.effectiveMl
                }
            } catch (e: Exception) {
                // Ignore invalid timestamps
            }
        }
        hourCounts
    }

    // Available drink types in period
    val availableDrinkTypes = remember(periodEntries) {
        periodEntries.mapNotNull { entry ->
            try {
                DrinkType.fromDb(entry.drinkType)
            } catch (e: Exception) {
                null
            }
        }.distinct()
    }

    // Filtered drink breakdown
    val drinkBreakdown = remember(periodEntries, selectedFilter) {
        val filteredEntries = if (selectedFilter != null) {
            periodEntries.filter { entry ->
                try {
                    DrinkType.fromDb(entry.drinkType) == selectedFilter
                } catch (e: Exception) {
                    false
                }
            }
        } else {
            periodEntries
        }

        filteredEntries
            .groupBy { it.drinkType }
            .map { (typeStr, entries) ->
                val drinkType = try {
                    DrinkType.fromDb(typeStr)
                } catch (e: Exception) {
                    null
                }
                Triple(drinkType, entries.size, entries.sumOf { it.effectiveMl })
            }
            .filter { it.first != null }
            .sortedByDescending { it.third }
    }

    val totalBreakdownMl = drinkBreakdown.sumOf { it.third }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = if (isSystemInDarkTheme()) Color(0xFF0A0A0A) else Color.White,
        tonalElevation = 0.dp,
        dragHandle = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp, bottom = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .width(40.dp)
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(AppColors.onSurface.copy(alpha = 0.3f))
                )
            }
        }
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding(),
            contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // 1. Header
            item {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        "Hydration Analytics",
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.onSurface
                    )
                    Text(
                        "Your complete overview",
                        fontSize = 14.sp,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }

            // 2. Period Selector
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    listOf("Today", "7 Days", "30 Days").forEach { period ->
                        val isSelected = selectedPeriod == period
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(12.dp))
                                .background(
                                    if (isSelected) HydrationCyan
                                    else if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)
                                )
                                .clickable { selectedPeriod = period }
                                .padding(vertical = 12.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                period,
                                fontSize = 14.sp,
                                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                                color = if (isSelected) Color.White else AppColors.onSurface
                            )
                        }
                    }
                }
            }

            // 3. Chart / Progress
            if (selectedPeriod == "Today") {
                // Today's progress card
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(20.dp))
                            .background(
                                Brush.linearGradient(
                                    listOf(
                                        drinkAccentColors[uiState.dominantDrinkType] ?: HydrationCyan,
                                        (drinkAccentColors[uiState.dominantDrinkType] ?: HydrationCyan).copy(alpha = 0.7f)
                                    )
                                )
                            )
                            .padding(20.dp)
                    ) {
                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(
                                    "${uiState.effectiveIntake}ml",
                                    fontSize = 36.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White
                                )
                                Text(
                                    "of ${uiState.effectiveGoalMl}ml goal",
                                    fontSize = 14.sp,
                                    color = Color.White.copy(alpha = 0.9f)
                                )
                            }
                            Column(
                                horizontalAlignment = Alignment.End,
                                verticalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                Text(
                                    "${(uiState.progress * 100).toInt()}%",
                                    fontSize = 32.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White
                                )
                                Text(
                                    if (uiState.isGoalMet) "Goal met!" else "${uiState.remainingMl}ml left",
                                    fontSize = 13.sp,
                                    color = Color.White.copy(alpha = 0.9f)
                                )
                            }
                        }
                    }
                }
            } else {
                // 7D/30D chart
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            "DAILY INTAKE",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.onSurface.copy(alpha = 0.5f),
                            letterSpacing = 0.8.sp
                        )
                        HydrationBarChart(
                            data = chartData,
                            goalMl = uiState.effectiveGoalMl,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(200.dp)
                        )
                    }
                }
            }

            // 4. Period Summary (7D/30D only)
            if (selectedPeriod != "Today") {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            "PERIOD SUMMARY",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.onSurface.copy(alpha = 0.5f),
                            letterSpacing = 0.8.sp
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            AnalyticsMiniCard(
                                label = "Average",
                                value = "${periodAvg}ml",
                                modifier = Modifier.weight(1f)
                            )
                            AnalyticsMiniCard(
                                label = "Best Day",
                                value = "${periodBest}ml",
                                modifier = Modifier.weight(1f)
                            )
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            AnalyticsMiniCard(
                                label = "Goals Met",
                                value = "$goalMetDays / $daysToShow",
                                modifier = Modifier.weight(1f)
                            )
                            AnalyticsMiniCard(
                                label = "Total",
                                value = String.format("%.1fL", totalPeriodMl / 1000.0),
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                }
            }

            // 5. Goal Achievement (7D/30D only)
            if (selectedPeriod != "Today") {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            "GOAL ACHIEVEMENT",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.onSurface.copy(alpha = 0.5f),
                            letterSpacing = 0.8.sp
                        )
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(16.dp))
                                .background(if (isDark) Color(0xFF1C1C1E) else Color(0xFFF8F9FA))
                                .padding(16.dp)
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        "Days goal was met",
                                        fontSize = 14.sp,
                                        color = AppColors.onSurface
                                    )
                                    Text(
                                        "${if (daysToShow > 0) (goalMetDays * 100 / daysToShow) else 0}%",
                                        fontSize = 16.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (goalMetDays > daysToShow / 2) Color(0xFF34C759) else HydrationCyan
                                    )
                                }
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(8.dp)
                                        .clip(RoundedCornerShape(4.dp))
                                        .background(AppColors.onSurface.copy(alpha = 0.1f))
                                ) {
                                    val achievementPct = if (daysToShow > 0)
                                        goalMetDays.toFloat() / daysToShow else 0f
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth(achievementPct)
                                            .fillMaxHeight()
                                            .clip(RoundedCornerShape(4.dp))
                                            .background(
                                                if (goalMetDays > daysToShow / 2) Color(0xFF34C759)
                                                else HydrationCyan
                                            )
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // 6. Drink Type Filter + Breakdown
            item {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        "DRINK BREAKDOWN",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.onSurface.copy(alpha = 0.5f),
                        letterSpacing = 0.8.sp
                    )

                    // Filter chips
                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        // "All" chip
                        item {
                            val isSelected = selectedFilter == null
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(
                                        if (isSelected) HydrationCyan
                                        else if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)
                                    )
                                    .clickable { selectedFilter = null }
                                    .padding(horizontal = 16.dp, vertical = 8.dp)
                            ) {
                                Text(
                                    "All",
                                    fontSize = 13.sp,
                                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                                    color = if (isSelected) Color.White else AppColors.onSurface
                                )
                            }
                        }

                        // Drink type chips
                        items(availableDrinkTypes) { drinkType ->
                            val isSelected = selectedFilter == drinkType
                            val accentColor = drinkAccentColors[drinkType] ?: HydrationCyan
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(
                                        if (isSelected) accentColor
                                        else if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)
                                    )
                                    .clickable { selectedFilter = drinkType }
                                    .padding(horizontal = 16.dp, vertical = 8.dp)
                            ) {
                                Text(
                                    drinkType.displayName,
                                    fontSize = 13.sp,
                                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                                    color = if (isSelected) Color.White else AppColors.onSurface
                                )
                            }
                        }
                    }

                    // Drink breakdown list
                    if (drinkBreakdown.isNotEmpty()) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(16.dp))
                                .background(if (isDark) Color(0xFF1C1C1E) else Color(0xFFF8F9FA))
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            drinkBreakdown.forEach { (drinkType, count, totalMl) ->
                                drinkType?.let { type ->
                                    val proportion = if (totalBreakdownMl > 0) totalMl.toFloat() / totalBreakdownMl else 0f
                                    val accentColor = drinkAccentColors[type] ?: HydrationCyan

                                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Row(
                                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                DrinkIcon(drinkType = type, size = 32.dp)
                                                Column {
                                                    Text(
                                                        type.displayName,
                                                        fontSize = 15.sp,
                                                        fontWeight = FontWeight.Medium,
                                                        color = AppColors.onSurface
                                                    )
                                                    Text(
                                                        "$count ${if (count == 1) "drink" else "drinks"}",
                                                        fontSize = 12.sp,
                                                        color = AppColors.onSurfaceVariant
                                                    )
                                                }
                                            }
                                            Text(
                                                "${totalMl}ml",
                                                fontSize = 16.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = AppColors.onSurface
                                            )
                                        }

                                        // Proportion bar
                                        Box(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .height(4.dp)
                                                .clip(RoundedCornerShape(2.dp))
                                                .background(AppColors.onSurface.copy(alpha = 0.1f))
                                        ) {
                                            Box(
                                                modifier = Modifier
                                                    .fillMaxWidth(proportion)
                                                    .fillMaxHeight()
                                                    .clip(RoundedCornerShape(2.dp))
                                                    .background(accentColor)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 7. Statistics Grid
            if (insights != null) {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            "STATISTICS",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.onSurface.copy(alpha = 0.5f),
                            letterSpacing = 0.8.sp
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            AnalyticsStatCard(
                                label = "Streak",
                                value = "${insights.streakDays}",
                                unit = "days",
                                icon = fireIcon,
                                modifier = Modifier.weight(1f)
                            )
                            AnalyticsStatCard(
                                label = "7-Day Avg",
                                value = "${insights.avgDailyIntake}",
                                unit = "ml",
                                icon = statisticsIcon,
                                modifier = Modifier.weight(1f)
                            )
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            AnalyticsStatCard(
                                label = "Favorite",
                                value = insights.mostCommonDrink ?: "—",
                                unit = "",
                                icon = glassWaterIcon,
                                modifier = Modifier.weight(1f)
                            )
                            AnalyticsStatCard(
                                label = "Caffeine",
                                value = "${insights.caffeineCount}",
                                unit = "drinks",
                                icon = coffeeIcon,
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                }
            }

            // 8. Hourly Distribution Chart
            if (hourlyData.any { it > 0 }) {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            "DRINKING PATTERNS",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.onSurface.copy(alpha = 0.5f),
                            letterSpacing = 0.8.sp
                        )
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(180.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .background(if (isDark) Color(0xFF1C1C1E) else Color(0xFFF8F9FA))
                                .padding(16.dp)
                        ) {
                            val maxValue = hourlyData.maxOrNull() ?: 1
                            Canvas(modifier = Modifier.fillMaxSize()) {
                                val barWidth = size.width / 24f
                                val chartHeight = size.height - 30f

                                // Draw bars
                                hourlyData.forEachIndexed { hour, ml ->
                                    if (ml > 0) {
                                        val barHeight = (ml.toFloat() / maxValue) * chartHeight
                                        val x = hour * barWidth + barWidth * 0.2f
                                        val width = barWidth * 0.6f
                                        val y = chartHeight - barHeight

                                        drawRect(
                                            color = HydrationCyan,
                                            topLeft = Offset(x, y),
                                            size = Size(width, barHeight)
                                        )
                                    }
                                }

                                // Draw hour labels (every 4th hour)
                                val hourLabels = listOf(
                                    0 to "12a", 4 to "4a", 8 to "8a",
                                    12 to "12p", 16 to "4p", 20 to "8p"
                                )
                                hourLabels.forEach { (hour, label) ->
                                    val x = hour * barWidth + barWidth / 2f
                                    drawContext.canvas.nativeCanvas.drawText(
                                        label,
                                        x,
                                        size.height,
                                        android.graphics.Paint().apply {
                                            color = if (isDark) 0x80FFFFFF.toInt() else 0x80000000.toInt()
                                            textSize = 24f
                                            textAlign = android.graphics.Paint.Align.CENTER
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // 9. Weather Adjustment
            if (uiState.isWeatherAdjusted && uiState.weatherData != null) {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            "WEATHER ADJUSTMENT",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AppColors.onSurface.copy(alpha = 0.5f),
                            letterSpacing = 0.8.sp
                        )
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(16.dp))
                                .background(Color(0xFFFF9500).copy(alpha = 0.1f))
                                .border(1.dp, Color(0xFFFF9500).copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                                .padding(16.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text(
                                        "Goal adjusted for hot weather",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = AppColors.onSurface
                                    )
                                    Text(
                                        "${uiState.weatherData!!.city} • ${uiState.weatherData!!.temperatureCelsius}°C",
                                        fontSize = 12.sp,
                                        color = AppColors.onSurfaceVariant
                                    )
                                }
                                Text(
                                    "+${((uiState.weatherAdjustmentFactor - 1) * 100).toInt()}%",
                                    fontSize = 20.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFFFF9500)
                                )
                            }
                        }
                    }
                }
            }

            // 10. Bottom Spacer
            item {
                Spacer(Modifier.height(20.dp))
            }
        }
    }
}

@Composable
private fun AnalyticsStatCard(
    label: String,
    value: String,
    unit: String,
    icon: androidx.compose.ui.graphics.ImageBitmap,
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(if (isDark) Color(0xFF1C1C1E) else Color(0xFFF8F9FA))
            .padding(16.dp)
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalAlignment = Alignment.Start
        ) {
            Image(
                bitmap = icon,
                contentDescription = null,
                modifier = Modifier.size(32.dp)
            )
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        value,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.onSurface
                    )
                    if (unit.isNotEmpty()) {
                        Text(
                            unit,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                            color = AppColors.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 2.dp)
                        )
                    }
                }
                Text(
                    label,
                    fontSize = 12.sp,
                    color = AppColors.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun AnalyticsMiniCard(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(if (isDark) Color(0xFF1C1C1E) else Color(0xFFF8F9FA))
            .padding(16.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                label,
                fontSize = 12.sp,
                color = AppColors.onSurfaceVariant
            )
            Text(
                value,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
        }
    }
}

@Composable
private fun AnalyticsDrinkBreakdown(uiState: HydrationUiState) {
    val isDark = isSystemInDarkTheme()

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            "TODAY'S DRINKS",
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface.copy(alpha = 0.5f),
            letterSpacing = 0.8.sp
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(if (isDark) Color(0xFF1C1C1E) else Color(0xFFF8F9FA))
                .padding(16.dp)
        ) {
            val drinkBreakdown = uiState.todaysEntries
                .groupBy { DrinkType.fromDb(it.drinkType) }
                .mapValues { it.value.sumOf { e -> e.amountMl } }
                .toList()
                .sortedByDescending { it.second }

            if (drinkBreakdown.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    drinkBreakdown.forEach { (drinkType, ml) ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(40.dp)
                                        .clip(CircleShape)
                                        .background(
                                            (drinkAccentColors[drinkType] ?: HydrationCyan)
                                                .copy(alpha = 0.15f)
                                        ),
                                    contentAlignment = Alignment.Center
                                ) {
                                    DrinkIcon(drinkType = drinkType, size = 24.dp)
                                }
                                Column {
                                    Text(
                                        drinkType.displayName,
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = AppColors.onSurface
                                    )
                                    Text(
                                        "${uiState.todaysEntries.count { DrinkType.fromDb(it.drinkType) == drinkType }} drinks",
                                        fontSize = 12.sp,
                                        color = AppColors.onSurfaceVariant
                                    )
                                }
                            }
                            Text(
                                "${ml}ml",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = drinkAccentColors[drinkType] ?: HydrationCyan
                            )
                        }
                    }
                }
            } else {
                Text(
                    "No drinks logged yet today",
                    fontSize = 14.sp,
                    color = AppColors.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Data Models & Chart
// ─────────────────────────────────────

private data class AnalyticsDataPoint(
    val date: LocalDate,
    val ml: Int,
    val goalMet: Boolean
)

@Composable
private fun HydrationBarChart(
    data: List<AnalyticsDataPoint>,
    goalMl: Int,
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()
    val maxMl = maxOf(goalMl, data.maxOfOrNull { it.ml } ?: 0)

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(if (isDark) Color(0xFF1C1C1E) else Color(0xFFF8F9FA))
            .padding(16.dp)
    ) {
        Canvas(
            modifier = Modifier.fillMaxSize()
        ) {
            val barWidth = (size.width / data.size) * 0.6f
            val spacing = (size.width / data.size) * 0.4f
            val chartHeight = size.height - 40.dp.toPx()

            // Draw goal line
            val goalY = chartHeight - (goalMl.toFloat() / maxMl) * chartHeight
            drawLine(
                color = if (isDark) Color(0xFF3A3A3C) else Color(0xFFD1D1D6),
                start = Offset(0f, goalY),
                end = Offset(size.width, goalY),
                strokeWidth = 2.dp.toPx(),
                pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(
                    floatArrayOf(8f, 8f)
                )
            )

            // Draw bars
            data.forEachIndexed { index, point ->
                val barHeight = if (maxMl > 0) {
                    (point.ml.toFloat() / maxMl) * chartHeight
                } else 0f
                val x = index * (barWidth + spacing) + spacing / 2f
                val y = chartHeight - barHeight

                drawRoundRect(
                    color = if (point.goalMet) Color(0xFF34C759) else HydrationCyan,
                    topLeft = Offset(x, y),
                    size = Size(barWidth, barHeight),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(6.dp.toPx())
                )

                // Draw date label
                val dateText = if (data.size <= 7) {
                    point.date.dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault()).take(1)
                } else {
                    point.date.dayOfMonth.toString()
                }
                drawContext.canvas.nativeCanvas.apply {
                    val paint = android.graphics.Paint().apply {
                        color = if (isDark) 0xFF9C9C9E.toInt() else 0xFF8E8E93.toInt()
                        textSize = 11.sp.toPx()
                        textAlign = android.graphics.Paint.Align.CENTER
                    }
                    drawText(
                        dateText,
                        x + barWidth / 2f,
                        size.height - 8.dp.toPx(),
                        paint
                    )
                }
            }
        }
    }
}
