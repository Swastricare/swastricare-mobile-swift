package com.swastricare.health.domain.model.hydration

/**
 * Domain model for drink types.
 * Represents different beverages and their hydration characteristics.
 */
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
