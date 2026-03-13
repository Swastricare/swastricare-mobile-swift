package com.swastricare.health.domain.usecase.auth

import com.swastricare.health.domain.model.EmailVerification
import com.swastricare.health.domain.model.User
import com.swastricare.health.domain.repository.AuthRepository
import javax.inject.Inject

/**
 * Use case for email OTP verification.
 * Encapsulates the business logic for verifying email addresses.
 *
 * Single Responsibility: Handle email verification flow
 */
class VerifyEmailOtpUseCase @Inject constructor(
    private val authRepository: AuthRepository
) {
    /**
     * Execute email verification operation.
     * @param email Email address to verify
     * @param token 6-digit OTP token
     * @return Authenticated User
     * @throws Exception if verification fails
     */
    suspend operator fun invoke(email: String, token: String): User {
        return authRepository.verifyEmailOtp(
            EmailVerification(email = email, token = token)
        )
    }
}
