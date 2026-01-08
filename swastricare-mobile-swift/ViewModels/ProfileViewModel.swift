//
//  ProfileViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//

import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var user: AppUser?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var showSignOutConfirmation = false
    
    // Settings
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var biometricEnabled: Bool {
        didSet { UserDefaults.standard.set(biometricEnabled, forKey: "biometricEnabled") }
    }
    @Published var healthSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(healthSyncEnabled, forKey: "healthSyncEnabled") }
    }
    
    // MARK: - Computed Properties
    
    var userName: String {
        user?.fullName ?? user?.email?.components(separatedBy: "@").first ?? "User"
    }
    
    var userEmail: String {
        user?.email ?? ""
    }
    
    var userAvatarURL: URL? {
        user?.avatarURL
    }
    
    var memberSince: String {
        guard let date = user?.createdAt else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let biometricService: BiometricServiceProtocol
    
    // MARK: - Init
    
    init(
        authService: AuthServiceProtocol = AuthService.shared,
        biometricService: BiometricServiceProtocol = BiometricService.shared
    ) {
        self.authService = authService
        self.biometricService = biometricService
        
        // Load settings from UserDefaults
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        self.biometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled")
        self.healthSyncEnabled = UserDefaults.standard.bool(forKey: "healthSyncEnabled")
        
        // Don't load user here - let the view trigger it
    }
    
    // MARK: - Actions
    
    func loadUser() async {
        // Run on a background task to avoid blocking the main thread (prevents gesture timeouts)
        let service = authService
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedUser = try await Task.detached(priority: .utility) {
                try await service.checkSession()
            }.value
            
            // Update on main actor (class is @MainActor)
            user = fetchedUser
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func signOut() async {
        isLoading = true
        
        // Use AuthViewModel's signOut to properly update auth state and trigger navigation
        await DependencyContainer.shared.authViewModel.signOut()
        user = nil
        
        isLoading = false
    }
    
    func toggleBiometric() async {
        guard biometricService.isBiometricAvailable else {
            errorMessage = "Biometric authentication is not available"
            biometricEnabled = false
            return
        }
        
        if biometricEnabled {
            // Verify with biometric before enabling
            do {
                let success = try await biometricService.authenticate(
                    reason: "Verify your identity to enable \(biometricService.biometricType.displayName)"
                )
                if !success {
                    biometricEnabled = false
                }
            } catch {
                biometricEnabled = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
    }
    
    var biometricTypeName: String {
        biometricService.biometricType.displayName
    }
    
    var biometricIcon: String {
        biometricService.biometricType.iconName
    }
}

