package com.swastricare.health.domain.usecase.auth

import javax.inject.Inject

/**
 * Use case for password validation.
 * Encapsulates the business rules for secure passwords.
 *
 * Single Responsibility: Validate password strength
 */
class ValidatePasswordUseCase @Inject constructor() {

    /**
     * Validate password strength.
     * Password must be:
     * - At least 8 characters
     * - Contain uppercase letter
     * - Contain lowercase letter
     * - Contain a number
     *
     * @param password Password to validate
     * @return ValidationResult with success/error message
     */
    operator fun invoke(password: String): ValidationResult {
        if (password.isBlank()) {
            return ValidationResult.Error("Password cannot be empty")
        }

        if (password.length < 8) {
            return ValidationResult.Error("Password must be at least 8 characters")
        }

        if (!password.any { it.isUpperCase() }) {
            return ValidationResult.Error("Password must contain an uppercase letter")
        }

        if (!password.any { it.isLowerCase() }) {
            return ValidationResult.Error("Password must contain a lowercase letter")
        }

        if (!password.any { it.isDigit() }) {
            return ValidationResult.Error("Password must contain a number")
        }

        return ValidationResult.Success
    }
}
