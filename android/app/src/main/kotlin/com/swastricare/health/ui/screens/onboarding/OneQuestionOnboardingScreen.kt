package com.swastricare.health.ui.screens.onboarding

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.swastricare.health.domain.model.profile.Gender
import com.swastricare.health.ui.theme.AITeal
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PoppinsFontFamily
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

// ─────────────────────────────────────
// MARK: - Host Screen
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OneQuestionOnboardingScreen(
    onFinished: () -> Unit
) {
    val vm: OneQuestionOnboardingViewModel = hiltViewModel()
    val state by vm.state.collectAsState()

    // Orb colors — match iOS: aiTeal.opacity(0.03) and Color(hex:"1BFFFF").opacity(0.02)
    val orb1Color = AITeal.copy(alpha = 0.03f)
    val orb2Color = Color(0xFF1BFFFF).copy(alpha = 0.02f)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
    ) {
        // ── Decorative ambient orbs (top area) ───────────────────
        // Orb 1: center-top, 280dp, aiTeal alpha 0.03 — radial gradient blob
        Box(
            modifier = Modifier
                .size(280.dp)
                .align(Alignment.TopCenter)
                .drawBehind { drawOrbGradient(orb1Color) }
        )
        // Orb 2: top-start, 250dp, cyan 1BFFFF alpha 0.02
        Box(
            modifier = Modifier
                .size(250.dp)
                .align(Alignment.TopStart)
                .drawBehind { drawOrbGradient(orb2Color) }
        )

        // ── Main content ─────────────────────────────────────────
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            if (state.submitState == SubmitState.SUBMITTING ||
                state.submitState == SubmitState.SUCCESS ||
                state.submitState == SubmitState.ERROR
            ) {
                OnboardingSetupLoadingScreen(
                    state = state.submitState,
                    errorMessage = state.errorMessage,
                    onRetry = vm::retry,
                    onComplete = onFinished
                )
            } else {
                // ── Top bar ──────────────────────────────────────
                OnboardingTopBar(
                    step = state.step,
                    totalSteps = vm.totalSteps,
                    onBack = { if (state.step > 0) vm.back() }
                )

                // ── Animated body ────────────────────────────────
                AnimatedContent(
                    targetState = state.step,
                    modifier = Modifier.weight(1f),
                    transitionSpec = {
                        if (targetState > initialState) {
                            slideInHorizontally { it / 4 } + fadeIn() togetherWith
                                slideOutHorizontally { -it / 4 } + fadeOut()
                        } else {
                            slideInHorizontally { -it / 4 } + fadeIn() togetherWith
                                slideOutHorizontally { it / 4 } + fadeOut()
                        }
                    },
                    label = "stepTransition"
                ) { step ->
                    // Each step renders inside a Column that fills available space.
                    // Step composables are ColumnScope extensions so Modifier.weight() works.
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 32.dp)
                    ) {
                        when (step) {
                            0 -> NameStep(form = state.form, onChange = vm::update)
                            1 -> GenderStep(form = state.form, onChange = vm::update)
                            2 -> DobStep(form = state.form, onChange = vm::update)
                            3 -> HeightStep(form = state.form, onChange = vm::update)
                            4 -> WeightStep(form = state.form, onChange = vm::update)
                            5 -> GoalStep(form = state.form, onChange = vm::update)
                            6 -> ActivityStep(form = state.form, onChange = vm::update)
                            7 -> WaterStep(form = state.form, onChange = vm::update)
                        }
                    }
                }

                // ── CTA button — AITeal solid, AITeal-tinted glow shadow ──
                val isEnabled = vm.isStepValid()
                val isLastStep = state.step == vm.totalSteps - 1

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 32.dp)
                        .navigationBarsPadding()
                        .padding(bottom = 16.dp)
                ) {
                    val buttonModifier = if (isEnabled) {
                        Modifier
                            .fillMaxWidth()
                            .height(56.dp)
                            .drawBehind { drawCtaShadow(AITeal.copy(alpha = 0.30f)) }
                    } else {
                        Modifier
                            .fillMaxWidth()
                            .height(56.dp)
                    }

                    Button(
                        onClick = vm::next,
                        enabled = isEnabled,
                        modifier = buttonModifier,
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = AITeal,
                            contentColor = Color.White,
                            disabledContainerColor = AppColors.onSurface.copy(alpha = 0.3f),
                            disabledContentColor = Color.White
                        )
                    ) {
                        Text(
                            text = if (isLastStep) "Complete" else "Continue",
                            fontFamily = PoppinsFontFamily,
                            fontSize = 17.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - Draw helpers (orbs + CTA glow)
// ─────────────────────────────────────

/** Radial gradient blob — simulates iOS's blurred Circle fill */
private fun DrawScope.drawOrbGradient(centerColor: Color) {
    val radius = size.minDimension
    drawCircle(
        brush = Brush.radialGradient(
            colors = listOf(centerColor, Color.Transparent),
            center = Offset(size.width / 2f, size.height / 2f),
            radius = radius
        )
    )
}

/** Subtle AITeal glow shadow under the CTA button */
private fun DrawScope.drawCtaShadow(glowColor: Color) {
    val blurRadius = 24.dp.toPx()
    drawRoundRect(
        brush = Brush.verticalGradient(
            colors = listOf(Color.Transparent, glowColor),
            startY = size.height * 0.5f,
            endY = size.height + blurRadius
        ),
        cornerRadius = CornerRadius(16.dp.toPx())
    )
}

// ─────────────────────────────────────
// MARK: - Top Bar (capsule progress pills)
// ─────────────────────────────────────

@Composable
private fun OnboardingTopBar(
    step: Int,
    totalSteps: Int,
    onBack: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Step 0: no back button — show transparent 44dp spacer to keep pills centered
        if (step == 0) {
            Spacer(Modifier.size(44.dp))
        } else {
            Surface(
                shape = CircleShape,
                color = AppColors.onSurface.copy(alpha = 0.05f),
                modifier = Modifier.size(44.dp)
            ) {
                IconButton(
                    onClick = onBack,
                    modifier = Modifier.size(44.dp)
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = AppColors.onSurface,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }

        // Centered capsule progress pills
        Row(
            modifier = Modifier.weight(1f),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            repeat(totalSteps) { index ->
                val isFilled = index <= step
                val pillWidth by animateDpAsState(
                    targetValue = if (index == step) 24.dp else 6.dp,
                    animationSpec = spring(),
                    label = "pillWidth_$index"
                )
                val pillColor by animateColorAsState(
                    targetValue = if (isFilled) AITeal else AppColors.onSurface.copy(alpha = 0.10f),
                    label = "pillColor_$index"
                )
                Box(
                    modifier = Modifier
                        .height(6.dp)
                        .width(pillWidth)
                        .clip(RoundedCornerShape(3.dp))
                        .background(pillColor)
                )
                if (index < totalSteps - 1) {
                    Spacer(Modifier.width(6.dp))
                }
            }
        }

        // Mirror spacer to balance layout (keeps pills center-aligned)
        Spacer(Modifier.size(44.dp))
    }
}

// ─────────────────────────────────────
// MARK: - Step Header helper
// ─────────────────────────────────────

@Composable
private fun StepHeader(title: String, subtitle: String) {
    Spacer(Modifier.height(60.dp))
    Text(
        text = title,
        fontFamily = PoppinsFontFamily,
        fontSize = 28.sp,
        fontWeight = FontWeight.SemiBold,
        color = AppColors.onSurface,
        lineHeight = 36.sp
    )
    Spacer(Modifier.height(8.dp))
    Text(
        text = subtitle,
        fontFamily = PoppinsFontFamily,
        fontSize = 16.sp,
        fontWeight = FontWeight.Normal,
        color = AppColors.onSurface.copy(alpha = 0.6f),
        lineHeight = 22.sp
    )
}

// ─────────────────────────────────────
// MARK: - Step 0: Name
// — ColumnScope receiver: Spacer(weight(1f)) pushes field to top
// ─────────────────────────────────────

@Composable
private fun ColumnScope.NameStep(
    form: OnboardingFormState,
    onChange: (OnboardingFormState.() -> OnboardingFormState) -> Unit
) {
    val focusRequester = remember { FocusRequester() }
    val hasFocus = remember { mutableStateOf(false) }

    StepHeader(
        title = "What's your name?",
        subtitle = "This is how we'll address you"
    )

    Spacer(Modifier.height(20.dp))

    // Underline color: AITeal when focused or has value; subtle when empty + unfocused
    val lineColor = if (hasFocus.value || form.fullName.isNotEmpty()) AITeal
    else AppColors.onSurface.copy(alpha = 0.1f)

    BasicTextField(
        value = form.fullName,
        onValueChange = { new -> onChange { copy(fullName = new) } },
        singleLine = true,
        textStyle = TextStyle(
            fontFamily = PoppinsFontFamily,
            fontSize = 28.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.onSurface
        ),
        cursorBrush = SolidColor(AITeal),
        keyboardOptions = KeyboardOptions(
            capitalization = KeyboardCapitalization.Words,
            imeAction = ImeAction.Done
        ),
        modifier = Modifier
            .fillMaxWidth()
            .focusRequester(focusRequester)
            .onFocusChanged { hasFocus.value = it.isFocused },
        decorationBox = { innerTextField ->
            Column {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp)
                ) {
                    if (form.fullName.isEmpty()) {
                        Text(
                            text = "Your full name",
                            fontFamily = PoppinsFontFamily,
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Medium,
                            color = AppColors.onSurface.copy(alpha = 0.4f)
                        )
                    }
                    innerTextField()
                }
                HorizontalDivider(thickness = 2.dp, color = lineColor)
            }
        }
    )

    Spacer(Modifier.weight(1f))

    LaunchedEffect(Unit) { focusRequester.requestFocus() }
}

// ─────────────────────────────────────
// MARK: - Step 1: Gender
// ─────────────────────────────────────

@Composable
private fun ColumnScope.GenderStep(
    form: OnboardingFormState,
    onChange: (OnboardingFormState.() -> OnboardingFormState) -> Unit
) {
    val options = listOf(Gender.MALE, Gender.FEMALE, Gender.OTHER, Gender.PREFER_NOT_TO_SAY)

    StepHeader(
        title = "Which gender do you identify with?",
        subtitle = "Select your gender identity"
    )

    Spacer(Modifier.height(20.dp))

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        options.forEach { gender ->
            PillCard(
                label = gender.displayName,
                selected = form.gender == gender,
                onClick = { onChange { copy(gender = gender) } }
            )
        }
    }

    Spacer(Modifier.weight(1f))
}

// ─────────────────────────────────────
// MARK: - Step 2: Date of Birth
// ─────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ColumnScope.DobStep(
    form: OnboardingFormState,
    onChange: (OnboardingFormState.() -> OnboardingFormState) -> Unit
) {
    StepHeader(
        title = "What's your date of birth?",
        subtitle = "This helps us provide age-appropriate insights"
    )

    Spacer(Modifier.height(12.dp))

    val defaultDate = LocalDate.now().minusYears(30)
    val initialMillis = (form.dateOfBirth ?: defaultDate)
        .atStartOfDay(ZoneId.systemDefault())
        .toInstant()
        .toEpochMilli()

    val datePickerState = rememberDatePickerState(
        initialSelectedDateMillis = initialMillis
    )

    LaunchedEffect(datePickerState.selectedDateMillis) {
        datePickerState.selectedDateMillis?.let { millis ->
            val picked = Instant.ofEpochMilli(millis)
                .atZone(ZoneId.systemDefault())
                .toLocalDate()
            if (picked != form.dateOfBirth) {
                onChange { copy(dateOfBirth = picked) }
            }
        }
    }

    // Scroll wrapper — the Material3 DatePicker is taller than the available
    // body height on small screens and would otherwise clip behind the CTA.
    Column(
        modifier = Modifier
            .weight(1f)
            .verticalScroll(rememberScrollState())
    ) {
        DatePicker(
            state = datePickerState,
            modifier = Modifier.fillMaxWidth(),
            // Suppress the picker's built-in title/headline — they duplicate
            // and visually overlap with our StepHeader above.
            title = null,
            headline = null,
            showModeToggle = false,
            colors = DatePickerDefaults.colors(
                selectedDayContainerColor = AITeal,
                selectedDayContentColor = Color.White,
                todayDateBorderColor = AITeal,
                todayContentColor = AITeal,
                currentYearContentColor = AITeal,
                selectedYearContentColor = Color.White,
                selectedYearContainerColor = AITeal
            )
        )
    }
}

// ─────────────────────────────────────
// MARK: - Step 3: Height
// ─────────────────────────────────────

@Composable
private fun ColumnScope.HeightStep(
    form: OnboardingFormState,
    onChange: (OnboardingFormState.() -> OnboardingFormState) -> Unit
) {
    StepHeader(
        title = "How tall are you?",
        subtitle = "Select your height"
    )

    Spacer(Modifier.height(24.dp))

    // Unit toggle
    UnitToggle(
        options = listOf("cm", "ft/in"),
        selectedIndex = if (form.heightUnit == HeightUnit.CM) 0 else 1,
        onSelect = { idx ->
            onChange { copy(heightUnit = if (idx == 0) HeightUnit.CM else HeightUnit.FT_IN) }
        }
    )

    Spacer(Modifier.height(32.dp))

    if (form.heightUnit == HeightUnit.CM) {
        BigValueDisplay(number = "${form.heightCm}", unit = "cm")
        Spacer(Modifier.height(24.dp))
        Slider(
            value = form.heightCm.toFloat(),
            onValueChange = { onChange { copy(heightCm = it.toInt()) } },
            valueRange = 100f..250f,
            modifier = Modifier.fillMaxWidth(),
            colors = SliderDefaults.colors(
                thumbColor = AITeal,
                activeTrackColor = AITeal,
                inactiveTrackColor = AITeal.copy(alpha = 0.25f)
            )
        )
    } else {
        val totalInches = (form.heightCm / 2.54).toInt()
        FtInDisplay(feet = totalInches / 12, inches = totalInches % 12)
        Spacer(Modifier.height(24.dp))
        Slider(
            value = form.heightCm.toFloat(),
            onValueChange = { onChange { copy(heightCm = it.toInt()) } },
            valueRange = 100f..250f,
            modifier = Modifier.fillMaxWidth(),
            colors = SliderDefaults.colors(
                thumbColor = AITeal,
                activeTrackColor = AITeal,
                inactiveTrackColor = AITeal.copy(alpha = 0.25f)
            )
        )
    }

    Spacer(Modifier.weight(1f))
}

// ─────────────────────────────────────
// MARK: - Step 4: Weight
// ─────────────────────────────────────

@Composable
private fun ColumnScope.WeightStep(
    form: OnboardingFormState,
    onChange: (OnboardingFormState.() -> OnboardingFormState) -> Unit
) {
    StepHeader(
        title = "What is your weight?",
        subtitle = "Select your weight"
    )

    Spacer(Modifier.height(24.dp))

    UnitToggle(
        options = listOf("kg", "lb"),
        selectedIndex = if (form.weightUnit == WeightUnit.KG) 0 else 1,
        onSelect = { idx ->
            onChange { copy(weightUnit = if (idx == 0) WeightUnit.KG else WeightUnit.LB) }
        }
    )

    Spacer(Modifier.height(32.dp))

    if (form.weightUnit == WeightUnit.KG) {
        BigValueDisplay(number = "${form.weightKg}", unit = "kg")
        Spacer(Modifier.height(24.dp))
        Slider(
            value = form.weightKg.toFloat(),
            onValueChange = { onChange { copy(weightKg = it.toInt()) } },
            valueRange = 20f..250f,
            modifier = Modifier.fillMaxWidth(),
            colors = SliderDefaults.colors(
                thumbColor = AITeal,
                activeTrackColor = AITeal,
                inactiveTrackColor = AITeal.copy(alpha = 0.25f)
            )
        )
    } else {
        val lb = (form.weightKg * 2.205).toInt()
        BigValueDisplay(number = "$lb", unit = "lb")
        Spacer(Modifier.height(24.dp))
        Slider(
            value = form.weightKg.toFloat(),
            onValueChange = { onChange { copy(weightKg = it.toInt()) } },
            valueRange = 20f..250f,
            modifier = Modifier.fillMaxWidth(),
            colors = SliderDefaults.colors(
                thumbColor = AITeal,
                activeTrackColor = AITeal,
                inactiveTrackColor = AITeal.copy(alpha = 0.25f)
            )
        )
    }

    Spacer(Modifier.weight(1f))
}

// ─────────────────────────────────────
// MARK: - Step 5: Goal
// ─────────────────────────────────────

@Composable
private fun GoalStep(
    form: OnboardingFormState,
    onChange: (OnboardingFormState.() -> OnboardingFormState) -> Unit
) {
    val scrollState = rememberScrollState()

    StepHeader(
        title = "What's your primary health goal?",
        subtitle = "Select your main health objective"
    )

    Spacer(Modifier.height(20.dp))

    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(scrollState)
    ) {
        PrimaryGoal.entries.forEach { goal ->
            PillCard(
                label = goal.display,
                selected = form.primaryGoal == goal,
                onClick = { onChange { copy(primaryGoal = goal) } }
            )
        }
        Spacer(Modifier.height(8.dp))
    }
}

// ─────────────────────────────────────
// MARK: - Step 6: Activity Level
// ─────────────────────────────────────

@Composable
private fun ColumnScope.ActivityStep(
    form: OnboardingFormState,
    onChange: (OnboardingFormState.() -> OnboardingFormState) -> Unit
) {
    StepHeader(
        title = "What's your activity level?",
        subtitle = "How active are you daily?"
    )

    Spacer(Modifier.height(20.dp))

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ActivityLevel.entries.forEach { level ->
            PillCard(
                label = level.display,
                selected = form.activityLevel == level,
                onClick = { onChange { copy(activityLevel = level) } }
            )
        }
    }

    Spacer(Modifier.weight(1f))
}

// ─────────────────────────────────────
// MARK: - Step 7: Water Intake
// ─────────────────────────────────────

@Composable
private fun ColumnScope.WaterStep(
    form: OnboardingFormState,
    onChange: (OnboardingFormState.() -> OnboardingFormState) -> Unit
) {
    StepHeader(
        title = "How much water do you drink daily?",
        subtitle = "Daily water consumption"
    )

    Spacer(Modifier.height(20.dp))

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        WaterIntake.entries.forEach { intake ->
            PillCard(
                label = intake.display,
                selected = form.waterIntake == intake,
                onClick = { onChange { copy(waterIntake = intake) } }
            )
        }
    }

    Spacer(Modifier.weight(1f))
}

// ─────────────────────────────────────
// MARK: - Shared: Full-width pill card
// iOS spec: 64dp height, RoundedCornerShape(16dp)
// Selected: AITeal fill + white SemiBold text
// Unselected: onSurface 5% fill + onSurface Medium text
// ─────────────────────────────────────

@Composable
private fun PillCard(
    label: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = if (selected) AITeal else AppColors.onSurface.copy(alpha = 0.05f),
        modifier = Modifier
            .fillMaxWidth()
            .height(64.dp)
            .clip(RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            Text(
                text = label,
                fontFamily = PoppinsFontFamily,
                fontSize = 17.sp,
                fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                color = if (selected) Color.White else AppColors.onSurface
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Shared: Big number display (80sp bold, unit in AITeal 24sp)
// ─────────────────────────────────────

@Composable
private fun BigValueDisplay(number: String, unit: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.Bottom
    ) {
        Text(
            text = number,
            fontFamily = PoppinsFontFamily,
            fontSize = 80.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.onSurface,
            lineHeight = 80.sp
        )
        Spacer(Modifier.width(4.dp))
        Text(
            text = unit,
            fontFamily = PoppinsFontFamily,
            fontSize = 24.sp,
            fontWeight = FontWeight.Medium,
            color = AITeal,
            modifier = Modifier.padding(bottom = 12.dp)
        )
    }
}

// ─────────────────────────────────────
// MARK: - Shared: ft/in display (64sp bold each group)
// ─────────────────────────────────────

@Composable
private fun FtInDisplay(feet: Int, inches: Int) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.Bottom
    ) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = "$feet",
                fontFamily = PoppinsFontFamily,
                fontSize = 64.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface,
                lineHeight = 64.sp
            )
            Spacer(Modifier.width(4.dp))
            Text(
                text = "ft",
                fontFamily = PoppinsFontFamily,
                fontSize = 20.sp,
                fontWeight = FontWeight.Medium,
                color = AITeal,
                modifier = Modifier.padding(bottom = 10.dp)
            )
        }
        Spacer(Modifier.width(20.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = "$inches",
                fontFamily = PoppinsFontFamily,
                fontSize = 64.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.onSurface,
                lineHeight = 64.sp
            )
            Spacer(Modifier.width(4.dp))
            Text(
                text = "in",
                fontFamily = PoppinsFontFamily,
                fontSize = 20.sp,
                fontWeight = FontWeight.Medium,
                color = AITeal,
                modifier = Modifier.padding(bottom = 10.dp)
            )
        }
    }
}

// ─────────────────────────────────────
// MARK: - Shared: Unit toggle (pill-shaped tabs)
// Selected: AITeal fill + white text; Unselected: AITeal 10% + AITeal text
// ─────────────────────────────────────

@Composable
private fun UnitToggle(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center
    ) {
        options.forEachIndexed { index, label ->
            val isSelected = index == selectedIndex
            Surface(
                shape = RoundedCornerShape(50),
                color = if (isSelected) AITeal else AITeal.copy(alpha = 0.10f),
                modifier = Modifier
                    .height(36.dp)
                    .clip(RoundedCornerShape(50))
                    .clickable { onSelect(index) }
            ) {
                Box(
                    modifier = Modifier.padding(horizontal = 20.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = label,
                        fontFamily = PoppinsFontFamily,
                        fontSize = 14.sp,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        color = if (isSelected) Color.White else AITeal
                    )
                }
            }
            if (index < options.size - 1) {
                Spacer(Modifier.width(8.dp))
            }
        }
    }
}
