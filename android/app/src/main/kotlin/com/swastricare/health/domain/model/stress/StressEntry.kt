package com.swastricare.health.domain.model.stress

import java.time.LocalDateTime

data class StressEntry(
    val id: String = java.util.UUID.randomUUID().toString(),
    val healthProfileId: String? = null,
    val stressLevel: Int, // 1-10
    val calculatedStressPercent: Int = 0, // 0-100 ("X% Good")
    val mood: StressMood = StressMood.NEUTRAL,
    val notes: String = "",
    val timestamp: LocalDateTime = LocalDateTime.now(),
    val source: StressSource = StressSource.MANUAL,
    val category: StressCategory = StressCategory.fromLevel(stressLevel),
    val synced: Boolean = false
) {
    fun isValid(): Boolean = stressLevel in 1..10
}

enum class StressSource(val displayName: String) {
    MANUAL("Manual"),
    CALCULATED("Calculated"),
    DEVICE("Device")
}

enum class StressMood(val emoji: String, val displayName: String) {
    CALM("\uD83D\uDE0C", "Calm"),
    HAPPY("\uD83D\uDE0A", "Happy"),
    NEUTRAL("\uD83D\uDE10", "Neutral"),
    ANXIOUS("\uD83D\uDE1F", "Anxious"),
    STRESSED("\uD83D\uDE23", "Stressed"),
    OVERWHELMED("\uD83E\uDD2F", "Overwhelmed")
}

enum class StressCategory(
    val displayName: String,
    val colorHex: Long,
    val description: String
) {
    LOW("Low", 0xFF4CAF50, "You're doing great — keep it up!"),
    MODERATE("Moderate", 0xFFFFC107, "Manageable stress — stay mindful"),
    HIGH("High", 0xFFFF9800, "Elevated stress — consider a break"),
    SEVERE("Severe", 0xFFF44336, "High stress — prioritise self-care");

    companion object {
        fun fromLevel(level: Int): StressCategory = when (level) {
            in 1..3 -> LOW
            in 4..6 -> MODERATE
            in 7..8 -> HIGH
            else -> SEVERE
        }
    }
}
