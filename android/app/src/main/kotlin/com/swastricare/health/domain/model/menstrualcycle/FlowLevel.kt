package com.swastricare.health.domain.model.menstrualcycle

/**
 * Enum representing menstrual flow intensity levels.
 */
enum class FlowLevel(val displayName: String, val emoji: String) {
    NONE("None", ""),
    LIGHT("Light", "💧"),
    MEDIUM("Medium", "💧💧"),
    HEAVY("Heavy", "💧💧💧"),
    VERY_HEAVY("Very Heavy", "💧💧💧💧");

    /**
     * Returns true if this represents an active flow (not NONE).
     */
    val isActiveFlow: Boolean
        get() = this != NONE
}
