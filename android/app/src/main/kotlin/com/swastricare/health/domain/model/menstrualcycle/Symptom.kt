package com.swastricare.health.domain.model.menstrualcycle

/**
 * Enum representing common menstrual symptoms.
 */
enum class Symptom(val displayName: String, val emoji: String, val category: SymptomCategory) {
    // Physical symptoms
    CRAMPS("Cramps", "😣", SymptomCategory.PHYSICAL),
    BLOATING("Bloating", "🫄", SymptomCategory.PHYSICAL),
    FATIGUE("Fatigue", "😴", SymptomCategory.PHYSICAL),
    HEADACHE("Headache", "🤕", SymptomCategory.PHYSICAL),
    BACKACHE("Backache", "🔙", SymptomCategory.PHYSICAL),
    NAUSEA("Nausea", "🤢", SymptomCategory.PHYSICAL),
    BREAST_TENDERNESS("Breast Tenderness", "⚡", SymptomCategory.PHYSICAL),

    // Emotional symptoms
    MOOD_SWINGS("Mood Swings", "🎭", SymptomCategory.EMOTIONAL),
    ANXIETY("Anxiety", "😰", SymptomCategory.EMOTIONAL),
    IRRITABILITY("Irritability", "😤", SymptomCategory.EMOTIONAL),

    // Other symptoms
    ACNE("Acne", "😖", SymptomCategory.SKIN),
    INSOMNIA("Insomnia", "😵", SymptomCategory.SLEEP),
    CRAVINGS("Cravings", "🍫", SymptomCategory.APPETITE),
    SPOTTING("Spotting", "🔴", SymptomCategory.BLEEDING);

    companion object {
        /**
         * Groups symptoms by category for easier display.
         */
        fun groupedByCategory(): Map<SymptomCategory, List<Symptom>> {
            return entries.groupBy { it.category }
        }
    }
}

/**
 * Categories for organizing symptoms.
 */
enum class SymptomCategory(val displayName: String) {
    PHYSICAL("Physical"),
    EMOTIONAL("Emotional"),
    SKIN("Skin"),
    SLEEP("Sleep"),
    APPETITE("Appetite"),
    BLEEDING("Bleeding")
}
