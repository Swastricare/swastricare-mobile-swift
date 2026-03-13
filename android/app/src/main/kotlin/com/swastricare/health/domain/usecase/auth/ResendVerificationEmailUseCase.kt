package com.swastricare.health.domain.usecase.auth

import com.swastricare.health.domain.repository.AuthRepository
import javax.inject.Inject

/**
 * Use case for resending verification email.
 * Encapsulates the business logic for requesting a new OTP.
 *
 * Single Responsibility: Handle resend verification email flow
 */
class ResendVerificationEmailUseCase @Inject constructor(
    private val authRepository: AuthRepository
) {
    /**
     * Execute resend verification email operation.
     * @param email Email address to send verification to
     * @throws Exception if resend fails
     */
    suspend operator fun invoke(email: String) {
        authRepository.resendVerificationEmail(email)
    }
}
