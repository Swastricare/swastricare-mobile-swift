package com.swastricare.health.domain.usecase.auth

import javax.inject.Inject

/**
 * Use case for email validation.
 * Encapsulates the business rules for valid email addresses.
 *
 * Single Responsibility: Validate email format
 */
class ValidateEmailUseCase @Inject constructor() {

    /**
     * Validate email address format.
     * @param email Email address to validate
     * @return ValidationResult with success/error message
     */
    operator fun invoke(email: String): ValidationResult {
        if (email.isBlank()) {
            return ValidationResult.Error("Email cannot be empty")
        }

        if (!EMAIL_REGEX.matches(email)) {
            return ValidationResult.Error("Please enter a valid email address")
        }

        return ValidationResult.Success
    }

    companion object {
        private val EMAIL_REGEX = Regex(
            "^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$"
        )
    }
}

/**
 * Result of a validation operation.
 */
sealed class ValidationResult {
    data object Success : ValidationResult()
    data class Error(val message: String) : ValidationResult()
}
