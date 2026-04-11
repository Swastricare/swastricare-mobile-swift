package com.swastricare.health.ui.screens.menstrualcycle

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.domain.model.menstrualcycle.FlowLevel
import com.swastricare.health.domain.model.menstrualcycle.Mood
import com.swastricare.health.domain.model.menstrualcycle.Symptom
import com.swastricare.health.ui.screens.home.glass
import androidx.compose.foundation.isSystemInDarkTheme
import com.swastricare.health.ui.theme.AppColors
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

// ─────────────────────────────────────
// MARK: - Data
// ─────────────────────────────────────

private data class LogData(
    val startDate: LocalDate = LocalDate.now(),
    val flowLevel: FlowLevel = FlowLevel.MEDIUM,
    val symptoms: Set<Symptom> = emptySet(),
    val mood: Mood? = null,
    val painLevel: Int = 0,
    val notes: String = ""
)

private val stepTitles = listOf(
    "When did it start?",
    "How heavy is the flow?",
    "Any symptoms?",
    "How's your mood?",
    "Pain level?",
    "Anything else?"
)

// ─────────────────────────────────────
// MARK: - Screen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun LogPeriodScreen(
    viewModel: MenstrualCycleViewModel,
    onNavigateBack: () -> Unit
) {
    var step by remember { mutableIntStateOf(0) }
    var data by remember { mutableStateOf(LogData()) }
    val totalSteps = 6

    val screenBg = if (isSystemInDarkTheme()) Color(0xFF1A0A0F) else Color(0xFFFFF5F8)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(screenBg)
            .statusBarsPadding()
            .navigationBarsPadding()
    ) {
        // ── Top bar ──
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = {
                if (step > 0) step-- else onNavigateBack()
            }) {
                Icon(
                    if (step > 0) Icons.Default.ArrowBack else Icons.Default.Close,
                    contentDescription = if (step > 0) "Back" else "Close",
                    tint = AppColors.onSurface
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = stepTitles[step],
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.onSurface
                )
                Text(
                    text = "Step ${step + 1} of $totalSteps",
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.onSurfaceVariant
                )
            }
        }

        // ── Progress bar ──
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(CyclePink.copy(alpha = 0.15f))
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth((step + 1).toFloat() / totalSteps)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(
                        Brush.horizontalGradient(listOf(CyclePink, CyclePurple))
                    )
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // ── Step content ──
        AnimatedContent(
            targetState = step,
            transitionSpec = {
                if (targetState > initialState)
                    slideInHorizontally { it } togetherWith slideOutHorizontally { -it }
                else
                    slideInHorizontally { -it } togetherWith slideOutHorizontally { it }
            },
            label = "LogStep",
            modifier = Modifier.weight(1f)
        ) { currentStep ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                when (currentStep) {
                    0 -> LogStepDate(data.startDate) { data = data.copy(startDate = it) }
                    1 -> LogStepFlow(data.flowLevel) { data = data.copy(flowLevel = it) }
                    2 -> LogStepSymptoms(data.symptoms) { data = data.copy(symptoms = it) }
                    3 -> LogStepMood(data.mood) { data = data.copy(mood = it) }
                    4 -> LogStepPain(data.painLevel) { data = data.copy(painLevel = it) }
                    5 -> LogStepNotes(data.notes, data) { data = data.copy(notes = it) }
                }
                Spacer(Modifier.height(8.dp))
            }
        }

        // ── Bottom nav button ──
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 16.dp)
        ) {
            if (step < totalSteps - 1) {
                Button(
                    onClick = { step++ },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = CyclePink),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Text("Continue", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.width(6.dp))
                    Icon(Icons.Default.ArrowForward, null, modifier = Modifier.size(18.dp))
                }
            } else {
                Button(
                    onClick = {
                        viewModel.logPeriodWithDetails(
                            data.startDate,
                            data.flowLevel,
                            data.symptoms.toList(),
                            data.mood,
                            data.painLevel,
                            data.notes.ifBlank { null }
                        )
                        onNavigateBack()
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = CyclePink
                    ),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Text(
                        "Log Period",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Step 1: Date
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LogStepDate(selected: LocalDate, onChange: (LocalDate) -> Unit) {
    val datePickerState = rememberDatePickerState(
        initialSelectedDateMillis = selected.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
    )
    LaunchedEffect(datePickerState.selectedDateMillis) {
        datePickerState.selectedDateMillis?.let { millis ->
            val date = Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDate()
            if (date != selected) onChange(date)
        }
    }
    DatePicker(
        state = datePickerState,
        colors = DatePickerDefaults.colors(
            selectedDayContainerColor = CyclePink,
            todayDateBorderColor = CyclePink
        )
    )
}

// ─────────────────────────────────────
// MARK: - Step 2: Flow Level
// ─────────────────────────────────────

@Composable
private fun LogStepFlow(
    selected: FlowLevel,
    onChange: (FlowLevel) -> Unit
) {
    data class FlowEntry(val level: FlowLevel, val emoji: String, val label: String)
    val levels = listOf(
        FlowEntry(FlowLevel.NONE, "\uD83D\uDCA7", "None"),
        FlowEntry(FlowLevel.LIGHT, "\uD83E\uDE78", "Light"),
        FlowEntry(FlowLevel.MEDIUM, "\uD83E\uDE78\uD83E\uDE78", "Medium"),
        FlowEntry(FlowLevel.HEAVY, "\uD83E\uDE78\uD83E\uDE78\uD83E\uDE78", "Heavy"),
        FlowEntry(FlowLevel.VERY_HEAVY, "\uD83E\uDE78\uD83E\uDE78\uD83E\uDE78\uD83E\uDE78", "Very Heavy")
    )
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        levels.forEach { entry ->
            val level = entry.level
            val emoji = entry.emoji
            val label = entry.label
            val isSelected = selected == level
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(if (isSelected) CyclePink.copy(alpha = 0.12f) else CycleTheme.cardBg)
                    .border(
                        width = if (isSelected) 1.5.dp else 0.dp,
                        color = if (isSelected) CyclePink else Color.Transparent,
                        shape = RoundedCornerShape(16.dp)
                    )
                    .clickable { onChange(level) }
                    .padding(horizontal = 20.dp, vertical = 18.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Text(emoji, fontSize = 24.sp)
                Text(
                    label,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                    color = if (isSelected) CyclePink else AppColors.onSurface,
                    modifier = Modifier.weight(1f)
                )
                if (isSelected) {
                    Box(
                        modifier = Modifier
                            .size(22.dp)
                            .background(CyclePink, CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("\u2713", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Step 3: Symptoms
// ─────────────────────────────────────

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun LogStepSymptoms(
    selected: Set<Symptom>,
    onChange: (Set<Symptom>) -> Unit
) {
    data class SymptomEntry(val symptom: Symptom, val label: String)
    val allSymptoms = listOf(
        SymptomEntry(Symptom.CRAMPS, "\uD83E\uDD15 Cramps"),
        SymptomEntry(Symptom.BLOATING, "\uD83E\uDEB7 Bloating"),
        SymptomEntry(Symptom.FATIGUE, "\uD83D\uDE34 Fatigue"),
        SymptomEntry(Symptom.MOOD_SWINGS, "\uD83C\uDF0A Mood Swings"),
        SymptomEntry(Symptom.HEADACHE, "\uD83E\uDD2F Headache"),
        SymptomEntry(Symptom.BACKACHE, "\uD83D\uDD19 Backache"),
        SymptomEntry(Symptom.NAUSEA, "\uD83E\uDD22 Nausea"),
        SymptomEntry(Symptom.ACNE, "\uD83D\uDE24 Acne"),
        SymptomEntry(Symptom.INSOMNIA, "\uD83C\uDF19 Insomnia"),
        SymptomEntry(Symptom.CRAVINGS, "\uD83C\uDF6B Cravings"),
        SymptomEntry(Symptom.BREAST_TENDERNESS, "\uD83D\uDC97 Tenderness"),
        SymptomEntry(Symptom.SPOTTING, "\uD83E\uDE79 Spotting"),
        SymptomEntry(Symptom.ANXIETY, "\uD83D\uDE30 Anxiety"),
        SymptomEntry(Symptom.IRRITABILITY, "\uD83D\uDE20 Irritability")
    )
    Text(
        "Select all that apply",
        style = MaterialTheme.typography.bodySmall,
        color = AppColors.onSurfaceVariant
    )
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        allSymptoms.forEach { entry ->
            val symptom = entry.symptom
            val label = entry.label
            val isSelected = symptom in selected
            FilterChip(
                selected = isSelected,
                onClick = { onChange(if (isSelected) selected - symptom else selected + symptom) },
                label = { Text(label, style = MaterialTheme.typography.bodySmall) },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = CyclePink.copy(alpha = 0.15f),
                    selectedLabelColor = CyclePink
                ),
                border = FilterChipDefaults.filterChipBorder(
                    enabled = true,
                    selected = isSelected,
                    selectedBorderColor = CyclePink,
                    selectedBorderWidth = 1.5.dp
                )
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Step 4: Mood
// ─────────────────────────────────────

internal data class LogMoodEntry(val mood: Mood, val emoji: String, val label: String)

@Composable
private fun LogStepMood(
    selected: Mood?,
    onChange: (Mood?) -> Unit
) {
    val moods = listOf(
        LogMoodEntry(Mood.HAPPY, "\uD83D\uDE0A", "Happy"),
        LogMoodEntry(Mood.CALM, "\uD83D\uDE0C", "Calm"),
        LogMoodEntry(Mood.ENERGETIC, "\u26A1", "Energetic"),
        LogMoodEntry(Mood.ANXIOUS, "\uD83D\uDE30", "Anxious"),
        LogMoodEntry(Mood.SAD, "\uD83D\uDE22", "Sad"),
        LogMoodEntry(Mood.IRRITABLE, "\uD83D\uDE24", "Irritable"),
        LogMoodEntry(Mood.TIRED, "\uD83D\uDE34", "Tired"),
        LogMoodEntry(Mood.NEUTRAL, "\uD83D\uDE10", "Neutral")
    )
    moods.chunked(4).forEach { row ->
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            row.forEach { entry ->
                val isSelected = selected == entry.mood
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(16.dp))
                        .background(
                            if (isSelected) CyclePink.copy(alpha = 0.12f)
                            else CycleTheme.cardBg
                        )
                        .border(
                            width = if (isSelected) 1.5.dp else 0.dp,
                            color = if (isSelected) CyclePink else Color.Transparent,
                            shape = RoundedCornerShape(16.dp)
                        )
                        .clickable { onChange(if (isSelected) null else entry.mood) }
                        .padding(vertical = 14.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(entry.emoji, fontSize = 30.sp)
                    Text(
                        entry.label,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isSelected) CyclePink else AppColors.onSurfaceVariant,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
        Spacer(Modifier.height(10.dp))
    }
}

// ─────────────────────────────────────
// MARK: - Step 5: Pain Level
// ─────────────────────────────────────

@Composable
private fun LogStepPain(level: Int, onChange: (Int) -> Unit) {
    val emoji = when {
        level == 0 -> "\uD83D\uDE0A"
        level <= 2 -> "\uD83D\uDE42"
        level <= 4 -> "\uD83D\uDE10"
        level <= 6 -> "\uD83D\uDE1F"
        level <= 8 -> "\uD83D\uDE23"
        else -> "\uD83D\uDE2D"
    }
    val color = when {
        level <= 3 -> FollicularColor
        level <= 6 -> OvulationColor
        else -> CyclePink
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp)).background(CycleTheme.cardBg)
            .padding(32.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(emoji, fontSize = 72.sp)
            Text(
                "$level / 10",
                style = MaterialTheme.typography.displaySmall,
                fontWeight = FontWeight.Bold,
                color = color
            )
            Text(
                when {
                    level == 0 -> "No pain"
                    level <= 2 -> "Mild"
                    level <= 4 -> "Moderate"
                    level <= 6 -> "Uncomfortable"
                    level <= 8 -> "Severe"
                    else -> "Unbearable"
                },
                style = MaterialTheme.typography.bodyLarge,
                color = AppColors.onSurfaceVariant
            )
        }
    }
    Spacer(Modifier.height(24.dp))
    Slider(
        value = level.toFloat(),
        onValueChange = { onChange(it.toInt()) },
        valueRange = 0f..10f,
        steps = 9,
        colors = SliderDefaults.colors(
            thumbColor = color,
            activeTrackColor = color,
            inactiveTrackColor = color.copy(alpha = 0.2f)
        )
    )
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text("0 — None", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
        Text("10 — Severe", style = MaterialTheme.typography.labelSmall, color = AppColors.onSurfaceVariant)
    }
}

// ─────────────────────────────────────
// MARK: - Step 6: Notes + Summary
// ─────────────────────────────────────

@Composable
private fun LogStepNotes(notes: String, data: LogData, onChange: (String) -> Unit) {
    val fmt = DateTimeFormatter.ofPattern("MMM dd, yyyy")
    OutlinedTextField(
        value = notes,
        onValueChange = onChange,
        modifier = Modifier.fillMaxWidth(),
        placeholder = { Text("Optional notes about this cycle...", color = AppColors.onSurfaceVariant) },
        minLines = 3,
        maxLines = 6,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = CyclePink,
            cursorColor = CyclePink
        ),
        shape = RoundedCornerShape(14.dp),
        label = { Text("Notes", color = AppColors.onSurfaceVariant) }
    )
    Spacer(Modifier.height(8.dp))
    // Summary card
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp)).background(CycleTheme.cardBg)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            "Summary",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            color = CyclePink
        )
        LogSummaryRow("\uD83D\uDCC5 Start date", data.startDate.format(fmt))
        LogSummaryRow(
            "\uD83E\uDE78 Flow",
            data.flowLevel.name.lowercase().replaceFirstChar { it.uppercase() }
        )
        if (data.symptoms.isNotEmpty()) {
            LogSummaryRow("\uD83E\uDD15 Symptoms", "${data.symptoms.size} selected")
        }
        data.mood?.let {
            LogSummaryRow(
                "\uD83D\uDE0A Mood",
                it.name.lowercase().replaceFirstChar { c -> c.uppercase() }
            )
        }
        LogSummaryRow("\uD83D\uDC8A Pain level", "${data.painLevel} / 10")
    }
}

@Composable
private fun LogSummaryRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = AppColors.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold, color = AppColors.onSurface)
    }
}
