package com.swasthicare.mobile.data.model

enum class VaultCategory(val title: String, val iconName: String, val colorHex: Long) {
    PRESCRIPTIONS("Prescriptions", "medication", 0xFFFF5252),
    LAB_REPORTS("Lab Reports", "science", 0xFF448AFF),
    IMAGING("Imaging", "image", 0xFF7C4DFF),
    INSURANCE("Insurance", "verified_user", 0xFF4CAF50),
    VACCINATIONS("Vaccinations", "vaccines", 0xFFFFC107),
    OTHER("Other", "folder", 0xFF9E9E9E);

    companion object {
        fun fromValue(value: String): VaultCategory {
            return entries.find { it.title.equals(value, ignoreCase = true) } ?: OTHER
        }
    }
}
