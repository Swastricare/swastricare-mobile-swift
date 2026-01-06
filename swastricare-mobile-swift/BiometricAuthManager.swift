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

// #region agent log helper
func logDebug(_ location: String, _ message: String, _ data: [String: Any] = [:], hypothesisId: String = "") {
    let logPath = "/Users/onwords/i do coding/swastricare-mobile-swift/.cursor/debug.log"
    var logData: [String: Any] = [
        "timestamp": Date().timeIntervalSince1970 * 1000,
        "location": location,
        "message": message,
        "sessionId": "debug-session",
        "data": data
    ]
    if !hypothesisId.isEmpty {
        logData["hypothesisId"] = hypothesisId
    }
    if let jsonData = try? JSONSerialization.data(withJSONObject: logData),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        if let fileHandle = FileHandle(forWritingAtPath: logPath) {
            fileHandle.seekToEndOfFile()
            if let data = (jsonString + "\n").data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            try? (jsonString + "\n").write(toFile: logPath, atomically: true, encoding: .utf8)
        }
    }
}
// #endregion

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
        print("🔐 BiometricAuth: Running on simulator - auto unlocking")
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
            print("Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    // MARK: - Authenticate
    func authenticate() async {
        // #region agent log
        logDebug("BiometricAuthManager:authenticate:entry", "Starting authentication", ["isLocked": isLocked], hypothesisId: "A,E")
        // #endregion
        
        print("🔐 BiometricAuth: Starting authentication...")
        
        // Skip authentication on simulator (Face ID doesn't work)
        #if targetEnvironment(simulator)
        print("🔐 BiometricAuth: Simulator detected - auto unlocking")
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
        
        // #region agent log
        logDebug("BiometricAuthManager:authenticate:beforeCheck", "About to check biometric availability", [:], hypothesisId: "D")
        // #endregion
        
        // Check if biometrics are available
        let canUseBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        // #region agent log
        logDebug("BiometricAuthManager:authenticate:afterCheck", "Checked biometric availability", ["canUseBiometrics": canUseBiometrics, "biometryType": context.biometryType.rawValue, "error": error?.localizedDescription ?? "none"], hypothesisId: "D")
        // #endregion
        
        print("🔐 BiometricAuth: Can use biometrics: \(canUseBiometrics)")
        
        if canUseBiometrics {
            print("🔐 BiometricAuth: Biometrics available - type: \(context.biometryType.rawValue)")
            // Try biometric authentication first
            let reason = "Unlock Swastricare to access your health data"
            
            do {
                print("🔐 BiometricAuth: Requesting biometric authentication...")
                
                // #region agent log
                logDebug("BiometricAuthManager:authenticate:beforeEvaluate", "About to call evaluatePolicy", ["thread": Thread.isMainThread ? "main" : "background"], hypothesisId: "A,C")
                // #endregion
                
                // Perform authentication (this should show Face ID prompt)
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                )
                
                // #region agent log
                logDebug("BiometricAuthManager:authenticate:afterEvaluate", "evaluatePolicy completed", ["success": success], hypothesisId: "A")
                // #endregion
                
                print("🔐 BiometricAuth: Biometric result: \(success)")
                
                if success {
                    // #region agent log
                    logDebug("BiometricAuthManager:authenticate:beforeUnlock", "About to unlock", ["isLocked": isLocked], hypothesisId: "B")
                    // #endregion
                    
                    await MainActor.run {
                        self.isLocked = false
                        self.errorMessage = nil
                        print("🔐 BiometricAuth: Unlocked!")
                        
                        // #region agent log
                        logDebug("BiometricAuthManager:authenticate:afterUnlock", "Unlocked state set", ["isLocked": self.isLocked], hypothesisId: "B")
                        // #endregion
                    }
                }
                return
                
            } catch let laError as LAError {
                // #region agent log
                logDebug("BiometricAuthManager:authenticate:error", "LAError caught", ["errorCode": laError.code.rawValue, "message": laError.localizedDescription], hypothesisId: "A,D")
                // #endregion
                
                print("🔐 BiometricAuth: LAError - code: \(laError.code.rawValue), message: \(laError.localizedDescription)")
                
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
                print("🔐 BiometricAuth: Unexpected error: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                }
                return
            }
        }
        
        // If biometrics not available, try passcode
        print("🔐 BiometricAuth: Biometrics NOT available - trying passcode")
        
        let passcodeContext = LAContext()
        
        guard passcodeContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            print("🔐 BiometricAuth: No authentication available at all - unlocking")
            await MainActor.run {
                self.errorMessage = "No authentication available"
                self.isLocked = false
            }
            return
        }
        
        let reason = "Enter your device passcode to unlock"
        
        do {
            print("🔐 BiometricAuth: Requesting passcode authentication...")
            let success = try await passcodeContext.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            print("🔐 BiometricAuth: Passcode result: \(success)")
            
            if success {
                await MainActor.run {
                    self.isLocked = false
                    self.errorMessage = nil
                    print("🔐 BiometricAuth: Unlocked via passcode!")
                }
            }
        } catch let laError as LAError {
            print("🔐 BiometricAuth: Passcode LAError - code: \(laError.code.rawValue)")
            await MainActor.run {
                switch laError.code {
                case .userCancel, .appCancel, .systemCancel:
                    self.errorMessage = "Authentication cancelled"
                default:
                    self.errorMessage = laError.localizedDescription
                }
            }
        } catch {
            print("🔐 BiometricAuth: Passcode unexpected error: \(error.localizedDescription)")
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
