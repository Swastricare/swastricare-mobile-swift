//
//  LockScreenViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//

import Foundation
import Combine

@MainActor
final class LockScreenViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var biometricState: BiometricState = .locked
    @Published private(set) var isLocked = true
    @Published private(set) var errorMessage: String?
    
    // MARK: - Computed Properties
    
    var biometricType: BiometricType {
        biometricService.biometricType
    }
    
    var biometricIcon: String {
        biometricType.iconName
    }
    
    var biometricName: String {
        biometricType.displayName
    }
    
    var isAuthenticating: Bool {
        biometricState == .authenticating
    }
    
    // MARK: - Dependencies
    
    private let biometricService: BiometricServiceProtocol
    
    // MARK: - Init
    
    init(biometricService: BiometricServiceProtocol = BiometricService.shared) {
        self.biometricService = biometricService
    }
    
    // MARK: - Actions
    
    func authenticate() async {
        guard biometricService.isBiometricAvailable else {
            // No biometric, just unlock
            unlock()
            return
        }
        
        biometricState = .authenticating
        
        do {
            let success = try await biometricService.authenticate(
                reason: "Unlock Swastricare to access your health data"
            )
            
            if success {
                unlock()
            } else {
                biometricState = .failed("Authentication failed")
            }
        } catch {
            biometricState = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
    
    func lock() {
        isLocked = true
        biometricState = .locked
        errorMessage = nil
    }
    
    func unlock() {
        isLocked = false
        biometricState = .unlocked
        errorMessage = nil
    }
    
    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
        if case .failed = biometricState {
            biometricState = .locked
        }
    }
}

