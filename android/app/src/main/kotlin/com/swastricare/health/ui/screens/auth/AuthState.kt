package com.swastricare.health.ui.screens.auth

import com.swastricare.health.data.model.AppUser

/**
 * Authentication UI State
 * Represents the current state of authentication in the app
 * Matches iOS AuthState enum
 */
sealed class AuthUiState {
    data object Idle : AuthUiState()
    data object Loading : AuthUiState()
    data class Success(val user: AppUser) : AuthUiState()
    data class Error(val message: String) : AuthUiState()
    data class EmailVerificationRequired(val email: String) : AuthUiState()
    data object PasswordRecovery : AuthUiState()
    data object ProcessingDeepLink : AuthUiState()
}

/**
 * Form State for Login and Sign Up
 * Manages form input and validation
 * Matches iOS AuthFormState
 */
data class AuthFormState(
    val email: String = "",
    val password: String = "",
    val fullName: String = "",
    val phone: String = "",
    val confirmPassword: String = "",
) {
    val isValidEmail: Boolean
        get() = EMAIL_REGEX.matches(email)

    val isValidPassword: Boolean
        get() = password.length >= 8
            && password.any { it.isUpperCase() }
            && password.any { it.isLowerCase() }
            && password.any { it.isDigit() }

    val passwordError: String?
        get() = when {
            password.isEmpty() -> null
            password.length < 8 -> "Password must be at least 8 characters"
            !password.any { it.isUpperCase() } -> "Password must contain an uppercase letter"
            !password.any { it.isLowerCase() } -> "Password must contain a lowercase letter"
            !password.any { it.isDigit() } -> "Password must contain a number"
            else -> null
        }

    val isValidPhone: Boolean
        get() = phone.length == 10

    val passwordsMatch: Boolean
        get() = password == confirmPassword && password.isNotEmpty()

    val isValidForLogin: Boolean
        get() = isValidEmail && password.isNotEmpty()

    val isValidForSignUp: Boolean
        get() = isValidEmail && isValidPassword && passwordsMatch && fullName.isNotEmpty()

    companion object {
        private val EMAIL_REGEX = Regex(
            "^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$"
        )
    }
}
