package com.swastricare.health.data.remote.dto.auth

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Data Transfer Object for user data from Supabase.
 * Maps directly to Supabase UserInfo structure.
 */
@Serializable
data class UserDto(
    val id: String,
    val email: String? = null,
    val phone: String? = null,
    @SerialName("user_metadata")
    val userMetadata: Map<String, String>? = null,
    @SerialName("created_at")
    val createdAt: String? = null
)

/**
 * DTO for phone update in public.users table.
 */
@Serializable
data class PhoneUpdateDto(
    val phone: String
)

/**
 * DTO for sign-up request.
 */
@Serializable
data class SignUpRequestDto(
    val email: String,
    val password: String,
    @SerialName("full_name")
    val fullName: String,
    val phone: String? = null
)

/**
 * DTO for login request.
 */
@Serializable
data class LoginRequestDto(
    val email: String,
    val password: String
)

/**
 * DTO for email verification request.
 */
@Serializable
data class EmailVerificationDto(
    val email: String,
    val token: String
)
