package com.swastricare.health.domain.usecase.auth

import com.swastricare.health.domain.repository.AuthRepository
import javax.inject.Inject

/**
 * Use case for user logout.
 * Encapsulates the business logic for signing out.
 *
 * Single Responsibility: Handle user logout flow
 */
class LogoutUseCase @Inject constructor(
    private val authRepository: AuthRepository
) {
    /**
     * Execute logout operation.
     * Signs out the current user and clears local data.
     * @throws Exception if logout fails
     */
    suspend operator fun invoke() {
        authRepository.signOut()
    }
}
