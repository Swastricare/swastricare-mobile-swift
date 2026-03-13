package com.swastricare.health.util

import com.swastricare.health.data.models.HydrationEntry
import com.swastricare.health.data.models.HydrationPreferences
import com.swastricare.health.domain.model.AuthCredentials
import com.swastricare.health.domain.model.SignUpData
import com.swastricare.health.domain.model.User
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

/**
 * Factory for creating mock test data.
 * Provides consistent test data across all tests.
 */
object MockFactory {

    private val isoFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")

    // ─────────────────────────────────────
    // MARK: - Hydration Test Data
    // ─────────────────────────────────────

    fun createHydrationEntry(
        id: String = UUID.randomUUID().toString(),
        amountMl: Int = 250,
        drinkType: String = "water",
        consumedAt: String = LocalDateTime.now().format(isoFormatter),
        effectiveMl: Int = amountMl
    ) = HydrationEntry(
        id = id,
        amountMl = amountMl,
        drinkType = drinkType,
        consumedAt = consumedAt,
        effectiveMl = effectiveMl
    )

    fun createHydrationEntries(count: Int = 5): List<HydrationEntry> {
        return List(count) { index ->
            createHydrationEntry(
                id = "test-entry-$index",
                amountMl = 250 + (index * 50),
                consumedAt = LocalDateTime.now().minusHours(index.toLong()).format(isoFormatter)
            )
        }
    }

    fun createHydrationPreferences(
        weightKg: Double = 70.0,
        activityLevel: String = "moderate"
    ) = HydrationPreferences(
        weightKg = weightKg,
        activityLevel = activityLevel
    )

    // ─────────────────────────────────────
    // MARK: - Auth Test Data
    // ─────────────────────────────────────

    fun createUser(
        id: String = "test-user-id",
        email: String = "test@example.com"
    ) = User(
        id = id,
        email = email
    )

    fun createAuthCredentials(
        email: String = TEST_EMAIL,
        password: String = "testPassword123"
    ) = AuthCredentials(
        email = email,
        password = password
    )

    fun createSignUpData(
        email: String = TEST_EMAIL,
        password: String = "testPassword123",
        fullName: String = "Test User",
        phone: String = ""
    ) = SignUpData(
        email = email,
        password = password,
        fullName = fullName,
        phone = phone
    )

    // ─────────────────────────────────────
    // MARK: - Common Test Data
    // ─────────────────────────────────────

    const val TEST_PROFILE_ID = "test-profile-id"
    const val TEST_USER_ID = "test-user-id"
    const val TEST_EMAIL = "test@example.com"
}
