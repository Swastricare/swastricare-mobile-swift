package com.swasthicare.mobile.ui.screens.diet

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.models.DietGoals
import com.swasthicare.mobile.data.models.DietLogEntry
import com.swasthicare.mobile.data.models.FoodCategory
import com.swasthicare.mobile.data.models.FoodItem
import com.swasthicare.mobile.data.models.MealType
import com.swasthicare.mobile.data.models.NutritionSummary
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

// ─────────────────────────────────────
// MARK: - Brand Colors
// ─────────────────────────────────────

val DietGreen = Color(0xFF34C759)        // iOS .green
val DietOrange = Color(0xFFFF9500)       // iOS .orange
val DietBlue = Color(0xFF007AFF)         // iOS .blue
val DietPurple = Color(0xFF9B59B6)       // iOS .purple
val DietBrandBlue = Color(0xFF2E3192)    // Shared brand blue

fun MealType.accentColor(): Color = when (this) {
    MealType.BREAKFAST -> Color(0xFFFF9500)
    MealType.MORNING_SNACK -> Color(0xFF8B6914)
    MealType.LUNCH -> Color(0xFFFFCC00)
    MealType.EVENING_SNACK -> DietGreen
    MealType.DINNER -> Color(0xFF007AFF)
    MealType.LATE_NIGHT -> Color(0xFF9B59B6)
}

fun MealType.iconVector(): ImageVector = when (this) {
    MealType.BREAKFAST -> Icons.Default.WbSunny
    MealType.MORNING_SNACK -> Icons.Default.LocalCafe
    MealType.LUNCH -> Icons.Default.LightMode
    MealType.EVENING_SNACK -> Icons.Default.EmojiNature
    MealType.DINNER -> Icons.Default.Bedtime
    MealType.LATE_NIGHT -> Icons.Default.NightlightRound
}

// ─────────────────────────────────────
// MARK: - DietCalendarStrip
// ─────────────────────────────────────

/**
 * 7-day strip centered on today (iOS: index - 3 offset).
 * Selected circle uses DietGreen.
 */
@Composable
fun DietCalendarStrip(
    selectedDate: LocalDate,
    onDateSelected: (LocalDate) -> Unit,
    modifier: Modifier = Modifier
) {
    val today = LocalDate.now()
    // Center on today: -3 days to +3 days
    val dates = (-3..3).map { today.plusDays(it.toLong()) }

    LazyRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(horizontal = 20.dp)
    ) {
        items(dates) { date ->
            val isToday = date == today
            val isSelected = date == selectedDate
            DietCalendarDay(
                date = date,
                isToday = isToday,
                isSelected = isSelected,
                onClick = { onDateSelected(date) }
            )
        }
    }
}

@Composable
private fun DietCalendarDay(
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
                color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
            )
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(
                        if (isSelected) DietGreen else Color.Transparent,
                        CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = date.dayOfMonth.toString(),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface
                )
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - CalorieProgressRing
// ─────────────────────────────────────

/**
 * Circular progress ring showing calorie progress.
 * Matches iOS CalorieProgressRing hero component.
 */
@Composable
fun CalorieProgressRing(
    current: Int,
    goal: Int,
    progress: Float,
    modifier: Modifier = Modifier
) {
    val animatedProgress by animateFloatAsState(
        targetValue = progress,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 200f),
        label = "calorieRing"
    )
    val ringColor = when {
        progress >= 1f -> DietOrange   // Over goal
        progress >= 0.7f -> DietGreen  // Nearly there
        else -> DietGreen
    }

    Box(
        modifier = modifier.size(140.dp),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val strokeWidth = 16.dp.toPx()
            val diameter = size.minDimension - strokeWidth
            val topLeft = Offset((size.width - diameter) / 2f, (size.height - diameter) / 2f)
            val arcSize = Size(diameter, diameter)

            // Background track
            drawArc(
                color = Color.Gray.copy(alpha = 0.15f),
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )
            // Progress arc
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

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = "$current",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = "of $goal cal",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - DietStatPill
// ─────────────────────────────────────

/**
 * Icon + value + label. Matches iOS dietStatPill.
 */
@Composable
fun DietStatPill(
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
            modifier = Modifier.size(14.sp.value.dp)
        )
        Text(
            text = value,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )
        Text(
            text = label,
            fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            maxLines = 1,
            textAlign = TextAlign.Center
        )
    }
}

// ─────────────────────────────────────
// MARK: - MacroBreakdownCard
// ─────────────────────────────────────

/**
 * Protein / Carbs / Fat progress bars. Matches iOS MacroBreakdownCard.
 */
@Composable
fun MacroBreakdownCard(
    summary: NutritionSummary,
    goals: DietGoals,
    proteinProgress: Float,
    carbsProgress: Float,
    fatProgress: Float,
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
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "Macro Breakdown",
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
        )
        MacroRow(
            label = "Protein",
            current = summary.totalProteinG.toInt(),
            goal = goals.proteinGrams,
            progress = proteinProgress,
            color = Color(0xFFFF6B6B)
        )
        MacroRow(
            label = "Carbs",
            current = summary.totalCarbsG.toInt(),
            goal = goals.carbsGrams,
            progress = carbsProgress,
            color = Color(0xFF4ECDC4)
        )
        MacroRow(
            label = "Fat",
            current = summary.totalFatG.toInt(),
            goal = goals.fatGrams,
            progress = fatProgress,
            color = Color(0xFFFFD93D)
        )
    }
}

@Composable
private fun MacroRow(
    label: String,
    current: Int,
    goal: Int,
    progress: Float,
    color: Color
) {
    val animatedProgress by animateFloatAsState(
        targetValue = progress,
        animationSpec = tween(600),
        label = "macro_$label"
    )
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(label, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface)
            Text(
                "${current}g / ${goal}g",
                fontSize = 13.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
            )
        }
        LinearProgressIndicator(
            progress = { animatedProgress },
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(6.dp)),
            color = color,
            trackColor = color.copy(alpha = 0.15f)
        )
    }
}

// ─────────────────────────────────────
// MARK: - MealSectionCard
// ─────────────────────────────────────

/**
 * Collapsible meal section with food log entries.
 * Matches iOS MealSectionCard.
 */
@Composable
fun MealSectionCard(
    mealType: MealType,
    entries: List<DietLogEntry>,
    onDelete: (DietLogEntry) -> Unit,
    onAddFood: () -> Unit,
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()
    val cardBg = if (isDark) Color(0xFF1C1C1E) else Color(0xFFF2F2F7)
    var expanded by remember { mutableStateOf(true) }
    val mealCalories = entries.sumOf { it.calories }.toInt()
    val accent = mealType.accentColor()

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(cardBg)
    ) {
        // Header row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ) { expanded = !expanded }
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Meal icon
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(accent.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = mealType.iconVector(),
                    contentDescription = null,
                    tint = accent,
                    modifier = Modifier.size(18.dp)
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    mealType.displayName,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                if (entries.isNotEmpty()) {
                    Text(
                        "$mealCalories cal · ${entries.size} item${if (entries.size == 1) "" else "s"}",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                    )
                } else {
                    Text(
                        mealType.typicalTime,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                    )
                }
            }
            // Add button
            IconButton(onClick = onAddFood, modifier = Modifier.size(36.dp)) {
                Icon(
                    Icons.Default.AddCircle,
                    contentDescription = "Add food",
                    tint = accent,
                    modifier = Modifier.size(22.dp)
                )
            }
            // Expand/collapse
            Icon(
                imageVector = if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                modifier = Modifier.size(20.dp)
            )
        }

        // Food entries
        if (expanded && entries.isNotEmpty()) {
            Divider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f))
            entries.forEachIndexed { index, entry ->
                FoodEntryRow(
                    entry = entry,
                    onDelete = { onDelete(entry) }
                )
                if (index < entries.lastIndex) {
                    Divider(
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.04f),
                        modifier = Modifier.padding(start = 60.dp)
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - FoodEntryRow
// ─────────────────────────────────────

@Composable
fun FoodEntryRow(
    entry: DietLogEntry,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Generic food icon
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(DietGreen.copy(alpha = 0.1f)),
            contentAlignment = Alignment.Center
        ) {
            Text(text = "🍽️", fontSize = 22.sp)
        }
        // Name + quantity
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                text = entry.foodName,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = "${entry.quantity.toInt()} ${entry.servingUnitEnum.displayName} · ${entry.calories.toInt()} cal",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
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
// MARK: - FoodItemRow
// ─────────────────────────────────────

/**
 * Food search result row. Matches iOS FoodItemRow.
 */
@Composable
fun FoodItemRow(
    food: FoodItem,
    onSelect: () -> Unit,
    isFavorite: Boolean = false,
    onToggleFavorite: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onSelect() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Category icon
        Box(
            modifier = Modifier
                .size(50.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(DietGreen.copy(alpha = 0.1f)),
            contentAlignment = Alignment.Center
        ) {
            Text(food.categoryEnum.icon, fontSize = 28.sp)
        }

        // Food details
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Text(
                text = food.name,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (food.brand != null) {
                Text(
                    text = food.brand,
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                )
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = food.displayServingSize,
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                )
                Text("·", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                Text(
                    text = food.caloriesPerServing,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = DietGreen
                )
            }
            Text(
                text = food.macroSummary,
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
            )
        }

        // Favorite toggle
        if (onToggleFavorite != null) {
            IconButton(onClick = onToggleFavorite, modifier = Modifier.size(36.dp)) {
                Icon(
                    imageVector = if (isFavorite) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                    contentDescription = if (isFavorite) "Unfavorite" else "Favorite",
                    tint = if (isFavorite) Color(0xFFFF2D55) else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                    modifier = Modifier.size(20.dp)
                )
            }
        }

        // Add button
        Icon(
            Icons.Default.AddCircle,
            contentDescription = "Add",
            tint = DietGreen,
            modifier = Modifier.size(26.dp)
        )
    }
}
