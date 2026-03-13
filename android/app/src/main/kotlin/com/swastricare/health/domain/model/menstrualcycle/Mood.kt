package com.swastricare.health.domain.model.menstrualcycle

/**
 * Enum representing mood states during menstrual cycle.
 */
enum class Mood(val displayName: String, val emoji: String) {
    HAPPY("Happy", "😊"),
    CALM("Calm", "😌"),
    ENERGETIC("Energetic", "⚡"),
    ANXIOUS("Anxious", "😰"),
    SAD("Sad", "😢"),
    IRRITABLE("Irritable", "😤"),
    TIRED("Tired", "😴"),
    NEUTRAL("Neutral", "😐");

    /**
     * Returns true if this is a positive mood.
     */
    val isPositive: Boolean
        get() = this in listOf(HAPPY, CALM, ENERGETIC)

    /**
     * Returns true if this is a negative mood.
     */
    val isNegative: Boolean
        get() = this in listOf(ANXIOUS, SAD, IRRITABLE)
}
