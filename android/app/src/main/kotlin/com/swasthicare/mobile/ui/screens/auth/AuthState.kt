package com.swasthicare.mobile.ui.screens.auth

import com.swasthicare.mobile.data.model.AppUser

/**
 * Authentication UI State
 * Represents the current state of authentication in the app
 * Matches iOS AuthState enum
 */
sealed class AuthUiState {
    data object Idle : AuthUiState()
    data object Loading : AuthUiState()
    data class Success(val user: AppUser) : AuthUiState()
    data class Error(val message: String) : AuthUiState()
}

/**
 * Form State for Login and Sign Up
 * Manages form input and validation
 * Matches iOS AuthFormState
 */
data class AuthFormState(
    val email: String = "",
    val password: String = "",
    val fullName: String = "",
    val confirmPassword: String = "",
) {
    val isValidEmail: Boolean
        get() = email.isNotEmpty() && email.contains("@") && email.contains(".")
    
    val isValidPassword: Boolean
        get() = password.length >= 6
    
    val passwordsMatch: Boolean
        get() = password == confirmPassword && password.isNotEmpty()
    
    val isValidForLogin: Boolean
        get() = isValidEmail && isValidPassword
    
    val isValidForSignUp: Boolean
        get() = isValidEmail && isValidPassword && passwordsMatch && fullName.isNotEmpty()
}
