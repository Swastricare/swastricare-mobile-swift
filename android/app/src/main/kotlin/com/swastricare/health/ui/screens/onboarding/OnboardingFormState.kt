package com.swastricare.health.ui.screens.onboarding

import com.swastricare.health.domain.model.profile.Gender
import java.time.LocalDate

enum class HeightUnit { CM, FT_IN }
enum class WeightUnit { KG, LB }

enum class PrimaryGoal(val display: String) {
    TRACK_HEALTH("Track health"),
    CONTROL_SUGAR("Control sugar"),
    CONTROL_BP("Control BP"),
    IMPROVE_HEART_HEALTH("Improve heart health"),
    IMPROVE_SLEEP("Improve sleep"),
    REDUCE_STRESS("Reduce stress"),
    FITNESS_TRACKING("Fitness tracking"),
    PREGNANCY_CARE("Pregnancy care"),
    OTHER("Other")
}

enum class ActivityLevel(val display: String) {
    SEDENTARY("Sedentary"),
    LIGHT("Light"),
    MODERATE("Moderate"),
    VERY_ACTIVE("Very active")
}

enum class WaterIntake(val display: String) {
    LESS_THAN_1L("<1L"),
    ONE_TO_TWO("1-2L"),
    TWO_TO_THREE("2-3L"),
    THREE_PLUS("3L+")
}

data class OnboardingFormState(
    val fullName: String = "",
    val gender: Gender? = null,
    val dateOfBirth: LocalDate? = null,
    val heightCm: Int = 170,
    val heightUnit: HeightUnit = HeightUnit.CM,
    val weightKg: Int = 65,
    val weightUnit: WeightUnit = WeightUnit.KG,
    val primaryGoal: PrimaryGoal? = null,
    val activityLevel: ActivityLevel? = null,
    val waterIntake: WaterIntake? = null
)
