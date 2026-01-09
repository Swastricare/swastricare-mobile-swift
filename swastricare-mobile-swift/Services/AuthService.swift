//
//  AuthService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Handles all authentication interactions with Supabase
//

import Foundation
import Supabase

// MARK: - Auth Service Protocol

protocol AuthServiceProtocol {
    func checkSession() async throws -> AppUser?
    func signUp(email: String, password: String, fullName: String) async throws -> AppUser?
    func signIn(email: String, password: String) async throws -> AppUser
    func signInWithGoogle() async throws -> AppUser
    func signOut() async throws
    func resetPassword(email: String) async throws
    func deleteAccount() async throws
}

// MARK: - Auth Service Implementation

final class AuthService: AuthServiceProtocol {
    
    static let shared = AuthService()
    
    private let client: SupabaseClient
    
    private init() {
        self.client = SupabaseManager.shared.client
    }
    
    // MARK: - Check Session
    
    func checkSession() async throws -> AppUser? {
        // Use timeout to prevent blocking UI
        do {
            return try await withTimeout(seconds: 5) {
                do {
                    let session = try await self.client.auth.session
                    // Important: with newer SDK behavior, a locally stored session may be emitted
                    // even if it's expired. Never treat an expired session as authenticated.
                    guard !session.isExpired else { return nil }
                    return self.mapUser(session.user)
                } catch {
                    return nil
                }
            }
        } catch {
            // Timeout or other error - return nil silently
            return nil
        }
    }
    
    /// Helper to add timeout to async operations
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AuthError.networkError
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String, fullName: String) async throws -> AppUser? {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(fullName)]
        )
        
        // If session is nil, user needs to verify email
        guard response.session != nil else {
            return nil
        }
        
        return mapUser(response.user)
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws -> AppUser {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        return mapUser(session.user)
    }
    
    // MARK: - Sign In with Google
    
    func signInWithGoogle() async throws -> AppUser {
        let session = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "swastricareapp://auth-callback")
        )
        return mapUser(session.user)
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    // MARK: - Reset Password
    
    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async throws {
        // Sign out the user first, then the account deletion should be handled
        // by a Supabase Edge Function or database trigger for security
        // For now, we sign out and clear local data
        try await client.auth.signOut()
        
        // Clear all local user data
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "notificationsEnabled")
        defaults.removeObject(forKey: "biometricEnabled")
        defaults.removeObject(forKey: "healthSyncEnabled")
        defaults.synchronize()
    }
    
    // MARK: - Helpers
    
    private func mapUser(_ user: User) -> AppUser {
        var avatarURL: URL?
        var fullName: String?
        
        let metadata = user.userMetadata
        if let avatar = metadata["avatar_url"], case .string(let urlString) = avatar {
            avatarURL = URL(string: urlString)
        } else if let picture = metadata["picture"], case .string(let urlString) = picture {
            avatarURL = URL(string: urlString)
        }
        
        if let name = metadata["full_name"], case .string(let nameString) = name {
            fullName = nameString
        }
        
        return AppUser(
            id: user.id.uuidString,
            email: user.email,
            fullName: fullName,
            avatarURL: avatarURL,
            createdAt: user.createdAt
        )
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailNotVerified
    case networkError
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid email or password"
        case .emailNotVerified: return "Please verify your email first"
        case .networkError: return "Network connection failed"
        case .unknown(let message): return message
        }
    }
}

