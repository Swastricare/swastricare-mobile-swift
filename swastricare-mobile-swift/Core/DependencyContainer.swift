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

// MARK: - Steps (minimal implementation)

protocol StepsServiceProtocol {
    func fetchTodayStepCount(healthKitService: HealthKitServiceProtocol) async -> Int
}

final class StepsService: StepsServiceProtocol {
    static let shared = StepsService()
    private init() {}

    func fetchTodayStepCount(healthKitService: HealthKitServiceProtocol) async -> Int {
        await healthKitService.fetchStepCount(for: Date())
    }
}

@MainActor
final class StepsViewModel: ObservableObject {
    @Published private(set) var todaySteps: Int = 0
    @Published var dailyGoal: Int = 10_000
    @Published private(set) var isLoading: Bool = false

    private let stepsService: StepsServiceProtocol
    private let healthKitService: HealthKitServiceProtocol

    init(
        stepsService: StepsServiceProtocol = StepsService.shared,
        healthKitService: HealthKitServiceProtocol = HealthKitService.shared
    ) {
        self.stepsService = stepsService
        self.healthKitService = healthKitService
    }

    func refresh() async {
        isLoading = true
        let steps = await stepsService.fetchTodayStepCount(healthKitService: healthKitService)
        todaySteps = steps
        isLoading = false
    }
}

// MARK: - Family (minimal implementation)

struct FamilyMember: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var relationship: String
    var createdAt: Date = Date()
}

enum FamilyServiceError: Error {
    case invalidInviteCode
}

protocol FamilyServiceProtocol {
    func loadMembers() -> [FamilyMember]
    func addMember(_ member: FamilyMember)
    func removeMember(id: UUID)
    func joinFamily(inviteCode: String) async throws
    func createInviteCode() async -> String
}

final class FamilyService: FamilyServiceProtocol {
    static let shared = FamilyService()

    private let storageKey = "FamilyService.members"
    private let defaults = UserDefaults.standard

    private init() {}

    func loadMembers() -> [FamilyMember] {
        guard let data = defaults.data(forKey: storageKey),
              let members = try? JSONDecoder().decode([FamilyMember].self, from: data) else {
            return []
        }
        return members
    }

    func addMember(_ member: FamilyMember) {
        var members = loadMembers()
        members.append(member)
        persistMembers(members)
    }

    func removeMember(id: UUID) {
        let members = loadMembers().filter { $0.id != id }
        persistMembers(members)
    }

    func joinFamily(inviteCode: String) async throws {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { throw FamilyServiceError.invalidInviteCode }
        // Placeholder: real implementation should validate code via backend.
    }

    func createInviteCode() async -> String {
        // Placeholder: real implementation should request an invite code from backend.
        let code = String(Int.random(in: 100_000...999_999))
        return code
    }

    private func persistMembers(_ members: [FamilyMember]) {
        if let data = try? JSONEncoder().encode(members) {
            defaults.set(data, forKey: storageKey)
        }
    }
}

@MainActor
final class FamilyViewModel: ObservableObject {
    @Published private(set) var members: [FamilyMember] = []
    @Published var inviteCode: String = ""
    @Published private(set) var isJoining: Bool = false
    @Published private(set) var lastErrorMessage: String?

    private let familyService: FamilyServiceProtocol

    init(familyService: FamilyServiceProtocol = FamilyService.shared) {
        self.familyService = familyService
        self.members = familyService.loadMembers()
    }

    func reload() {
        members = familyService.loadMembers()
    }

    func addMember(name: String, relationship: String) {
        familyService.addMember(FamilyMember(name: name, relationship: relationship))
        reload()
    }

    func removeMember(id: UUID) {
        familyService.removeMember(id: id)
        reload()
    }

    func joinFamily() async {
        isJoining = true
        lastErrorMessage = nil
        do {
            try await familyService.joinFamily(inviteCode: inviteCode)
        } catch {
            lastErrorMessage = "Couldn’t join family. Please check the invite code and try again."
        }
        isJoining = false
    }
}
