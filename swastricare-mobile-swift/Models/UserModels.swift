//
//  UserModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//

import Foundation

// MARK: - App User Model (wraps Supabase User)

struct AppUser: Identifiable, Equatable {
    let id: String
    let email: String?
    let fullName: String?
    let avatarURL: URL?
    let createdAt: Date?
    
    init(id: String, email: String?, fullName: String? = nil, avatarURL: URL? = nil, createdAt: Date? = nil) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }
}

// MARK: - Authentication State

enum AuthState: Equatable {
    case unknown
    case authenticated(AppUser)
    case unauthenticated
    
    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
    
    var user: AppUser? {
        if case .authenticated(let user) = self { return user }
        return nil
    }
}

// MARK: - Auth Form State

struct AuthFormState: Equatable {
    var email: String = ""
    var password: String = ""
    var fullName: String = ""
    var confirmPassword: String = ""
    
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    var isValidPassword: Bool {
        password.count >= 6
    }
    
    var passwordsMatch: Bool {
        password == confirmPassword
    }
    
    var isValidForLogin: Bool {
        isValidEmail && isValidPassword
    }
    
    var isValidForSignUp: Bool {
        isValidEmail && isValidPassword && passwordsMatch && !fullName.isEmpty
    }
}

// MARK: - Biometric State

enum BiometricState: Equatable {
    case locked
    case unlocked
    case authenticating
    case failed(String)
}

