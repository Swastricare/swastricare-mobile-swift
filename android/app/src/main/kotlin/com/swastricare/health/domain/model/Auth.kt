package com.swastricare.health.domain.model

/**
 * Domain model representing an authenticated user.
 * Pure domain entity without any framework dependencies.
 */
data class User(
    val id: String,
    val email: String,
    val fullName: String? = null,
    val phone: String? = null,
    val avatarUrl: String? = null,
    val createdAt: String? = null
)

/**
 * Domain model for authentication credentials.
 */
data class AuthCredentials(
    val email: String,
    val password: String
)

/**
 * Domain model for sign-up data.
 */
data class SignUpData(
    val email: String,
    val password: String,
    val fullName: String,
    val phone: String = ""
)

/**
 * Domain model for email verification.
 */
data class EmailVerification(
    val email: String,
    val token: String
)

/**
 * Domain model for authentication session.
 */
data class AuthSession(
    val user: User,
    val accessToken: String,
    val refreshToken: String,
    val expiresAt: Long
)

/**
 * Result type for sign-up operations.
 * SignUp can either immediately succeed with a User,
 * or require email verification first.
 */
sealed class SignUpResult {
    data class Success(val user: User) : SignUpResult()
    data class EmailVerificationRequired(val email: String) : SignUpResult()
}
