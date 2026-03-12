package com.swastricare.health.ui.screens.diet

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.models.DietGoals
import com.swastricare.health.ui.theme.AppColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DietSettingsSheet(
    currentGoals: DietGoals,
    onSave: (DietGoals) -> Unit,
    onDismiss: () -> Unit
) {
    var calories by remember { mutableStateOf(currentGoals.dailyCalories.toString()) }
    var proteinPct by remember { mutableStateOf(currentGoals.proteinPercent.toString()) }
    var carbsPct by remember { mutableStateOf(currentGoals.carbsPercent.toString()) }
    var fatPct by remember { mutableStateOf(currentGoals.fatPercent.toString()) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(modifier = Modifier.padding(24.dp)) {
            Text("Daily Nutrition Goals", fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(20.dp))

            OutlinedTextField(
                value = calories,
                onValueChange = { calories = it },
                label = { Text("Calories (kcal)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
            )
            OutlinedTextField(
                value = proteinPct,
                onValueChange = { proteinPct = it },
                label = { Text("Protein (%)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
            )
            OutlinedTextField(
                value = carbsPct,
                onValueChange = { carbsPct = it },
                label = { Text("Carbohydrates (%)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
            )
            OutlinedTextField(
                value = fatPct,
                onValueChange = { fatPct = it },
                label = { Text("Fat (%)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
            )

            // Show computed grams preview
            val cal = calories.toIntOrNull() ?: 2000
            val pPct = proteinPct.toIntOrNull() ?: 25
            val cPct = carbsPct.toIntOrNull() ?: 50
            val fPct = fatPct.toIntOrNull() ?: 25
            Text(
                "≈ ${cal * pPct / 400}g protein · ${cal * cPct / 400}g carbs · ${cal * fPct / 900}g fat",
                fontSize = 12.sp,
                color = AppColors.onSurface.copy(alpha = 0.5f),
                modifier = Modifier.padding(bottom = 24.dp)
            )

            Button(
                onClick = {
                    onSave(
                        currentGoals.copy(
                            dailyCalories = calories.toIntOrNull() ?: 2000,
                            proteinPercent = proteinPct.toIntOrNull() ?: 25,
                            carbsPercent = carbsPct.toIntOrNull() ?: 50,
                            fatPercent = fatPct.toIntOrNull() ?: 25
                        )
                    )
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth().height(56.dp),
                colors = ButtonDefaults.buttonColors(containerColor = DietGreen)
            ) {
                Text("Save Goals", fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}
