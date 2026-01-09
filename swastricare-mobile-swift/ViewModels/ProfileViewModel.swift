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
    @Published private(set) var healthProfile: HealthProfile?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingHealthProfile = false
    @Published private(set) var errorMessage: String?
    @Published var showSignOutConfirmation = false
    @Published var showDeleteAccountConfirmation = false
    
    // Settings
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published private(set) var biometricEnabled: Bool
    @Published private(set) var isTogglingBiometric = false
    @Published var healthSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(healthSyncEnabled, forKey: "healthSyncEnabled") }
    }
    
    // MARK: - Computed Properties
    
    var userName: String {
        healthProfile?.name ?? user?.fullName ?? user?.email?.components(separatedBy: "@").first ?? "User"
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
    
    // Health Profile Computed Properties
    var profileName: String {
        healthProfile?.name ?? "Not set"
    }
    
    var profileGender: String {
        healthProfile?.gender.displayName ?? "Not set"
    }
    
    var profileAge: String {
        guard let dob = healthProfile?.dateOfBirth else { return "Not set" }
        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
        return "\(age) years"
    }
    
    var profileDateOfBirth: String {
        guard let dob = healthProfile?.dateOfBirth else { return "Not set" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dob)
    }
    
    var profileHeight: String {
        guard let profile = healthProfile else { return "Not set" }
        if profile.heightUnit == .cm {
            return String(format: "%.0f cm", profile.height)
        } else {
            let totalInches = profile.height / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(feet)' \(inches)\""
        }
    }
    
    var profileWeight: String {
        guard let profile = healthProfile else { return "Not set" }
        return String(format: "%.1f %@", profile.weight, profile.weightUnit.displayName)
    }
    
    var profileBMI: String {
        guard let profile = healthProfile else { return "Not set" }
        let heightInMeters = profile.height / 100
        var weightInKg = profile.weight
        if profile.weightUnit == .lbs {
            weightInKg = profile.weight / 2.205
        }
        let bmi = weightInKg / (heightInMeters * heightInMeters)
        return String(format: "%.1f", bmi)
    }
    
    var profileExerciseLevel: String {
        healthProfile?.exerciseLevel.displayName ?? "Not set"
    }
    
    var profileFoodIntakeLevel: String {
        healthProfile?.foodIntakeLevel.displayName ?? "Not set"
    }
    
    var profileBloodType: String {
        healthProfile?.bloodType ?? "Not set"
    }
    
    var profileAllergies: [String] {
        healthProfile?.allergies ?? []
    }
    
    var profileChronicConditions: [String] {
        healthProfile?.chronicConditions ?? []
    }
    
    var profileMedications: [String] {
        healthProfile?.medications ?? []
    }
    
    var hasHealthProfile: Bool {
        healthProfile != nil
    }
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let biometricService: BiometricServiceProtocol
    private let healthProfileService: HealthProfileServiceProtocol
    
    // MARK: - Init
    
    init(
        authService: AuthServiceProtocol = AuthService.shared,
        biometricService: BiometricServiceProtocol = BiometricService.shared,
        healthProfileService: HealthProfileServiceProtocol = HealthProfileService.shared
    ) {
        self.authService = authService
        self.biometricService = biometricService
        self.healthProfileService = healthProfileService
        
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
            
            // Also fetch health profile
            await loadHealthProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadHealthProfile() async {
        isLoadingHealthProfile = true
        defer { isLoadingHealthProfile = false }
        
        do {
            print("📋 ProfileVM: Starting to fetch health profile...")
            let profile = try await healthProfileService.fetchHealthProfile()
            healthProfile = profile
            if let profile = profile {
                print("📋 ProfileVM: ✅ Loaded health profile successfully:")
                print("   - Name: \(profile.name)")
                print("   - Gender: \(profile.gender.displayName)")
                print("   - DOB: \(profile.dateOfBirth)")
                print("   - Height: \(profile.height) \(profile.heightUnit.displayName)")
                print("   - Weight: \(profile.weight) \(profile.weightUnit.displayName)")
            } else {
                print("📋 ProfileVM: ⚠️ No health profile found for user")
            }
        } catch {
            print("❌ ProfileVM: Failed to load health profile:")
            print("   Error: \(error)")
            print("   Localized: \(error.localizedDescription)")
            // Don't show error to user - health profile might not exist yet
        }
    }
    
    func refreshHealthProfile() async {
        await loadHealthProfile()
    }
    
    func signOut() async {
        isLoading = true
        
        // Use AuthViewModel's signOut to properly update auth state and trigger navigation
        await DependencyContainer.shared.authViewModel.signOut()
        user = nil
        
        isLoading = false
    }
    
    func deleteAccount() async {
        isLoading = true
        
        do {
            try await authService.deleteAccount()
            user = nil
            // Update auth state to trigger navigation back to auth screen
            await DependencyContainer.shared.authViewModel.signOut()
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Toggle biometric authentication setting
    /// This method performs biometric verification BEFORE changing the setting
    func toggleBiometric() async {
        // Prevent concurrent toggles
        guard !isTogglingBiometric else { return }
        
        isTogglingBiometric = true
        defer { isTogglingBiometric = false }
        
        let currentlyEnabled = biometricEnabled
        
        if currentlyEnabled {
            // Disabling biometrics - no verification needed (user can disable freely)
            biometricEnabled = false
            UserDefaults.standard.set(false, forKey: "biometricEnabled")
            print("🔐 Biometric disabled by user")
        } else {
            // Enabling biometrics - must verify first
            guard biometricService.isBiometricAvailable else {
                errorMessage = "\(biometricService.biometricType.displayName) is not available on this device"
                return
            }
            
            do {
                let success = try await biometricService.authenticate(
                    reason: "Verify your identity to enable \(biometricService.biometricType.displayName)"
                )
                
                if success {
                    // Only enable after successful authentication
                    biometricEnabled = true
                    UserDefaults.standard.set(true, forKey: "biometricEnabled")
                    print("🔐 Biometric enabled successfully")
                } else {
                    // Authentication returned false (shouldn't happen normally)
                    errorMessage = "Authentication was not successful"
                }
            } catch let error as BiometricError {
                // Handle specific biometric errors
                switch error {
                case .cancelled:
                    // User cancelled - don't show error
                    print("🔐 Biometric authentication cancelled by user")
                case .notAvailable:
                    errorMessage = "\(biometricService.biometricType.displayName) is not available"
                case .notEnrolled:
                    errorMessage = "No \(biometricService.biometricType.displayName) enrolled. Please set it up in Settings."
                case .lockout:
                    errorMessage = "Too many failed attempts. Please try again later."
                default:
                    errorMessage = error.localizedDescription
                }
            } catch {
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

