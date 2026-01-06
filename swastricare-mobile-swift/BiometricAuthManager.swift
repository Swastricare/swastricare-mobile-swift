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
        
        // Auto-unlock on simulator (Face ID doesn't work on simulator)
        #if targetEnvironment(simulator)
        isLocked = false
        #endif
    }
    
    // MARK: - Check Biometric Availability
    func checkBiometricAvailability() {
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
        }
    }
    
    // MARK: - Authenticate
    func authenticate() async {
        // Skip authentication on simulator (Face ID doesn't work)
        #if targetEnvironment(simulator)
        await MainActor.run {
            self.isLocked = false
            self.errorMessage = "⚠️ Running on Simulator - Face ID bypassed"
        }
        return
        #endif
        
        // Create context on main thread
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        // First, try biometrics only (no passcode fallback button)
        var error: NSError?
        
        // Check if biometrics are available
        let canUseBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if canUseBiometrics {
            // Try biometric authentication first
            let reason = "Unlock Swastricare to access your health data"
            
            do {
                // Perform authentication (this should show Face ID prompt)
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                )
                
                if success {
                    await MainActor.run {
                        self.isLocked = false
                        self.errorMessage = nil
                    }
                }
                return
                
            } catch let laError as LAError {
                // Handle biometric-specific errors
                await MainActor.run {
                    switch laError.code {
                    case .userCancel, .appCancel, .systemCancel:
                        self.errorMessage = "Authentication cancelled. Tap to try again."
                        
                    case .biometryLockout:
                        self.errorMessage = "Too many failed attempts. Use passcode."
                        
                    case .biometryNotAvailable:
                        self.errorMessage = "Face ID not available"
                        
                    case .biometryNotEnrolled:
                        self.errorMessage = "Face ID not set up"
                        
                    default:
                        self.errorMessage = laError.localizedDescription
                    }
                }
                return
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                }
                return
            }
        }
        
        // If biometrics not available, try passcode
        let passcodeContext = LAContext()
        
        guard passcodeContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            await MainActor.run {
                self.errorMessage = "No authentication available"
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
            
            if success {
                await MainActor.run {
                    self.isLocked = false
                    self.errorMessage = nil
                }
            }
        } catch let laError as LAError {
            await MainActor.run {
                switch laError.code {
                case .userCancel, .appCancel, .systemCancel:
                    self.errorMessage = "Authentication cancelled"
                default:
                    self.errorMessage = laError.localizedDescription
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
