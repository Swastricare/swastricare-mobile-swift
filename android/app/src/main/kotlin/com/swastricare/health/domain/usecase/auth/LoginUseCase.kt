package com.swastricare.health.domain.usecase.auth

import com.swastricare.health.domain.model.AuthCredentials
import com.swastricare.health.domain.model.User
import com.swastricare.health.domain.repository.AuthRepository
import javax.inject.Inject

/**
 * Use case for user login with email and password.
 * Encapsulates the business logic for authentication.
 *
 * Single Responsibility: Handle email/password login flow
 */
class LoginUseCase @Inject constructor(
    private val authRepository: AuthRepository
) {
    /**
     * Execute login operation.
     * @param email User's email address
     * @param password User's password
     * @return Authenticated User
     * @throws Exception if login fails
     */
    suspend operator fun invoke(email: String, password: String): User {
        return authRepository.signIn(
            AuthCredentials(email = email, password = password)
        )
    }
}
