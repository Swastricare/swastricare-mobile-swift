//
//  OneQuestionOnboardingViewModel.swift
//  swastricare-mobile-swift
//
//  One Question Per Screen Onboarding ViewModel
//

import Foundation
import Combine
import CoreLocation
import Supabase
import Auth

// MARK: - Onboarding Question Enum

enum OnboardingQuestion: Int, CaseIterable {
    case fullName = 0
    case gender = 1
    case dateOfBirth = 2
    case height = 3
    case weight = 4
    case primaryGoal = 5
    case activityLevel = 6
    case waterIntake = 7
    
    var title: String {
        switch self {
        case .fullName: return "What's your name?"
        case .gender: return "Which gender do you identify with?"
        case .dateOfBirth: return "What's your date of birth?"
        case .height: return "How tall are you?"
        case .weight: return "What is your weight?"
        case .primaryGoal: return "What's your primary health goal?"
        case .activityLevel: return "What's your activity level?"
        case .waterIntake: return "How much water do you drink daily?"
        }
    }
    
    var subtitle: String {
        switch self {
        case .fullName: return "This is how we'll address you"
        case .gender: return "Select your gender identity"
        case .dateOfBirth: return "This helps us provide age-appropriate insights"
        case .height: return "Select your height"
        case .weight: return "Select your weight"
        case .primaryGoal: return "Select your main health objective"
        case .activityLevel: return "How active are you daily?"
        case .waterIntake: return "Daily water consumption"
        }
    }
}

@MainActor
final class OneQuestionOnboardingViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var formState = ComprehensiveOnboardingFormState() {
        didSet {
            // Trigger UI update when formState changes
            objectWillChange.send()
        }
    }
    @Published var currentQuestion: OnboardingQuestion = .fullName
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var canProceed: Bool = false
    
    // MARK: - Location Manager
    
    private let locationManager = CLLocationManager()
    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    
    // MARK: - Dependencies
    
    private let onboardingService: ComprehensiveOnboardingServiceProtocol
    private let healthProfileService: HealthProfileServiceProtocol
    
    // MARK: - Init
    
    init(
        onboardingService: ComprehensiveOnboardingServiceProtocol = ComprehensiveOnboardingService.shared,
        healthProfileService: HealthProfileServiceProtocol = HealthProfileService.shared
    ) {
        self.onboardingService = onboardingService
        self.healthProfileService = healthProfileService
        
        locationManager.delegate = LocationDelegate(
            onAuthorizationChange: { [weak self] status in
                Task { @MainActor in
                    self?.locationPermissionStatus = status
                }
            },
            onLocationUpdate: { [weak self] coordinate in
                Task { @MainActor in
                    self?.formState.location = coordinate
                    self?.updateCanProceed()
                }
            }
        )
        locationPermissionStatus = locationManager.authorizationStatus
        
        // Observe formState changes to update canProceed
        formState.objectWillChange
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateCanProceed()
                }
            }
            .store(in: &cancellables)
        
        // Also observe currentQuestion changes
        $currentQuestion
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateCanProceed()
                }
            }
            .store(in: &cancellables)
        
        updateCanProceed()
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Navigation
    
    func nextQuestion() {
        if let next = OnboardingQuestion(rawValue: currentQuestion.rawValue + 1) {
            currentQuestion = next
            updateCanProceed()
        }
    }
    
    func previousQuestion() {
        if let previous = OnboardingQuestion(rawValue: currentQuestion.rawValue - 1) {
            currentQuestion = previous
            updateCanProceed()
        }
    }
    
    func skipQuestion() {
        // Only skip optional questions
        if isOptionalQuestion {
            nextQuestion()
        }
    }
    
    // MARK: - Location
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func fetchCurrentLocation() {
        guard locationPermissionStatus == .authorizedWhenInUse || locationPermissionStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        if let location = locationManager.location {
            formState.location = location.coordinate
        } else {
            locationManager.requestLocation()
        }
    }
    
    // MARK: - Save
    
    func saveOnboarding() async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else {
                throw ComprehensiveOnboardingError.notAuthenticated
            }
            
            let healthProfile = formState.toHealthProfile(userId: userId)
            try await healthProfileService.saveHealthProfile(healthProfile)
            
            let onboardingData = formState.toOnboardingJSON()
            try await onboardingService.saveOnboardingData(onboardingData)
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Validation
    
    func updateCanProceed() {
        canProceed = canProceedForCurrentQuestion
    }
    
    var canProceedForCurrentQuestion: Bool {
        switch currentQuestion {
        case .fullName:
            return !formState.fullName.trimmingCharacters(in: .whitespaces).isEmpty
        case .gender:
            return formState.gender != nil
        case .dateOfBirth:
            return true // Always valid
        case .height:
            return true // Has default value
        case .weight:
            return true // Has default value
        case .primaryGoal:
            return formState.primaryGoal != nil
        case .activityLevel:
            return formState.activityLevel != nil
        case .waterIntake:
            return formState.waterIntake != nil
        }
    }
    
    var isOptionalQuestion: Bool {
        switch currentQuestion {
        default:
            return false
        }
    }
}
