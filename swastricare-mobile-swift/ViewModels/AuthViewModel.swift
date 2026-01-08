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
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var formState = AuthFormState()
    
    // MARK: - Computed Properties
    
    var isAuthenticated: Bool { authState.isAuthenticated }
    var currentUser: AppUser? { authState.user }
    var userEmail: String? { currentUser?.email }
    var userPhotoURL: URL? { currentUser?.avatarURL }
    var userName: String { currentUser?.fullName ?? currentUser?.email?.components(separatedBy: "@").first ?? "User" }
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    
    // MARK: - Init
    
    init(authService: AuthServiceProtocol = AuthService.shared) {
        self.authService = authService
        
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
            } else {
                authState = .unauthenticated
            }
        } catch {
            authState = .unauthenticated
        }
    }
    
    func signUp() async {
        guard formState.isValidForSignUp else {
            errorMessage = "Please fill all fields correctly"
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
                clearForm()
            } else {
                errorMessage = "Please check your email to verify your account"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signIn() async {
        guard formState.isValidForLogin else {
            errorMessage = "Please enter valid email and password"
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
            clearForm()
        } catch {
            errorMessage = error.localizedDescription
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
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signOut()
            authState = .unauthenticated
            clearForm()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func resetPassword() async {
        guard formState.isValidEmail else {
            errorMessage = "Please enter a valid email"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.resetPassword(email: formState.email)
            errorMessage = "Password reset email sent! Check your inbox."
        } catch {
            errorMessage = error.localizedDescription
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
}

