package com.swastricare.health.util

import com.swastricare.health.data.models.HydrationEntry
import com.swastricare.health.data.models.HydrationPreferences
import com.swastricare.health.domain.model.Auth
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
        synced: Boolean = false,
        healthProfileId: String = "test-profile-id",
        effectiveMl: Int = amountMl
    ) = HydrationEntry(
        id = id,
        amountMl = amountMl,
        drinkType = drinkType,
        consumedAt = consumedAt,
        synced = synced,
        healthProfileId = healthProfileId,
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
        gender: String = "male",
        activityLevel: String = "moderate",
        climate: String = "temperate"
    ) = HydrationPreferences(
        weightKg = weightKg,
        gender = gender,
        activityLevel = activityLevel,
        climate = climate
    )

    // ─────────────────────────────────────
    // MARK: - Auth Test Data
    // ─────────────────────────────────────

    fun createAuthUser(
        id: String = "test-user-id",
        email: String = "test@example.com"
    ) = Auth.User(
        id = id,
        email = email
    )

    fun createAuthSession(
        accessToken: String = "test-access-token",
        refreshToken: String = "test-refresh-token",
        user: Auth.User = createAuthUser()
    ) = Auth.Session(
        accessToken = accessToken,
        refreshToken = refreshToken,
        user = user
    )

    // ─────────────────────────────────────
    // MARK: - Common Test Data
    // ─────────────────────────────────────

    const val TEST_PROFILE_ID = "test-profile-id"
    const val TEST_USER_ID = "test-user-id"
    const val TEST_EMAIL = "test@example.com"
}
