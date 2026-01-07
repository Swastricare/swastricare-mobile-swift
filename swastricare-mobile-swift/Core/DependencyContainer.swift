//
//  DependencyContainer.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Dependency Injection Container
//

import Foundation
import SwiftUI
import Combine

// MARK: - Dependency Container

@MainActor
final class DependencyContainer: ObservableObject {
    
    // MARK: - Shared Instance
    
    static let shared = DependencyContainer()
    
    // MARK: - Services (Singletons)
    
    let authService: AuthServiceProtocol
    let healthService: HealthKitServiceProtocol
    let vaultService: VaultServiceProtocol
    let aiService: AIServiceProtocol
    let biometricService: BiometricServiceProtocol
    
    // MARK: - ViewModels (Lazy initialized)
    
    lazy var authViewModel: AuthViewModel = {
        AuthViewModel(authService: authService)
    }()
    
    lazy var homeViewModel: HomeViewModel = {
        HomeViewModel(healthService: healthService)
    }()
    
    lazy var trackerViewModel: TrackerViewModel = {
        TrackerViewModel(healthService: healthService)
    }()
    
    lazy var vaultViewModel: VaultViewModel = {
        VaultViewModel(vaultService: vaultService)
    }()
    
    lazy var aiViewModel: AIViewModel = {
        AIViewModel(aiService: aiService)
    }()
    
    lazy var profileViewModel: ProfileViewModel = {
        ProfileViewModel(authService: authService, biometricService: biometricService)
    }()
    
    lazy var lockScreenViewModel: LockScreenViewModel = {
        LockScreenViewModel(biometricService: biometricService)
    }()
    
    // MARK: - Init
    
    private init() {
        // Initialize services
        self.authService = AuthService.shared
        self.healthService = HealthKitService.shared
        self.vaultService = VaultService.shared
        self.aiService = AIService.shared
        self.biometricService = BiometricService.shared
    }
    
    // MARK: - Factory Methods (for creating new instances if needed)
    
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(healthService: healthService)
    }
    
    func makeTrackerViewModel() -> TrackerViewModel {
        TrackerViewModel(healthService: healthService)
    }
    
    func makeVaultViewModel() -> VaultViewModel {
        VaultViewModel(vaultService: vaultService)
    }
    
    func makeAIViewModel() -> AIViewModel {
        AIViewModel(aiService: aiService)
    }
}

// MARK: - Environment Key

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func withDependencies(_ container: DependencyContainer = .shared) -> some View {
        self.environment(\.dependencies, container)
    }
}

