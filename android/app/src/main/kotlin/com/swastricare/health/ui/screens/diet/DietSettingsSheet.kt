package com.swastricare.health.ui.screens.diet

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.DietGoals
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.NutritionCarbs
import com.swastricare.health.ui.theme.NutritionFat
import com.swastricare.health.ui.theme.NutritionProtein

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DietSettingsSheet(
    currentGoals: DietGoals,
    onSave: (DietGoals) -> Unit,
    onDismiss: () -> Unit
) {
    var calories by remember { mutableStateOf(currentGoals.dailyCalories) }
    var proteinPct by remember { mutableStateOf(currentGoals.proteinPercent) }
    var carbsPct by remember { mutableStateOf(currentGoals.carbsPercent) }
    var fatPct by remember { mutableStateOf(currentGoals.fatPercent) }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val totalPct = proteinPct + carbsPct + fatPct
    val isValid = totalPct == 100 && calories in 800..6000

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = Color.White,
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(top = 8.dp)
                    .size(width = 40.dp, height = 4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(AppColors.onSurface.copy(alpha = 0.18f))
            )
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 24.dp)
        ) {
            // ── Header ──
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        "Nutrition Goals",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.onSurface
                    )
                    Text(
                        "Set your daily calorie and macro targets",
                        fontSize = 12.sp,
                        color = AppColors.onSurface.copy(alpha = 0.55f)
                    )
                }
                IconButton(onClick = onDismiss) {
                    Icon(
                        Icons.Default.Close,
                        contentDescription = "Close",
                        tint = AppColors.onSurface.copy(alpha = 0.6f)
                    )
                }
            }

            // ── Calorie stepper card ──
            CalorieStepperCard(
                calories = calories,
                onChange = { calories = it.coerceIn(800, 6000) }
            )

            Spacer(Modifier.height(20.dp))

            // ── Macro distribution ──
            Row(
                modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "Macro Distribution",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.onSurface
                )
                Text(
                    "$totalPct%",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (totalPct == 100) DietAccent else Color(0xFFFF9500)
                )
            }

            MacroSliderRow(
                label = "Protein",
                pct = proteinPct,
                grams = (calories * proteinPct / 400).coerceAtLeast(0),
                color = NutritionProtein,
                onChange = { proteinPct = it }
            )
            Spacer(Modifier.height(12.dp))
            MacroSliderRow(
                label = "Carbs",
                pct = carbsPct,
                grams = (calories * carbsPct / 400).coerceAtLeast(0),
                color = NutritionCarbs,
                onChange = { carbsPct = it }
            )
            Spacer(Modifier.height(12.dp))
            MacroSliderRow(
                label = "Fat",
                pct = fatPct,
                grams = (calories * fatPct / 900).coerceAtLeast(0),
                color = NutritionFat,
                onChange = { fatPct = it }
            )

            if (totalPct != 100) {
                Spacer(Modifier.height(12.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color(0xFFFFF3E0))
                        .padding(horizontal = 12.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        Icons.Default.WarningAmber,
                        contentDescription = null,
                        tint = Color(0xFFFF9500),
                        modifier = Modifier.size(18.dp)
                    )
                    Text(
                        "Macros must add up to 100% (currently $totalPct%)",
                        fontSize = 12.sp,
                        color = Color(0xFF8A4F00)
                    )
                }
            }

            Spacer(Modifier.height(20.dp))

            // ── Quick presets ──
            Text(
                "Presets",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.onSurface,
                modifier = Modifier.padding(bottom = 8.dp)
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                PresetChip("Balanced", "30/40/30") {
                    proteinPct = 30; carbsPct = 40; fatPct = 30
                }
                PresetChip("High Protein", "40/30/30") {
                    proteinPct = 40; carbsPct = 30; fatPct = 30
                }
                PresetChip("Low Carb", "30/20/50") {
                    proteinPct = 30; carbsPct = 20; fatPct = 50
                }
            }

            Spacer(Modifier.height(28.dp))

            // ── Save button ──
            Button(
                onClick = {
                    onSave(
                        currentGoals.copy(
                            dailyCalories = calories,
                            proteinPercent = proteinPct,
                            carbsPercent = carbsPct,
                            fatPercent = fatPct
                        )
                    )
                    onDismiss()
                },
                enabled = isValid,
                modifier = Modifier.fillMaxWidth().height(54.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = DietAccent,
                    disabledContainerColor = DietAccent.copy(alpha = 0.4f)
                )
            ) {
                Text(
                    "Save Goals",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 15.sp,
                    color = Color.White
                )
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

// ─────────────────────────────────────
// MARK: - Calorie stepper
// ─────────────────────────────────────

@Composable
private fun CalorieStepperCard(
    calories: Int,
    onChange: (Int) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .dietCardShadow(radius = 16.dp, elevation = 4.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .padding(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            "Daily Calories",
            fontSize = 13.sp,
            color = AppColors.onSurface.copy(alpha = 0.55f),
            fontWeight = FontWeight.Medium
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            StepperButton(
                icon = Icons.Default.Remove,
                onClick = { onChange(calories - 50) }
            )
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "$calories",
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )
                Text(
                    "kcal / day",
                    fontSize = 11.sp,
                    color = AppColors.onSurface.copy(alpha = 0.45f)
                )
            }
            StepperButton(
                icon = Icons.Default.Add,
                onClick = { onChange(calories + 50) }
            )
        }
    }
}

@Composable
private fun StepperButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(DietAccent.copy(alpha = 0.12f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = DietAccent,
            modifier = Modifier.size(20.dp)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Macro slider row
// ─────────────────────────────────────

@Composable
private fun MacroSliderRow(
    label: String,
    pct: Int,
    grams: Int,
    color: Color,
    onChange: (Int) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(color)
                )
                Text(
                    label,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.onSurface
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    "${grams}g",
                    fontSize = 12.sp,
                    color = AppColors.onSurface.copy(alpha = 0.5f)
                )
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(color.copy(alpha = 0.12f))
                        .padding(horizontal = 10.dp, vertical = 4.dp)
                ) {
                    Text(
                        "$pct%",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = color
                    )
                }
            }
        }
        Slider(
            value = pct.toFloat(),
            onValueChange = { onChange(it.toInt()) },
            valueRange = 5f..70f,
            colors = SliderDefaults.colors(
                thumbColor = color,
                activeTrackColor = color,
                inactiveTrackColor = color.copy(alpha = 0.18f)
            )
        )
    }
}

// ─────────────────────────────────────
// MARK: - Preset chip
// ─────────────────────────────────────

@Composable
private fun PresetChip(
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(DietAccent.copy(alpha = 0.08f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClick() }
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Text(
            title,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = DietAccent
        )
        Text(
            subtitle,
            fontSize = 10.sp,
            color = DietAccent.copy(alpha = 0.7f)
        )
    }
}
