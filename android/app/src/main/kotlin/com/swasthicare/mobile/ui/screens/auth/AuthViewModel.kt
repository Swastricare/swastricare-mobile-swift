package com.swasthicare.mobile.ui.screens.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swasthicare.mobile.data.helpers.GoogleAuthHelper
import com.swasthicare.mobile.data.repository.SupabaseAuthRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Authentication ViewModel
 * Manages authentication state and user interactions
 * Mirrors logic from Swift's AuthViewModel.swift
 */
class AuthViewModel(
    private val authRepository: SupabaseAuthRepository,
    private val googleAuthHelper: GoogleAuthHelper
) : ViewModel() {
    
    // UI State
    private val _uiState = MutableStateFlow<AuthUiState>(AuthUiState.Idle)
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()
    
    // Form State
    private val _formState = MutableStateFlow(AuthFormState())
    val formState: StateFlow<AuthFormState> = _formState.asStateFlow()
    
    // Error Message
    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()
    
    // Loading State
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    init {
        checkSession()
    }
    
    /**
     * Check if user has active session
     * Matches iOS checkAuthStatus()
     */
    private fun checkSession() {
        viewModelScope.launch {
            _uiState.value = AuthUiState.Loading
            try {
                val user = authRepository.checkSession()
                _uiState.value = if (user != null) {
                    AuthUiState.Success(user)
                } else {
                    AuthUiState.Idle
                }
            } catch (e: Exception) {
                _uiState.value = AuthUiState.Idle
            }
        }
    }
    
    /**
     * Sign in with email and password
     * Matches iOS signIn()
     */
    fun signIn() {
        if (!_formState.value.isValidForLogin) {
            _errorMessage.value = "Please enter valid email and password"
            return
        }
        
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            
            try {
                val user = authRepository.signIn(
                    email = _formState.value.email,
                    password = _formState.value.password
                )
                _uiState.value = AuthUiState.Success(user)
                clearForm()
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Sign in failed"
                _uiState.value = AuthUiState.Error(e.message ?: "Sign in failed")
            } finally {
                _isLoading.value = false
            }
        }
    }
    
    /**
     * Sign up with email, password, and full name
     * Matches iOS signUp()
     */
    fun signUp() {
        if (!_formState.value.isValidForSignUp) {
            _errorMessage.value = "Please fill in all fields correctly"
            return
        }
        
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            
            try {
                val user = authRepository.signUp(
                    email = _formState.value.email,
                    password = _formState.value.password,
                    fullName = _formState.value.fullName
                )
                
                if (user != null) {
                    _uiState.value = AuthUiState.Success(user)
                    clearForm()
                } else {
                    _errorMessage.value = "Please check your email to verify your account"
                }
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Sign up failed"
                _uiState.value = AuthUiState.Error(e.message ?: "Sign up failed")
            } finally {
                _isLoading.value = false
            }
        }
    }
    
    /**
     * Sign in with Google OAuth
     * Matches iOS signInWithGoogle()
     */
    fun signInWithGoogle() {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            
            try {
                // Get Google ID token using Credential Manager
                val idToken = googleAuthHelper.signIn()
                
                // Sign in with Supabase using the ID token
                val user = authRepository.signInWithGoogle(idToken)
                _uiState.value = AuthUiState.Success(user)
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Google sign-in failed"
                _uiState.value = AuthUiState.Error(e.message ?: "Google sign-in failed")
            } finally {
                _isLoading.value = false
            }
        }
    }
    
    /**
     * Reset password via email
     * Matches iOS resetPassword()
     */
    fun resetPassword() {
        if (!_formState.value.isValidEmail) {
            _errorMessage.value = "Please enter a valid email"
            return
        }
        
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            
            try {
                authRepository.resetPassword(_formState.value.email)
                _errorMessage.value = "Password reset link sent to your email"
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Failed to send reset link"
            } finally {
                _isLoading.value = false
            }
        }
    }
    
    /**
     * Sign out current user
     */
    fun signOut() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                authRepository.signOut()
                _uiState.value = AuthUiState.Idle
                clearForm()
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Sign out failed"
            } finally {
                _isLoading.value = false
            }
        }
    }
    
    // Form field updates
    fun updateEmail(email: String) {
        _formState.value = _formState.value.copy(email = email)
    }
    
    fun updatePassword(password: String) {
        _formState.value = _formState.value.copy(password = password)
    }
    
    fun updateFullName(fullName: String) {
        _formState.value = _formState.value.copy(fullName = fullName)
    }
    
    fun updateConfirmPassword(confirmPassword: String) {
        _formState.value = _formState.value.copy(confirmPassword = confirmPassword)
    }
    
    fun clearError() {
        _errorMessage.value = null
    }
    
    private fun clearForm() {
        _formState.value = AuthFormState()
    }
}
