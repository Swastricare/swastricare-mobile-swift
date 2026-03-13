package com.swastricare.health.domain.model.profile

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Domain model for user profile.
 * Represents the basic user account information.
 */
data class UserProfile(
    val id: String,
    val email: String?,
    val fullName: String?,
    val phone: String? = null,
    val bio: String? = null,
    val avatarUrl: String? = null,
    val createdAt: LocalDateTime
) {
    /**
     * Business logic: Get formatted member since date.
     */
    fun getMemberSince(pattern: String = "MMM d, yyyy"): String {
        val formatter = DateTimeFormatter.ofPattern(pattern, Locale.getDefault())
        return createdAt.format(formatter)
    }

    /**
     * Business logic: Get display name (full name or email).
     */
    fun getDisplayName(): String {
        return when {
            !fullName.isNullOrBlank() -> fullName
            !email.isNullOrBlank() -> email
            else -> "User"
        }
    }

    /**
     * Business logic: Check if profile is complete.
     */
    fun isComplete(): Boolean {
        return !fullName.isNullOrBlank() && !email.isNullOrBlank()
    }

    /**
     * Business logic: Get initials for avatar.
     */
    fun getInitials(): String {
        return when {
            !fullName.isNullOrBlank() -> {
                fullName.split(" ")
                    .take(2)
                    .mapNotNull { it.firstOrNull()?.uppercaseChar() }
                    .joinToString("")
            }
            !email.isNullOrBlank() -> email.first().uppercaseChar().toString()
            else -> "U"
        }
    }
}
