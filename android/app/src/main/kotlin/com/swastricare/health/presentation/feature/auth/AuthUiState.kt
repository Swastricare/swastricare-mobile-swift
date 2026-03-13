package com.swastricare.health.presentation.feature.auth

import com.swastricare.health.domain.model.User

/**
 * UI State for authentication screens.
 * Represents all possible states of the authentication flow.
 */
sealed class AuthUiState {
    data object Idle : AuthUiState()
    data object Loading : AuthUiState()
    data class Success(val user: User) : AuthUiState()
    data class Error(val message: String) : AuthUiState()
    data class EmailVerificationRequired(val email: String) : AuthUiState()
}

/**
 * Form state for login and sign-up screens.
 * Manages user input and client-side validation.
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
        get() = phone.isEmpty() || phone.length >= 10

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
