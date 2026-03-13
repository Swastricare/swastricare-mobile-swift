package com.swastricare.health.domain.model.ai

/**
 * Domain model for health context data.
 * Provides health information to AI for context-aware responses.
 */
data class HealthContext(
    val steps: Int = 0,
    val heartRate: Int = 0,
    val sleep: String = "0h 0m",
    val activeCalories: Int = 0,
    val exerciseMinutes: Int = 0,
    val bloodPressure: String = "--/--",
    val weight: String = "--",
    val hydrationMl: Int = 0,
    val currentMedications: List<String> = emptyList()
) {
    /**
     * Business logic: Check if health context is empty (no data available).
     */
    fun isEmpty(): Boolean {
        return steps == 0 &&
            heartRate == 0 &&
            sleep == "0h 0m" &&
            activeCalories == 0 &&
            exerciseMinutes == 0
    }

    /**
     * Business logic: Convert to formatted string for AI context.
     */
    fun toContextString(): String {
        return buildString {
            appendLine("Current Health Status:")
            appendLine("- Steps: $steps")
            if (heartRate > 0) appendLine("- Heart Rate: $heartRate bpm")
            if (sleep != "0h 0m") appendLine("- Sleep: $sleep")
            if (activeCalories > 0) appendLine("- Active Calories: $activeCalories kcal")
            if (exerciseMinutes > 0) appendLine("- Exercise Minutes: $exerciseMinutes min")
            if (bloodPressure != "--/--") appendLine("- Blood Pressure: $bloodPressure")
            if (weight != "--") appendLine("- Weight: $weight kg")
            if (hydrationMl > 0) appendLine("- Hydration: ${hydrationMl}ml")
            if (currentMedications.isNotEmpty()) {
                appendLine("- Current Medications: ${currentMedications.joinToString(", ")}")
            }
        }
    }

    /**
     * Business logic: Get health summary for quick insights.
     */
    fun getSummary(): String {
        val items = mutableListOf<String>()
        if (steps > 0) items.add("$steps steps")
        if (heartRate > 0) items.add("${heartRate} bpm")
        if (exerciseMinutes > 0) items.add("${exerciseMinutes}min exercise")
        return items.joinToString(" • ")
    }
}
