package com.swastricare.health.domain.usecase.auth

import com.swastricare.health.domain.model.User
import com.swastricare.health.domain.repository.AuthRepository
import javax.inject.Inject

/**
 * Use case for checking authentication session.
 * Encapsulates the business logic for validating active sessions.
 *
 * Single Responsibility: Handle session validation
 */
class CheckSessionUseCase @Inject constructor(
    private val authRepository: AuthRepository
) {
    /**
     * Check if there's an active session.
     * Validates the session with a timeout.
     * @return User if session is valid, null otherwise
     */
    suspend operator fun invoke(): User? {
        return authRepository.checkSession()
    }
}
