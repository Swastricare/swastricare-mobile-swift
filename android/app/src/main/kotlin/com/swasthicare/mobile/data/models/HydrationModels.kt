package com.swasthicare.mobile.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

// ─────────────────────────────────────
// MARK: - ActivityLevel
// ─────────────────────────────────────

enum class ActivityLevel(
    val dbValue: String,
    val displayName: String,
    val description: String,
    val multiplier: Double,
    val icon: String
) {
    SEDENTARY("sedentary", "Sedentary", "Desk job, minimal exercise", 0.9, "🪑"),
    MODERATE("moderate", "Moderate Activity", "Regular exercise, active lifestyle", 1.0, "🚶"),
    HIGH("high", "High Activity", "Intense workouts, athlete", 1.15, "🏃"),
    OUTDOOR("outdoor", "Outdoor/Hot Climate", "Outdoor work, hot climate exposure", 1.2, "☀️");

    companion object {
        fun fromDb(value: String): ActivityLevel =
            entries.firstOrNull { it.dbValue == value } ?: MODERATE
    }
}

// ─────────────────────────────────────
// MARK: - DrinkType
// ─────────────────────────────────────

enum class DrinkType(
    val dbValue: String,
    val displayName: String,
    val icon: String,
    val hydrationMultiplier: Double,
    val containsCaffeine: Boolean
) {
    WATER("water", "Water", "💧", 1.0, false),
    TEA("tea", "Tea", "🍵", 0.85, true),
    COFFEE("coffee", "Coffee", "☕", 0.8, true),
    JUICE("juice", "Juice", "🧃", 0.9, false),
    MILK("milk", "Milk", "🥛", 0.9, false),
    SPORTS_DRINK("sports_drink", "Sports Drink", "🥤", 1.0, false),
    OTHER("other", "Other", "🫗", 0.9, false);

    companion object {
        fun fromDb(value: String): DrinkType =
            entries.firstOrNull { it.dbValue == value } ?: WATER
    }
}

// ─────────────────────────────────────
// MARK: - HydrationEntry
// ─────────────────────────────────────

@Serializable
data class HydrationEntry(
    val id: String = UUID.randomUUID().toString(),
    @SerialName("drink_type") val drinkType: String = "water",
    @SerialName("amount_ml") val amountMl: Int,
    @SerialName("effective_ml") val effectiveMl: Int = 0,
    @SerialName("consumed_at") val consumedAt: String, // ISO datetime "2026-03-02T08:30:00"
    val notes: String? = null,
    val synced: Boolean = false
) {
    val drinkTypeEnum: DrinkType get() = DrinkType.fromDb(drinkType)

    val formattedTime: String get() {
        // Extract HH:mm from ISO datetime and convert to 12h format
        val timePart = consumedAt.substringAfter("T").take(5) // "08:30"
        val parts = timePart.split(":")
        if (parts.size < 2) return timePart
        val hour = parts[0].toIntOrNull() ?: return timePart
        val minute = parts[1]
        val amPm = if (hour < 12) "AM" else "PM"
        val hour12 = when {
            hour == 0 -> 12
            hour > 12 -> hour - 12
            else -> hour
        }
        return "$hour12:$minute $amPm"
    }
}

// ─────────────────────────────────────
// MARK: - HydrationPreferences
// ─────────────────────────────────────

@Serializable
data class HydrationPreferences(
    @SerialName("activity_level") val activityLevel: String = "moderate",
    @SerialName("weight_kg") val weightKg: Double? = null,
    @SerialName("custom_goal_ml") val customGoalMl: Int? = null
) {
    val activityLevelEnum: ActivityLevel get() = ActivityLevel.fromDb(activityLevel)

    companion object {
        val Default = HydrationPreferences()
    }
}

// ─────────────────────────────────────
// MARK: - HydrationGoal
// ─────────────────────────────────────

data class HydrationGoal(
    val dailyGoalMl: Int = 2500,
    val breakdown: GoalBreakdown = GoalBreakdown()
) {
    data class GoalBreakdown(
        val baseAmount: Int = 2310,
        val activityBonus: Int = 0
    ) {
        val description: String get() {
            val parts = mutableListOf("${baseAmount}ml base")
            if (activityBonus != 0) {
                val sign = if (activityBonus > 0) "+" else ""
                parts.add("${sign}${activityBonus}ml activity")
            }
            return parts.joinToString(", ")
        }
    }
}

// ─────────────────────────────────────
// MARK: - QuickAddPreset
// ─────────────────────────────────────

data class QuickAddPreset(
    val amountMl: Int,
    val label: String,
    val icon: String
) {
    companion object {
        val defaults = listOf(
            QuickAddPreset(100, "100ml", "💧"),
            QuickAddPreset(250, "250ml", "🥛"),
            QuickAddPreset(500, "500ml", "🍶"),
            QuickAddPreset(750, "750ml", "🫗"),
            QuickAddPreset(1000, "1L", "🧴")
        )
    }
}

// ─────────────────────────────────────
// MARK: - HydrationInsights
// ─────────────────────────────────────

data class HydrationInsights(
    val streakDays: Int = 0,
    val avgDailyIntake: Int = 0,
    val mostCommonDrink: String? = null,
    val caffeineCount: Int = 0,
    val caffeineAmountMl: Int = 0
)

// ─────────────────────────────────────
// MARK: - Urine Color Guide
// ─────────────────────────────────────

data class UrineColorLevel(
    val level: Int,
    val name: String,
    val colorHex: Long,
    val status: String,
    val recommendation: String
) {
    companion object {
        val guide = listOf(
            UrineColorLevel(0, "Clear", 0xFFFAFAF2, "Over Hydrated", "You might be drinking too much. Slow down unless exercising heavily."),
            UrineColorLevel(1, "Pale Yellow", 0xFFFAF7CC, "Well Hydrated", "Great job! You're well hydrated."),
            UrineColorLevel(2, "Light Yellow", 0xFFFAF299, "Well Hydrated", "Keep up the good work."),
            UrineColorLevel(3, "Yellow", 0xFFFAE666, "Normal", "You're doing okay. Have a glass of water soon."),
            UrineColorLevel(4, "Dark Yellow", 0xFFF2D94D, "Mildly Dehydrated", "Time to drink some water. Have a glass now."),
            UrineColorLevel(5, "Amber", 0xFFE6B333, "Dehydrated", "You need to drink water soon. Aim for 2-3 glasses."),
            UrineColorLevel(6, "Honey", 0xFFCC8C26, "Dehydrated", "Drink water now. Consider an electrolyte drink."),
            UrineColorLevel(7, "Brown", 0xFF99591A, "Severely Dehydrated", "Drink water immediately. If this persists, consult a doctor.")
        )
    }
}

// ─────────────────────────────────────
// MARK: - HydrationCalculator
// ─────────────────────────────────────

object HydrationCalculator {
    /** Base multiplier: 33ml per kg body weight */
    const val BASE_MULTIPLIER = 33.0

    /** Default goal if no weight available */
    const val DEFAULT_GOAL = 2500

    fun calculateGoal(prefs: HydrationPreferences): HydrationGoal {
        // If custom goal is set, use it directly
        prefs.customGoalMl?.let { custom ->
            return HydrationGoal(
                dailyGoalMl = custom,
                breakdown = HydrationGoal.GoalBreakdown(baseAmount = custom, activityBonus = 0)
            )
        }

        val weight = prefs.weightKg ?: 70.0
        val baseAmount = (weight * BASE_MULTIPLIER).toInt()
        val activityLevel = prefs.activityLevelEnum

        val activityAdjusted = (baseAmount * activityLevel.multiplier).toInt()
        val activityBonus = activityAdjusted - baseAmount

        return HydrationGoal(
            dailyGoalMl = activityAdjusted,
            breakdown = HydrationGoal.GoalBreakdown(
                baseAmount = baseAmount,
                activityBonus = activityBonus
            )
        )
    }
}

// ─────────────────────────────────────
// MARK: - Supabase DTO for hydration_logs
// ─────────────────────────────────────

@Serializable
data class HydrationEntryRecord(
    val id: String,
    @SerialName("health_profile_id") val healthProfileId: String,
    @SerialName("beverage_type") val beverageType: String,
    @SerialName("amount_ml") val amountMl: Int,
    @SerialName("consumed_at") val consumedAt: String,
    val notes: String? = null,
    @SerialName("hydration_factor") val hydrationFactor: Double
) {
    companion object {
        fun from(entry: HydrationEntry, profileId: String): HydrationEntryRecord {
            val drinkType = DrinkType.fromDb(entry.drinkType)
            return HydrationEntryRecord(
                id = entry.id,
                healthProfileId = profileId,
                beverageType = entry.drinkType,
                amountMl = entry.amountMl,
                consumedAt = entry.consumedAt,
                notes = entry.notes,
                hydrationFactor = drinkType.hydrationMultiplier
            )
        }
    }
}
