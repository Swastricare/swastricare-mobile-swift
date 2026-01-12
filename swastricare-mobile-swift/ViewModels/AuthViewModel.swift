//
//  AuthViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//

import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var authState: AuthState = .unknown
    @Published private(set) var healthProfile: HealthProfile?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var formState = AuthFormState()
    
    // MARK: - Computed Properties
    
    var isAuthenticated: Bool { authState.isAuthenticated }
    var currentUser: AppUser? { authState.user }
    var userEmail: String? { currentUser?.email }
    var userPhotoURL: URL? { currentUser?.avatarURL }
    var userName: String {
        healthProfile?.fullName ?? currentUser?.fullName ?? currentUser?.email?.components(separatedBy: "@").first ?? "User"
    }
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let healthProfileService: HealthProfileServiceProtocol
    
    // MARK: - Init
    
    init(
        authService: AuthServiceProtocol = AuthService.shared,
        healthProfileService: HealthProfileServiceProtocol = HealthProfileService.shared
    ) {
        self.authService = authService
        self.healthProfileService = healthProfileService
        
        Task {
            await checkAuthStatus()
        }
    }
    
    // MARK: - Auth Actions
    
    func checkAuthStatus() async {
        do {
            if let user = try await authService.checkSession() {
                authState = .authenticated(user)
                // Mark that user has logged in before (for onboarding logic)
                UserDefaults.standard.set(true, forKey: AppConfig.hasLoggedInBeforeKey)
                // Fetch health profile for user name
                await fetchHealthProfile()
            } else {
                authState = .unauthenticated
            }
        } catch {
            authState = .unauthenticated
        }
    }
    
    func fetchHealthProfile() async {
        do {
            healthProfile = try await healthProfileService.fetchHealthProfile()
        } catch {
            print("Failed to fetch health profile: \(error.localizedDescription)")
        }
    }
    
    func signUp() async {
        guard formState.isValidForSignUp else {
            errorMessage = "Please fill in all fields correctly."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if let user = try await authService.signUp(
                email: formState.email,
                password: formState.password,
                fullName: formState.fullName
            ) {
                authState = .authenticated(user)
                // Mark that user has logged in before (for onboarding logic)
                UserDefaults.standard.set(true, forKey: AppConfig.hasLoggedInBeforeKey)
                // Fetch health profile
                await fetchHealthProfile()
                clearForm()
            } else {
                errorMessage = "Please check your email to verify your account."
            }
        } catch {
            errorMessage = mapError(error)
        }
        
        isLoading = false
    }
    
    func signIn() async {
        guard formState.isValidForLogin else {
            errorMessage = "Please enter a valid email and password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signIn(
                email: formState.email,
                password: formState.password
            )
            authState = .authenticated(user)
            // Mark that user has logged in before (for onboarding logic)
            UserDefaults.standard.set(true, forKey: AppConfig.hasLoggedInBeforeKey)
            // Fetch health profile
            await fetchHealthProfile()
            clearForm()
        } catch {
            errorMessage = mapError(error)
        }
        
        isLoading = false
    }
    
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signInWithGoogle()
            authState = .authenticated(user)
            // Mark that user has logged in before (for onboarding logic)
            UserDefaults.standard.set(true, forKey: AppConfig.hasLoggedInBeforeKey)
            // Fetch health profile
            await fetchHealthProfile()
        } catch {
            errorMessage = mapError(error)
        }
        
        isLoading = false
    }
    
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signInWithApple()
            authState = .authenticated(user)
            // Mark that user has logged in before (for onboarding logic)
            UserDefaults.standard.set(true, forKey: AppConfig.hasLoggedInBeforeKey)
            // Fetch health profile
            await fetchHealthProfile()
        } catch {
            errorMessage = mapError(error)
        }
        
        isLoading = false
    }
    
    func signOut() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signOut()
            authState = .unauthenticated
            healthProfile = nil
            clearForm()
        } catch {
            errorMessage = mapError(error)
        }
        
        isLoading = false
    }
    
    func resetPassword() async {
        guard formState.isValidEmail else {
            errorMessage = "Please enter a valid email address."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.resetPassword(email: formState.email)
            errorMessage = "Password reset email sent! Check your inbox."
        } catch {
            errorMessage = mapError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
    }
    
    private func clearForm() {
        formState = AuthFormState()
    }
    
    /// Maps raw server errors to user-friendly messages
    private func mapError(_ error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("invalid login credentials") || errorString.contains("invalid_grant") {
            return "Incorrect email or password. Please try again."
        } else if errorString.contains("user already registered") || errorString.contains("user_already_exists") {
            return "An account with this email already exists."
        } else if errorString.contains("password should be at least") {
            return "Password is too short. It must be at least 6 characters."
        } else if errorString.contains("email not confirmed") {
            return "Please verify your email address before signing in."
        } else if errorString.contains("network") || errorString.contains("connection") || errorString.contains("offline") {
            return "Network error. Please check your internet connection."
        } else if errorString.contains("rate limit") || errorString.contains("too many requests") {
            return "Too many attempts. Please wait a moment and try again."
        } else if errorString.contains("invalid email") {
            return "Please enter a valid email address."
        }
        
        // Fallback for unknown errors (log actual error for debug, show generic for user)
        print("❌ Auth Error: \(error.localizedDescription)")
        return "Something went wrong. Please try again."
    }
}
