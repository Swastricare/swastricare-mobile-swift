package com.swasthicare.mobile.ui.screens.onboarding

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swasthicare.mobile.data.model.Gender
import com.swasthicare.mobile.data.model.HealthProfile
import com.swasthicare.mobile.data.repository.ProfileRepository
import com.swasthicare.mobile.ui.theme.PrimaryColor
import kotlinx.coroutines.launch

@Composable
fun HealthProfileScreen(
    userId: String,
    profileRepository: ProfileRepository,
    onCompleted: () -> Unit
) {
    var fullName by remember { mutableStateOf("") }
    var dateOfBirth by remember { mutableStateOf("") }
    var gender by remember { mutableStateOf(Gender.Male) }
    var heightCm by remember { mutableStateOf("") }
    var weightKg by remember { mutableStateOf("") }
    var bloodType by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    val bloodTypes = listOf("A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-")
    val genders = Gender.entries

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Spacer(Modifier.height(48.dp))
        Text("Your Health Profile", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text(
            "We use this to personalize your health insights.",
            fontSize = 14.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            modifier = Modifier.padding(top = 8.dp, bottom = 32.dp)
        )

        OutlinedTextField(
            value = fullName,
            onValueChange = { fullName = it },
            label = { Text("Full Name") },
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
        )

        OutlinedTextField(
            value = dateOfBirth,
            onValueChange = { dateOfBirth = it },
            label = { Text("Date of Birth (YYYY-MM-DD)") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
        )

        // Gender selector
        Text("Gender", fontSize = 14.sp, fontWeight = FontWeight.Medium, modifier = Modifier.padding(bottom = 8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(bottom = 16.dp)) {
            genders.forEach { g ->
                FilterChip(
                    selected = gender == g,
                    onClick = { gender = g },
                    label = { Text(g.displayName) }
                )
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            OutlinedTextField(
                value = heightCm,
                onValueChange = { heightCm = it },
                label = { Text("Height (cm)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.weight(1f)
            )
            OutlinedTextField(
                value = weightKg,
                onValueChange = { weightKg = it },
                label = { Text("Weight (kg)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(Modifier.height(16.dp))

        // Blood type selector
        Text("Blood Type", fontSize = 14.sp, fontWeight = FontWeight.Medium, modifier = Modifier.padding(bottom = 8.dp))
        // Use two rows for 8 blood types
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(bottom = 8.dp)) {
            bloodTypes.take(4).forEach { bt ->
                FilterChip(
                    selected = bloodType == bt,
                    onClick = { bloodType = bt },
                    label = { Text(bt) }
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(bottom = 32.dp)) {
            bloodTypes.drop(4).forEach { bt ->
                FilterChip(
                    selected = bloodType == bt,
                    onClick = { bloodType = bt },
                    label = { Text(bt) }
                )
            }
        }

        errorMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(bottom = 8.dp))
        }

        Button(
            onClick = {
                val h = heightCm.toDoubleOrNull()
                val w = weightKg.toDoubleOrNull()
                if (fullName.isBlank() || dateOfBirth.length != 10 || h == null || w == null) {
                    errorMessage = "Please fill in all required fields."
                    return@Button
                }
                isLoading = true
                scope.launch {
                    val profile = HealthProfile(
                        userId = userId,
                        fullName = fullName.trim(),
                        gender = gender,
                        dateOfBirth = dateOfBirth,
                        heightCm = h,
                        weightKg = w,
                        bloodType = bloodType.ifEmpty { null }
                    )
                    val result = profileRepository.createHealthProfile(profile)
                    result.onSuccess {
                        onCompleted()
                    }.onFailure { e ->
                        errorMessage = "Failed to save profile: ${e.message}"
                        isLoading = false
                    }
                }
            },
            enabled = !isLoading,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = PrimaryColor)
        ) {
            if (isLoading) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = MaterialTheme.colorScheme.onPrimary)
            } else {
                Text("Save & Continue", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            }
        }

        Spacer(Modifier.height(32.dp))
    }
}
