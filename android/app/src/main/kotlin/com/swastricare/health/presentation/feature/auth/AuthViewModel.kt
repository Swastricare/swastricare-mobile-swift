package com.swastricare.health.presentation.feature.auth

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.helpers.GoogleSignInCancelledException
import com.swastricare.health.data.helpers.GoogleSignInException
import com.swastricare.health.data.helpers.GoogleSignInNotConfiguredException
import com.swastricare.health.data.helpers.NoGoogleAccountException
import com.swastricare.health.data.mapper.AuthMapper
import com.swastricare.health.data.model.AppUser
import com.swastricare.health.data.services.AnalyticsService
import com.swastricare.health.data.services.CrashlyticsService
import com.swastricare.health.domain.model.SignUpResult
import com.swastricare.health.domain.usecase.auth.CheckSessionUseCase
import com.swastricare.health.domain.usecase.auth.GoogleSignInUseCase
import com.swastricare.health.domain.usecase.auth.LoginUseCase
import com.swastricare.health.domain.usecase.auth.LogoutUseCase
import com.swastricare.health.domain.usecase.auth.ResendVerificationEmailUseCase
import com.swastricare.health.domain.usecase.auth.ResetPasswordUseCase
import com.swastricare.health.domain.usecase.auth.SignUpUseCase
import com.swastricare.health.domain.usecase.auth.VerifyEmailOtpUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Authentication ViewModel with Clean Architecture and Hilt integration.
 * Manages authentication state and delegates business logic to use cases.
 *
 * Responsibilities:
 * - Manage UI state
 * - Coordinate use cases
 * - Handle user interactions
 * - Map domain models to UI models
 *
 * Business logic is delegated to use cases in the domain layer.
 */
@HiltViewModel
class AuthViewModel @Inject constructor(
    private val loginUseCase: LoginUseCase,
    private val signUpUseCase: SignUpUseCase,
    private val logoutUseCase: LogoutUseCase,
    private val googleSignInUseCase: GoogleSignInUseCase,
    private val verifyEmailOtpUseCase: VerifyEmailOtpUseCase,
    private val resendVerificationEmailUseCase: ResendVerificationEmailUseCase,
    private val resetPasswordUseCase: ResetPasswordUseCase,
    private val checkSessionUseCase: CheckSessionUseCase,
    private val analyticsService: AnalyticsService,
    private val crashlyticsService: CrashlyticsService
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

    // Verification Email (set when signup requires email confirmation)
    private val _verificationEmail = MutableStateFlow("")
    val verificationEmail: StateFlow<String> = _verificationEmail.asStateFlow()

    // Whether Google Sign-In is available
    val isGoogleSignInConfigured: Boolean
        get() = googleSignInUseCase.isConfigured

    init {
        checkSession()
    }

    /**
     * Check if user has active session.
     * Matches iOS checkAuthStatus().
     */
    private fun checkSession() {
        viewModelScope.launch {
            _uiState.value = AuthUiState.Loading
            try {
                val user = checkSessionUseCase()
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
     * Sign in with email and password.
     * Matches iOS signIn().
     */
    fun signIn() {
        if (!_formState.value.isValidForLogin) {
            _errorMessage.value = "Please enter valid email and password"
            return
        }

        checkRateLimit()?.let { msg ->
            _errorMessage.value = msg
            return
        }

        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                val user = loginUseCase(
                    email = _formState.value.email,
                    password = _formState.value.password
                )
                resetRateLimit()
                analyticsService.logEvent("sign_in", mapOf("method" to "email"))
                analyticsService.setUserId(user.id)
                crashlyticsService.setUserId(user.id)
                _uiState.value = AuthUiState.Success(user)
                clearForm()
            } catch (e: Exception) {
                recordFailedAttempt()
                val friendlyMessage = mapAuthError(e)
                _errorMessage.value = friendlyMessage
                _uiState.value = AuthUiState.Error(friendlyMessage)
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Sign up with email, password, and full name.
     * Matches iOS signUp().
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
                val result = signUpUseCase(
                    email = _formState.value.email,
                    password = _formState.value.password,
                    fullName = _formState.value.fullName,
                    phone = _formState.value.phone
                )

                when (result) {
                    is SignUpResult.Success -> {
                        analyticsService.logEvent("sign_up", mapOf("method" to "email"))
                        analyticsService.setUserId(result.user.id)
                        crashlyticsService.setUserId(result.user.id)
                        _uiState.value = AuthUiState.Success(result.user)
                        clearForm()
                    }
                    is SignUpResult.EmailVerificationRequired -> {
                        _verificationEmail.value = result.email
                        _uiState.value = AuthUiState.EmailVerificationRequired(result.email)
                    }
                }
            } catch (e: Exception) {
                val friendlyMessage = mapAuthError(e)
                _errorMessage.value = friendlyMessage
                _uiState.value = AuthUiState.Error(friendlyMessage)
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Sign in with Google OAuth.
     * Matches iOS signInWithGoogle().
     * Handles specific error types for better UX.
     */
    fun signInWithGoogle(activityContext: Context) {
        if (!googleSignInUseCase.isConfigured) {
            _errorMessage.value = "Google Sign-In is not configured yet"
            return
        }

        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                val user = googleSignInUseCase(activityContext)
                analyticsService.logEvent("sign_in", mapOf("method" to "google"))
                analyticsService.setUserId(user.id)
                crashlyticsService.setUserId(user.id)
                _uiState.value = AuthUiState.Success(user)
            } catch (e: GoogleSignInCancelledException) {
                Log.w("GoogleAuth", "Cancelled by user", e)
                _isLoading.value = false
                return@launch
            } catch (e: GoogleSignInNotConfiguredException) {
                Log.e("GoogleAuth", "Not configured", e)
                _errorMessage.value = "Google Sign-In is not configured"
                _uiState.value = AuthUiState.Error("Google Sign-In is not configured")
            } catch (e: NoGoogleAccountException) {
                Log.e("GoogleAuth", "No accounts found", e)
                _errorMessage.value = "No Google accounts found on this device"
                _uiState.value = AuthUiState.Error("No Google accounts found")
            } catch (e: GoogleSignInException) {
                Log.e("GoogleAuth", "GoogleSignInException: ${e.message}", e)
                _errorMessage.value = e.message ?: "Google sign-in failed"
                _uiState.value = AuthUiState.Error(e.message ?: "Google sign-in failed")
            } catch (e: Exception) {
                Log.e("GoogleAuth", "Unexpected: ${e.javaClass.simpleName}: ${e.message}", e)
                _errorMessage.value = e.message ?: "Google sign-in failed"
                _uiState.value = AuthUiState.Error(e.message ?: "Google sign-in failed")
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Verify email with OTP token sent to the user's inbox after signup.
     */
    fun verifyEmailOtp(token: String) {
        val email = _verificationEmail.value
        if (email.isBlank() || token.length != 6) {
            _errorMessage.value = "Please enter a valid 6-digit code"
            return
        }

        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                val user = verifyEmailOtpUseCase(email, token)
                analyticsService.logEvent("email_verified", mapOf("method" to "otp"))
                analyticsService.setUserId(user.id)
                crashlyticsService.setUserId(user.id)
                _uiState.value = AuthUiState.Success(user)
                clearForm()
            } catch (e: Exception) {
                val msg = when {
                    e.message?.lowercase()?.contains("token") == true ||
                            e.message?.lowercase()?.contains("otp") == true -> "Invalid or expired verification code"
                    e.message?.lowercase()?.contains("expired") == true -> "Verification code has expired. Please request a new one"
                    else -> "Verification failed. Please try again"
                }
                _errorMessage.value = msg
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Resend verification email to the address stored during signup.
     */
    fun resendVerificationEmail() {
        val email = _verificationEmail.value
        if (email.isBlank()) return

        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            try {
                resendVerificationEmailUseCase(email)
                _errorMessage.value = "Verification email sent to $email"
            } catch (e: Exception) {
                _errorMessage.value = when {
                    e.message?.lowercase()?.contains("rate") == true -> "Please wait before requesting another email"
                    else -> "Failed to resend email. Please try again"
                }
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Reset password via email.
     * Matches iOS resetPassword().
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
                resetPasswordUseCase(_formState.value.email)
                _errorMessage.value = "Password reset link sent to your email"
            } catch (e: Exception) {
                _errorMessage.value = mapAuthError(e)
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Sign out current user.
     */
    fun signOut() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                logoutUseCase()
                analyticsService.logEvent("sign_out")
                _uiState.value = AuthUiState.Idle
                clearForm()
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Sign out failed"
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Called when Supabase processes an auth deep link (email verification link clicked).
     * Re-checks the session and transitions to Success if a valid session now exists.
     */
    fun onAuthCallback() {
        viewModelScope.launch {
            try {
                val user = checkSessionUseCase()
                if (user != null) {
                    analyticsService.logEvent("email_verified", mapOf("method" to "link"))
                    analyticsService.setUserId(user.id)
                    crashlyticsService.setUserId(user.id)
                    _uiState.value = AuthUiState.Success(user)
                    clearForm()
                }
            } catch (e: Exception) {
                Log.w("AuthViewModel", "Auth callback session check failed", e)
            }
        }
    }

    /**
     * Called when the Supabase session expires (refresh token invalid).
     * Resets auth state to Idle so the UI navigates to the login screen.
     * Unlike [signOut], this does NOT call the Supabase sign-out endpoint
     * because the session is already invalid.
     */
    fun onSessionExpired() {
        Log.w("AuthViewModel", "Session expired — forcing sign out")
        _uiState.value = AuthUiState.Idle
        clearForm()
        analyticsService.logEvent("session_expired")
    }

    // ── Form Field Updates ──

    fun updateEmail(email: String) {
        _formState.value = _formState.value.copy(email = email)
    }

    fun updatePassword(password: String) {
        _formState.value = _formState.value.copy(password = password)
    }

    fun updateFullName(fullName: String) {
        _formState.value = _formState.value.copy(fullName = fullName)
    }

    fun updatePhone(phone: String) {
        _formState.value = _formState.value.copy(phone = phone)
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

    // ── Rate Limiting ──

    private var failedAttempts = 0
    private var lockoutUntil = 0L

    private fun checkRateLimit(): String? {
        val now = System.currentTimeMillis()
        if (now < lockoutUntil) {
            val remaining = ((lockoutUntil - now) / 1000).toInt()
            return "Too many failed attempts. Please wait ${remaining}s"
        }
        return null
    }

    private fun recordFailedAttempt() {
        failedAttempts++
        lockoutUntil = System.currentTimeMillis() + when {
            failedAttempts >= 10 -> 5 * 60 * 1000L  // 5 minutes
            failedAttempts >= 5 -> 30 * 1000L        // 30 seconds
            else -> 0L
        }
    }

    private fun resetRateLimit() {
        failedAttempts = 0
        lockoutUntil = 0L
    }

    /**
     * Map raw exception messages to user-friendly error strings.
     * Matches iOS AuthViewModel error mapping.
     */
    private fun mapAuthError(e: Exception): String {
        val message = e.message?.lowercase() ?: return "Something went wrong. Please try again."
        return when {
            "invalid login credentials" in message ||
                    "invalid_credentials" in message -> "Invalid email or password"
            "email not confirmed" in message -> "Please verify your email before signing in"
            "user already registered" in message ||
                    "already been registered" in message -> "Unable to complete sign up. Please try signing in instead."
            "rate limit" in message || "too many requests" in message ->
                "Too many attempts. Please try again later"
            "network" in message || "timeout" in message ||
                    "unable to resolve host" in message -> "Network connection failed. Please check your internet"
            "weak password" in message || "password" in message && "short" in message ->
                "Password must be at least 8 characters with uppercase, lowercase, and a number"
            else -> "Something went wrong. Please try again."
        }
    }

    /**
     * Get current user as AppUser for backward compatibility.
     * TODO: Remove once all code migrates to domain User model.
     */
    fun getCurrentUserAsAppUser(): AppUser? {
        return when (val state = _uiState.value) {
            is AuthUiState.Success -> AuthMapper.mapToAppUser(state.user)
            else -> null
        }
    }
}
