package com.swasthicare.mobile.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Row from the `profiles` table — always exists for any signed-in user. */
@Serializable
data class UserProfileRow(
    val id: String,
    @SerialName("full_name")
    val fullName: String? = null,
    @SerialName("avatar_url")
    val avatarUrl: String? = null,
    @SerialName("created_at")
    val createdAt: String? = null
)

@Serializable
data class AppUser(
    val id: String,
    val email: String?,
    
    @SerialName("full_name")
    val fullName: String? = null,
    
    @SerialName("avatar_url")
    val avatarUrl: String? = null,
    
    @SerialName("created_at")
    val createdAt: String? = null
)
