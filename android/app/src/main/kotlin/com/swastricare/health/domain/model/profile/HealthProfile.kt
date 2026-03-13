package com.swastricare.health.domain.model.profile

import java.time.LocalDate
import java.time.Period
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Domain model for health profile.
 * Pure business model with no Android/Framework dependencies.
 */
data class HealthProfile(
    val id: String,
    val userId: String,
    val fullName: String,
    val gender: Gender,
    val dateOfBirth: LocalDate,
    val heightCm: Double,
    val weightKg: Double,
    val bloodType: String? = null
) {
    /**
     * Business logic: Calculate age from date of birth.
     */
    fun calculateAge(currentDate: LocalDate = LocalDate.now()): Int {
        return Period.between(dateOfBirth, currentDate).years
    }

    /**
     * Business logic: Calculate BMI (Body Mass Index).
     */
    fun calculateBmi(): Double {
        val heightM = heightCm / 100.0
        return if (heightM > 0) weightKg / (heightM * heightM) else 0.0
    }

    /**
     * Business logic: Get BMI category.
     */
    fun getBmiCategory(): BmiCategory {
        val bmi = calculateBmi()
        return when {
            bmi < 18.5 -> BmiCategory.UNDERWEIGHT
            bmi < 25.0 -> BmiCategory.NORMAL
            bmi < 30.0 -> BmiCategory.OVERWEIGHT
            else -> BmiCategory.OBESE
        }
    }

    /**
     * Business logic: Get formatted date of birth.
     */
    fun getFormattedDateOfBirth(pattern: String = "yyyy-MM-dd"): String {
        val formatter = DateTimeFormatter.ofPattern(pattern, Locale.getDefault())
        return dateOfBirth.format(formatter)
    }

    /**
     * Business logic: Check if profile is complete.
     */
    fun isComplete(): Boolean {
        return fullName.isNotBlank() &&
                heightCm > 0 &&
                weightKg > 0
    }
}

/**
 * Gender enum for health profile.
 */
enum class Gender(val displayName: String, val dbValue: String) {
    MALE("Male", "male"),
    FEMALE("Female", "female"),
    OTHER("Other", "other"),
    PREFER_NOT_TO_SAY("Prefer not to say", "prefer_not_to_say");

    companion object {
        fun fromDb(value: String): Gender {
            return values().find { it.dbValue == value } ?: PREFER_NOT_TO_SAY
        }
    }
}

/**
 * BMI category classification.
 */
enum class BmiCategory(val displayName: String, val description: String) {
    UNDERWEIGHT("Underweight", "Below healthy weight range"),
    NORMAL("Normal", "Within healthy weight range"),
    OVERWEIGHT("Overweight", "Above healthy weight range"),
    OBESE("Obese", "Significantly above healthy weight range")
}
