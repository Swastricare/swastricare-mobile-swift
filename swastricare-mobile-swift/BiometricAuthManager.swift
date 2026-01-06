//
//  BiometricAuthManager.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import Foundation
import LocalAuthentication
import SwiftUI
import Combine

@MainActor
class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    @Published var isLocked = true
    @Published var biometricType: LABiometryType = .none
    @Published var errorMessage: String?
    
    private let context = LAContext()
    
    private init() {
        checkBiometricAvailability()
    }
    
    // MARK: - Check Biometric Availability
    func checkBiometricAvailability() {
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
            print("Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    // MARK: - Authenticate
    func authenticate() async {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        // First, try biometrics only (no passcode fallback button)
        var error: NSError?
        
        // Check if biometrics are available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // Try biometric authentication first
            let reason = "Unlock Swastricare to access your health data"
            
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                )
                
                await MainActor.run {
                    if success {
                        self.isLocked = false
                        self.errorMessage = nil
                    }
                }
                return
            } catch let error as LAError {
                // Handle biometric-specific errors
                switch error.code {
                case .userCancel, .appCancel, .systemCancel:
                    await MainActor.run {
                        self.errorMessage = "Authentication cancelled"
                    }
                    return
                    
                case .biometryLockout:
                    // Too many failed attempts - fall through to passcode
                    break
                    
                case .userFallback:
                    // User explicitly chose to use passcode - fall through
                    break
                    
                default:
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
            }
        }
        
        // If biometrics failed or not available, offer passcode as fallback
        let passcodeContext = LAContext()
        passcodeContext.localizedCancelTitle = "Cancel"
        
        guard passcodeContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            await MainActor.run {
                self.errorMessage = error?.localizedDescription ?? "Authentication not available"
                // If no authentication available at all, unlock (device is not secured)
                self.isLocked = false
            }
            return
        }
        
        let reason = "Enter your device passcode to unlock"
        
        do {
            let success = try await passcodeContext.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            await MainActor.run {
                if success {
                    self.isLocked = false
                    self.errorMessage = nil
                } else {
                    self.errorMessage = "Authentication failed"
                }
            }
        } catch let error as LAError {
            await MainActor.run {
                switch error.code {
                case .userCancel, .appCancel, .systemCancel:
                    self.errorMessage = "Authentication cancelled"
                default:
                    self.errorMessage = error.localizedDescription
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Lock App
    func lock() {
        isLocked = true
        errorMessage = nil
    }
    
    // MARK: - Get Biometric Icon Name
    var biometricIconName: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.fill"
        }
    }
    
    // MARK: - Get Biometric Display Name
    var biometricDisplayName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Passcode"
        }
    }
}
