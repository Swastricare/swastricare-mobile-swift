package com.swastricare.health.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Row from the `emergency_contacts` table.
 * Linked to a health_profile via [healthProfileId].
 */
@Serializable
data class EmergencyContact(
    val id: String? = null,

    @SerialName("health_profile_id")
    val healthProfileId: String,

    val name: String,
    val relationship: String,

    @SerialName("phone_primary")
    val phonePrimary: String,

    @SerialName("phone_secondary")
    val phoneSecondary: String? = null,

    val email: String? = null,

    val priority: Int = 1,

    val notes: String? = null,

    @SerialName("created_at")
    val createdAt: String? = null,

    @SerialName("updated_at")
    val updatedAt: String? = null
)

/** Row from the `profiles` table — always exists for any signed-in user. */
@Serializable
data class UserProfileRow(
    val id: String,
    @SerialName("full_name")
    val fullName: String? = null,
    @SerialName("avatar_url")
    val avatarUrl: String? = null,
    val phone: String? = null,
    val bio: String? = null,
    @SerialName("created_at")
    val createdAt: String? = null
)

@Serializable
data class AppUser(
    val id: String,
    val email: String?,

    @SerialName("full_name")
    val fullName: String? = null,

    val phone: String? = null,

    val bio: String? = null,

    val city: String? = null,

    @SerialName("avatar_url")
    val avatarUrl: String? = null,

    @SerialName("created_at")
    val createdAt: String? = null
)
