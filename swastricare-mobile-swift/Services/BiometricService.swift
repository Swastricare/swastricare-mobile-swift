//
//  BiometricService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Handles biometric authentication (Face ID / Touch ID)
//

import Foundation
import LocalAuthentication

// MARK: - Biometric Service Protocol

protocol BiometricServiceProtocol {
    var biometricType: BiometricType { get }
    var isBiometricAvailable: Bool { get }
    func authenticate(reason: String) async throws -> Bool
}

// MARK: - Biometric Type

enum BiometricType {
    case none
    case touchID
    case faceID
    
    var displayName: String {
        switch self {
        case .none: return "Passcode"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        }
    }
    
    var iconName: String {
        switch self {
        case .none: return "lock.fill"
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        }
    }
}

// MARK: - Biometric Service Implementation

final class BiometricService: BiometricServiceProtocol {
    
    static let shared = BiometricService()
    
    private let context = LAContext()
    
    private init() {}
    
    // MARK: - Public Properties
    
    var biometricType: BiometricType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .touchID: return .touchID
        case .faceID: return .faceID
        default: return .none
        }
    }
    
    var isBiometricAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    // MARK: - Authentication
    
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext() // Create new context for each auth attempt
        context.localizedCancelTitle = "Cancel"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                throw BiometricError.from(error)
            }
            throw BiometricError.notAvailable
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch let authError as NSError {
            throw BiometricError.from(authError)
        }
    }
}

// MARK: - Biometric Errors

enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case lockout
    case cancelled
    case failed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Biometric authentication not available"
        case .notEnrolled: return "No biometric data enrolled"
        case .lockout: return "Too many failed attempts. Use passcode."
        case .cancelled: return "Authentication was cancelled"
        case .failed: return "Authentication failed"
        case .unknown(let message): return message
        }
    }
    
    static func from(_ error: NSError) -> BiometricError {
        switch error.code {
        case LAError.biometryNotAvailable.rawValue:
            return .notAvailable
        case LAError.biometryNotEnrolled.rawValue:
            return .notEnrolled
        case LAError.biometryLockout.rawValue:
            return .lockout
        case LAError.userCancel.rawValue, LAError.systemCancel.rawValue:
            return .cancelled
        case LAError.authenticationFailed.rawValue:
            return .failed
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

