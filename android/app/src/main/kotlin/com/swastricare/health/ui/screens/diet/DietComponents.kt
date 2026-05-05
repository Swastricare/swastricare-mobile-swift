package com.swastricare.health.ui.screens.diet

import android.graphics.BitmapFactory
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.DietGoals
import com.swastricare.health.data.models.DietLogEntry
import com.swastricare.health.data.models.FoodItem
import com.swastricare.health.data.models.MealType
import com.swastricare.health.data.models.NutritionSummary
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.NutritionCarbs
import com.swastricare.health.ui.theme.NutritionFat
import com.swastricare.health.ui.theme.NutritionProtein

// ─────────────────────────────────────
// MARK: - Brand Colors
// ─────────────────────────────────────

val DietGreen = Color(0xFF34C759)
val DietOrange = Color(0xFFFF9500)
val DietBlue = Color(0xFF007AFF)
val DietPurple = Color(0xFF9B59B6)
val DietBrandBlue = Color(0xFF2E3192)

// Accent colors for the redesigned screen.
val DietAccent = AITeal                  // primary teal (#22C5A6)
val DietAccentSoft = Color(0xFFE6FAF5)   // pale mint card backgrounds
val DietHeroSurface = Color(0xFFEEFBF7)  // hero banner backdrop

private val CardShadowColor = Color(0xFF0F172A).copy(alpha = 0.40f)

/** Shadow style matching the Activity screen cards. */
fun Modifier.dietCardShadow(
    radius: androidx.compose.ui.unit.Dp = 18.dp,
    elevation: androidx.compose.ui.unit.Dp = 6.dp
): Modifier = this.shadow(
    elevation = elevation,
    shape = RoundedCornerShape(radius),
    ambientColor = CardShadowColor,
    spotColor = CardShadowColor
)

fun MealType.accentColor(): Color = when (this) {
    MealType.BREAKFAST -> Color(0xFFFFB020)
    MealType.MORNING_SNACK -> Color(0xFF8B6914)
    MealType.LUNCH -> Color(0xFFFFA000)
    MealType.EVENING_SNACK -> DietAccent
    MealType.DINNER -> Color(0xFF6C7BFF)
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

private fun MealType.shortTime(): String = when (this) {
    MealType.BREAKFAST -> "8:30 AM"
    MealType.MORNING_SNACK -> "10:30 AM"
    MealType.LUNCH -> "1:00 PM"
    MealType.EVENING_SNACK -> "4:30 PM"
    MealType.DINNER -> "7:30 PM"
    MealType.LATE_NIGHT -> "10:30 PM"
}

// ─────────────────────────────────────
// MARK: - Asset image cache
// ─────────────────────────────────────

@Composable
private fun rememberAssetBitmap(path: String): ImageBitmap? {
    val context = LocalContext.current
    return remember(path) {
        runCatching {
            context.assets.open(path).use { BitmapFactory.decodeStream(it) }.asImageBitmap()
        }.getOrNull()
    }
}

// ─────────────────────────────────────
// MARK: - DietHeroBanner
// ─────────────────────────────────────

@Composable
fun DietHeroBanner(modifier: Modifier = Modifier) {
    val bitmap = rememberAssetBitmap("images/diet screen hero illustration.png")
    Box(modifier = modifier.fillMaxWidth()) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap,
                contentDescription = null,
                modifier = Modifier.fillMaxWidth(),
                contentScale = ContentScale.FillWidth
            )
        } else {
            Spacer(Modifier.fillMaxWidth().height(180.dp))
        }
        // Top + bottom blend so the illustration fades into the white screen
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(
                    brush = androidx.compose.ui.graphics.Brush.verticalGradient(
                        colorStops = arrayOf(
                            0.00f to Color.White,
                            0.18f to Color.Transparent,
                            0.82f to Color.Transparent,
                            1.00f to Color.White
                        )
                    )
                )
        )
    }
}

// ─────────────────────────────────────
// MARK: - Today's Progress Card
// ─────────────────────────────────────

/**
 * Donut + macro list. Donut shows calorie progress;
 * the right column lists Calories / Protein / Carbs / Fats with mini bars.
 */
@Composable
fun TodaysProgressCard(
    summary: NutritionSummary,
    goals: DietGoals,
    calorieProgress: Float,
    proteinProgress: Float,
    carbsProgress: Float,
    fatProgress: Float,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .dietCardShadow(radius = 20.dp, elevation = 6.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(Color.White)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "Today's Progress",
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.onSurface
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            CalorieDonut(
                current = summary.totalCalories.toInt(),
                goal = goals.dailyCalories,
                progress = calorieProgress,
                modifier = Modifier.size(132.dp)
            )

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                ProgressLine(
                    color = DietAccent,
                    label = "Calories",
                    value = "${summary.totalCalories.toInt()} / ${goals.dailyCalories}",
                    progress = calorieProgress
                )
                ProgressLine(
                    color = NutritionProtein,
                    label = "Protein",
                    value = "${summary.totalProteinG.toInt()} / ${goals.proteinGrams}",
                    progress = proteinProgress
                )
                ProgressLine(
                    color = NutritionCarbs,
                    label = "Carbs",
                    value = "${summary.totalCarbsG.toInt()} / ${goals.carbsGrams}",
                    progress = carbsProgress
                )
                ProgressLine(
                    color = NutritionFat,
                    label = "Fats",
                    value = "${summary.totalFatG.toInt()} / ${goals.fatGrams}",
                    progress = fatProgress
                )
            }
        }
    }
}

@Composable
private fun CalorieDonut(
    current: Int,
    goal: Int,
    progress: Float,
    modifier: Modifier = Modifier
) {
    val animated by animateFloatAsState(
        targetValue = progress,
        animationSpec = spring(dampingRatio = 0.75f, stiffness = 180f),
        label = "calorieDonut"
    )
    val pct = ((if (goal > 0) current.toFloat() / goal else 0f) * 100).toInt()

    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val stroke = 14.dp.toPx()
            val diameter = size.minDimension - stroke
            val topLeft = Offset((size.width - diameter) / 2f, (size.height - diameter) / 2f)
            val arcSize = Size(diameter, diameter)

            drawArc(
                color = DietAccent.copy(alpha = 0.12f),
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = stroke, cap = StrokeCap.Round)
            )
            drawArc(
                color = DietAccent,
                startAngle = -90f,
                sweepAngle = 360f * animated,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = stroke, cap = StrokeCap.Round)
            )
        }

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                "$current",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface
            )
            Text(
                "/ $goal kcal",
                fontSize = 11.sp,
                color = AppColors.onSurface.copy(alpha = 0.5f)
            )
            Spacer(Modifier.height(4.dp))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(DietAccent.copy(alpha = 0.12f))
                    .padding(horizontal = 8.dp, vertical = 2.dp)
            ) {
                Text(
                    "$pct%",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = DietAccent
                )
            }
        }
    }
}

@Composable
private fun ProgressLine(
    color: Color,
    label: String,
    value: String,
    progress: Float
) {
    val animated by animateFloatAsState(
        targetValue = progress,
        animationSpec = tween(600),
        label = "macroLine_$label"
    )
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(color)
                )
                Text(
                    label,
                    fontSize = 12.sp,
                    color = AppColors.onSurface.copy(alpha = 0.7f)
                )
            }
            Text(
                value,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface
            )
        }
        LinearProgressIndicator(
            progress = { animated },
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp)
                .clip(RoundedCornerShape(4.dp)),
            color = color,
            trackColor = color.copy(alpha = 0.12f)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Macro Chip Row
// ─────────────────────────────────────

/**
 * 4-up chip strip showing macro current/target.
 */
@Composable
fun MacroChipRow(
    summary: NutritionSummary,
    goals: DietGoals,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        MacroChip(
            label = "Protein",
            value = "${summary.totalProteinG.toInt()}g",
            target = "Target ${goals.proteinGrams}g",
            color = NutritionProtein,
            modifier = Modifier.weight(1f)
        )
        MacroChip(
            label = "Carbs",
            value = "${summary.totalCarbsG.toInt()}g",
            target = "Target ${goals.carbsGrams}g",
            color = NutritionCarbs,
            modifier = Modifier.weight(1f)
        )
        MacroChip(
            label = "Fats",
            value = "${summary.totalFatG.toInt()}g",
            target = "Target ${goals.fatGrams}g",
            color = NutritionFat,
            modifier = Modifier.weight(1f)
        )
        MacroChip(
            label = "Fiber",
            value = "${summary.totalFiberG.toInt()}g",
            target = "Target 30g",
            color = DietAccent,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun MacroChip(
    label: String,
    value: String,
    target: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .dietCardShadow(radius = 14.dp, elevation = 4.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White)
            .padding(horizontal = 10.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(color)
            )
            Text(
                label,
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                color = color
            )
        }
        Text(
            value,
            fontSize = 17.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface
        )
        Text(
            target,
            fontSize = 10.sp,
            color = AppColors.onSurface.copy(alpha = 0.45f),
            maxLines = 1
        )
    }
}

// ─────────────────────────────────────
// MARK: - Compact Meal Row
// ─────────────────────────────────────

/**
 * Single horizontal meal row. Tappable to add food.
 * Long-press first entry to delete (handled separately).
 */
@Composable
fun CompactMealRow(
    mealType: MealType,
    entries: List<DietLogEntry>,
    onAddFood: () -> Unit,
    onDelete: (DietLogEntry) -> Unit,
    modifier: Modifier = Modifier
) {
    val accent = mealType.accentColor()
    val totalCal = entries.sumOf { it.calories }.toInt()
    val totalProtein = entries.sumOf { it.proteinG }.toInt()
    val totalCarbs = entries.sumOf { it.carbsG }.toInt()
    val totalFat = entries.sumOf { it.fatG }.toInt()
    val hasEntries = entries.isNotEmpty()

    Row(
        modifier = modifier
            .fillMaxWidth()
            .dietCardShadow(radius = 16.dp, elevation = 5.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onAddFood() }
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Leading icon
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(accent.copy(alpha = 0.14f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = mealType.iconVector(),
                contentDescription = null,
                tint = accent,
                modifier = Modifier.size(20.dp)
            )
        }

        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                mealType.displayName,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface
            )
            Text(
                if (hasEntries) entries.first().foodName else mealType.shortTime(),
                fontSize = 12.sp,
                color = AppColors.onSurface.copy(alpha = 0.5f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (hasEntries) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    MacroLetter("P", "${totalProtein}g", NutritionProtein)
                    MacroLetter("C", "${totalCarbs}g", NutritionCarbs)
                    MacroLetter("F", "${totalFat}g", NutritionFat)
                }
            }
        }

        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            if (hasEntries) {
                Text(
                    "$totalCal kcal",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = DietOrange
                )
                if (entries.size > 1) {
                    Text(
                        "${entries.size} items",
                        fontSize = 10.sp,
                        color = AppColors.onSurface.copy(alpha = 0.4f)
                    )
                } else {
                    IconButton(
                        onClick = { onDelete(entries.first()) },
                        modifier = Modifier.size(24.dp)
                    ) {
                        Icon(
                            Icons.Default.RemoveCircleOutline,
                            contentDescription = "Remove",
                            tint = Color(0xFFFF3B30).copy(alpha = 0.55f),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            } else {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(accent.copy(alpha = 0.14f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.Add,
                        contentDescription = "Add",
                        tint = accent,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun MacroLetter(letter: String, value: String, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            "$letter ",
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = color
        )
        Text(
            value,
            fontSize = 11.sp,
            color = AppColors.onSurface.copy(alpha = 0.55f)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Water Intake Card (decorative link)
// ─────────────────────────────────────

@Composable
fun WaterIntakeCard(
    consumedGlasses: Int,
    goalGlasses: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .dietCardShadow(radius = 16.dp, elevation = 5.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(38.dp)
                .clip(CircleShape)
                .background(DietBlue.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.WaterDrop,
                contentDescription = null,
                tint = DietBlue,
                modifier = Modifier.size(20.dp)
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "Water Intake",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface
                )
                Text(
                    "$consumedGlasses / $goalGlasses",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.onSurface.copy(alpha = 0.55f)
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                repeat(goalGlasses.coerceAtMost(8)) { idx ->
                    val filled = idx < consumedGlasses
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(20.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(
                                if (filled) DietBlue.copy(alpha = 0.85f)
                                else DietBlue.copy(alpha = 0.12f)
                            )
                    )
                }
            }
        }
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = AppColors.onSurface.copy(alpha = 0.3f)
        )
    }
}

// ─────────────────────────────────────
// MARK: - FoodEntryRow (kept for reuse)
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
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(DietAccent.copy(alpha = 0.1f)),
            contentAlignment = Alignment.Center
        ) {
            Text(text = "🍽️", fontSize = 22.sp)
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                text = entry.foodName,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = "${entry.quantity.toInt()} ${entry.servingUnitEnum.displayName} · ${entry.calories.toInt()} cal",
                fontSize = 12.sp,
                color = AppColors.onSurface.copy(alpha = 0.5f)
            )
        }
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
// MARK: - FoodItemRow (used by AddFood / Search screens)
// ─────────────────────────────────────

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
        Box(
            modifier = Modifier
                .size(50.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(DietAccent.copy(alpha = 0.1f)),
            contentAlignment = Alignment.Center
        ) {
            Text(food.categoryEnum.icon, fontSize = 28.sp)
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Text(
                text = food.name,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (food.brand != null) {
                Text(
                    text = food.brand,
                    fontSize = 13.sp,
                    color = AppColors.onSurface.copy(alpha = 0.5f)
                )
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = food.displayServingSize,
                    fontSize = 13.sp,
                    color = AppColors.onSurface.copy(alpha = 0.5f)
                )
                Text("·", fontSize = 13.sp, color = AppColors.onSurface.copy(alpha = 0.5f))
                Text(
                    text = food.caloriesPerServing,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = DietAccent
                )
            }
            Text(
                text = food.macroSummary,
                fontSize = 12.sp,
                color = AppColors.onSurface.copy(alpha = 0.4f)
            )
        }

        if (onToggleFavorite != null) {
            IconButton(onClick = onToggleFavorite, modifier = Modifier.size(36.dp)) {
                Icon(
                    imageVector = if (isFavorite) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                    contentDescription = if (isFavorite) "Unfavorite" else "Favorite",
                    tint = if (isFavorite) Color(0xFFFF2D55) else AppColors.onSurface.copy(alpha = 0.4f),
                    modifier = Modifier.size(20.dp)
                )
            }
        }

        Icon(
            Icons.Default.AddCircle,
            contentDescription = "Add",
            tint = DietAccent,
            modifier = Modifier.size(26.dp)
        )
    }
}
