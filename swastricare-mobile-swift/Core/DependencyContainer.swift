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
    let hydrationService: HydrationServiceProtocol
    let weatherService: WeatherServiceProtocol
    let vitalSignsService: VitalSignsServiceProtocol
    let runActivityService: RunActivityServiceProtocol
    let locationTrackingService: LocationTrackingServiceProtocol
    let workoutSessionManager: WorkoutSessionManagerProtocol
    let dietService: DietServiceProtocol
    let familyService: FamilyServiceProtocol
    
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
        ProfileViewModel(
            authService: authService,
            biometricService: biometricService,
            healthProfileService: HealthProfileService.shared
        )
    }()
    
    lazy var lockScreenViewModel: LockScreenViewModel = {
        LockScreenViewModel(biometricService: biometricService)
    }()
    
    lazy var hydrationViewModel: HydrationViewModel = {
        HydrationViewModel(
            hydrationService: hydrationService,
            healthKitService: healthService,
            weatherService: weatherService
        )
    }()
    
    lazy var medicationViewModel: MedicationViewModel = {
        MedicationViewModel()
    }()
    
    lazy var heartRateViewModel: HeartRateViewModel = {
        HeartRateViewModel(vitalSignsService: vitalSignsService)
    }()
    
    lazy var runActivityViewModel: RunActivityViewModel = {
        RunActivityViewModel(healthService: healthService, activityService: runActivityService)
    }()
    
    lazy var liveActivityViewModel: LiveActivityViewModel = {
        LiveActivityViewModel(
            workoutManager: workoutSessionManager,
            locationService: locationTrackingService
        )
    }()
    
    lazy var dietViewModel: DietViewModel = {
        DietViewModel(dietService: dietService)
    }()
    
    lazy var stepsViewModel: StepsViewModel = {
        StepsViewModel(stepsService: StepsService.shared, healthKitService: healthService)
    }()
    
    lazy var familyViewModel: FamilyViewModel = {
        FamilyViewModel(familyService: familyService)
    }()
    
    // MARK: - Init
    
    private init() {
        // Initialize services
        self.authService = AuthService.shared
        self.healthService = HealthKitService.shared
        self.vaultService = VaultService.shared
        self.aiService = AIService.shared
        self.biometricService = BiometricService.shared
        self.hydrationService = HydrationService.shared
        self.weatherService = WeatherService.shared
        self.vitalSignsService = VitalSignsService.shared
        self.runActivityService = RunActivityService.shared
        self.locationTrackingService = LocationTrackingService.shared
        self.workoutSessionManager = WorkoutSessionManager.shared
        self.dietService = DietService.shared
        self.familyService = FamilyService.shared
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
    
    func makeHydrationViewModel() -> HydrationViewModel {
        HydrationViewModel(
            hydrationService: hydrationService,
            healthKitService: healthService,
            weatherService: weatherService
        )
    }
    
    func makeMedicationViewModel() -> MedicationViewModel {
        MedicationViewModel()
    }
    
    func makeHeartRateViewModel() -> HeartRateViewModel {
        HeartRateViewModel(vitalSignsService: vitalSignsService)
    }
    
    func makeRunActivityViewModel() -> RunActivityViewModel {
        RunActivityViewModel(healthService: healthService, activityService: runActivityService)
    }
    
    func makeLiveActivityViewModel() -> LiveActivityViewModel {
        LiveActivityViewModel(
            workoutManager: workoutSessionManager,
            locationService: locationTrackingService
        )
    }
    
    func makeDietViewModel() -> DietViewModel {
        DietViewModel(dietService: dietService)
    }
    
    func makeStepsViewModel() -> StepsViewModel {
        StepsViewModel(stepsService: StepsService.shared, healthKitService: healthService)
    }
    
    func makeFamilyViewModel() -> FamilyViewModel {
        FamilyViewModel(familyService: familyService)
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

