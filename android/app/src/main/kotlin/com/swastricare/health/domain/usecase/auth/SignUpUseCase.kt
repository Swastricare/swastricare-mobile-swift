package com.swastricare.health.domain.usecase.auth

import com.swastricare.health.domain.model.SignUpData
import com.swastricare.health.domain.model.SignUpResult
import com.swastricare.health.domain.repository.AuthRepository
import javax.inject.Inject

/**
 * Use case for user registration.
 * Encapsulates the business logic for creating new user accounts.
 *
 * Single Responsibility: Handle user sign-up flow
 */
class SignUpUseCase @Inject constructor(
    private val authRepository: AuthRepository
) {
    /**
     * Execute sign-up operation.
     * @param email User's email address
     * @param password User's password
     * @param fullName User's full name
     * @param phone Optional phone number
     * @return SignUpResult indicating success or email verification required
     * @throws Exception if sign-up fails
     */
    suspend operator fun invoke(
        email: String,
        password: String,
        fullName: String,
        phone: String = ""
    ): SignUpResult {
        return authRepository.signUp(
            SignUpData(
                email = email,
                password = password,
                fullName = fullName,
                phone = phone
            )
        )
    }
}
