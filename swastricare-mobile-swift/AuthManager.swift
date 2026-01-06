//
//  AuthManager.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import Foundation
import Supabase
import Combine

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Computed property for easy access
    var userEmail: String? {
        currentUser?.email
    }
    
    var userPhotoURL: URL? {
        guard let metadata = currentUser?.userMetadata else { return nil }
        // Supabase typically returns JSON enum, access safely
        if let avatar = metadata["avatar_url"], case .string(let urlString) = avatar {
            return URL(string: urlString)
        }
        if let picture = metadata["picture"], case .string(let urlString) = picture {
            return URL(string: urlString)
        }
        return nil
    }
    
    private let client = SupabaseManager.shared.client
    
    private init() {
        // Check if user is already logged in
        Task {
            await checkAuthStatus()
        }
    }
    
    // MARK: - Check Auth Status
    func checkAuthStatus() async {
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
            self.isAuthenticated = true
        } catch {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
    
    // MARK: - Sign Up with Email
    func signUp(email: String, password: String, fullName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
            
            self.currentUser = response.user
            self.isAuthenticated = response.session != nil
            
            if response.session == nil {
                errorMessage = "Please check your email to verify your account"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Sign In with Email
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            self.currentUser = session.user
            self.isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    func signOut() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await client.auth.signOut()
            self.currentUser = nil
            self.isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Sign In with Google
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "swastricareapp://auth-callback")
            )
            
            self.currentUser = session.user
            self.isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Reset Password
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await client.auth.resetPasswordForEmail(email)
            errorMessage = "Password reset email sent! Check your inbox."
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
