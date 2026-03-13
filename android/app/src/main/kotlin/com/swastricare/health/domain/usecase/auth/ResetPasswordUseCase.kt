package com.swastricare.health.domain.usecase.auth

import com.swastricare.health.domain.repository.AuthRepository
import javax.inject.Inject

/**
 * Use case for password reset.
 * Encapsulates the business logic for requesting password reset.
 *
 * Single Responsibility: Handle password reset flow
 */
class ResetPasswordUseCase @Inject constructor(
    private val authRepository: AuthRepository
) {
    /**
     * Execute password reset operation.
     * Sends a password reset link to the user's email.
     * @param email Email address to send reset link to
     * @throws Exception if reset request fails
     */
    suspend operator fun invoke(email: String) {
        authRepository.resetPassword(email)
    }
}
