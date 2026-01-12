//
//  ComprehensiveOnboardingViewModel.swift
//  swastricare-mobile-swift
//
//  Comprehensive Onboarding ViewModel
//

import Foundation
import Combine
import CoreLocation
import Supabase
import Auth

@MainActor
final class ComprehensiveOnboardingViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var formState = ComprehensiveOnboardingFormState()
    @Published var currentScreen: OnboardingScreen = .profileSetup
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
                }
            }
        )
        locationPermissionStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Navigation
    
    func nextScreen() {
        switch currentScreen {
        case .profileSetup:
            if formState.canProceedFromProfileSetup {
                currentScreen = .bodyMetrics
            }
        case .bodyMetrics:
            currentScreen = .goals
        case .goals:
            if formState.canProceedFromGoals {
                currentScreen = .lifestyle
            }
        case .lifestyle:
            if formState.canProceedFromLifestyle {
                currentScreen = .health
            }
        case .health:
            if formState.canProceedFromHealth {
            if formState.hasRegularMedication == true {
                currentScreen = .medicationDetails
            } else {
                currentScreen = .habits
            }
            }
        case .medicationDetails:
            if formState.canProceedFromMedication {
                currentScreen = .habits
            }
        case .habits:
            if formState.canProceedFromEmergency {
                currentScreen = .permissions
            }
        case .permissions:
            break // Final screen
        }
    }
    
    func previousScreen() {
        switch currentScreen {
        case .profileSetup:
            break // First screen
        case .bodyMetrics:
            currentScreen = .profileSetup
        case .goals:
            currentScreen = .bodyMetrics
        case .lifestyle:
            currentScreen = .goals
        case .health:
            currentScreen = .lifestyle
        case .medicationDetails:
            currentScreen = .health
        case .habits:
            if formState.hasRegularMedication == true {
                currentScreen = .medicationDetails
            } else {
                currentScreen = .health
            }
        case .permissions:
            currentScreen = .habits
        }
    }
    
    func skipScreen() {
        // Skip to next screen, marking optional fields as skipped
        switch currentScreen {
        case .bodyMetrics:
            // Body goal is optional, can skip
            currentScreen = .goals
        case .goals:
            // Family history is optional, can skip
            currentScreen = .lifestyle
        default:
            nextScreen()
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
            // Save health profile
            guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else {
                throw ComprehensiveOnboardingError.notAuthenticated
            }
            
            let healthProfile = formState.toHealthProfile(userId: userId)
            try await healthProfileService.saveHealthProfile(healthProfile)
            
            // Save comprehensive onboarding data
            let onboardingData = formState.toOnboardingJSON()
            try await onboardingService.saveOnboardingData(onboardingData)
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Validation
    
    var canProceed: Bool {
        switch currentScreen {
        case .profileSetup:
            return formState.canProceedFromProfileSetup
        case .bodyMetrics:
            return formState.canProceedFromBodyMetrics
        case .goals:
            return formState.canProceedFromGoals
        case .lifestyle:
            return formState.canProceedFromLifestyle
        case .health:
            return formState.canProceedFromHealth
        case .medicationDetails:
            return formState.canProceedFromMedication
        case .habits:
            return formState.smoking != nil && formState.alcohol != nil && formState.canProceedFromEmergency
        case .permissions:
            return true // Can always proceed
        }
    }
    
    var isOptionalScreen: Bool {
        switch currentScreen {
        case .bodyMetrics:
            return formState.bodyGoal == nil // Body goal is optional
        case .goals:
            return true // Family history is optional
        default:
            return false
        }
    }
}

// MARK: - Onboarding Screen Enum

enum OnboardingScreen: Int, CaseIterable {
    case profileSetup = 0
    case bodyMetrics = 1
    case goals = 2
    case lifestyle = 3
    case health = 4
    case medicationDetails = 5
    case habits = 6
    case permissions = 7
    
    var title: String {
        switch self {
        case .profileSetup: return "Profile Setup"
        case .bodyMetrics: return "Body Metrics"
        case .goals: return "Your Goals"
        case .lifestyle: return "Lifestyle"
        case .health: return "Health Information"
        case .medicationDetails: return "Medication Details"
        case .habits: return "Habits & Emergency"
        case .permissions: return "Permissions"
        }
    }
    
    var subtitle: String {
        switch self {
        case .profileSetup: return "Let's start with the basics"
        case .bodyMetrics: return "Help us understand your body"
        case .goals: return "What do you want to achieve?"
        case .lifestyle: return "Tell us about your daily routine"
        case .health: return "Your health matters"
        case .medicationDetails: return "Tell us about your medications"
        case .habits: return "Lifestyle habits and emergency contact"
        case .permissions: return "Enable features for better experience"
        }
    }
    
    var progress: Double {
        Double(rawValue + 1) / Double(OnboardingScreen.allCases.count)
    }
}

// MARK: - Location Delegate

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    let onAuthorizationChange: (CLAuthorizationStatus) -> Void
    let onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?
    
    init(
        onAuthorizationChange: @escaping (CLAuthorizationStatus) -> Void,
        onLocationUpdate: ((CLLocationCoordinate2D) -> Void)? = nil
    ) {
        self.onAuthorizationChange = onAuthorizationChange
        self.onLocationUpdate = onLocationUpdate
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange(manager.authorizationStatus)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            onLocationUpdate?(location.coordinate)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Errors

enum ComprehensiveOnboardingError: LocalizedError {
    case notAuthenticated
    case userCreationFailed
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .userCreationFailed:
            return "Failed to create user record"
        case .saveFailed(let message):
            return "Failed to save onboarding data: \(message)"
        }
    }
}
