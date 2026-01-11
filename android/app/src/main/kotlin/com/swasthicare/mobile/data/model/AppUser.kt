package com.swasthicare.mobile.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

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
