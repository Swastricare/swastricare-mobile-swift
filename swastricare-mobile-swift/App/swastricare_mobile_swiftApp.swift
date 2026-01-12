//
//  swastricare_mobile_swiftApp.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - App Entry Point
//

import SwiftUI
import UIKit
import WidgetKit
import Supabase
import Auth

@main
struct swastricare_mobile_swiftApp: App {
    
    // MARK: - State
    
    @StateObject private var authViewModel = DependencyContainer.shared.authViewModel
    @StateObject private var lockViewModel = DependencyContainer.shared.lockScreenViewModel
    @StateObject private var appVersionService = AppVersionService.shared
    
    @State private var hasCompletedOnboarding: Bool = {
        if AppConfig.isTestingMode {
            return false
        }
        // Show onboarding only for new users (before first login)
        return UserDefaults.standard.bool(forKey: AppConfig.hasLoggedInBeforeKey)
    }()
    
    @State private var hasAcceptedConsent: Bool = {
        if AppConfig.isTestingMode {
            return false
        }
        // Show consent screen if user hasn't accepted terms and privacy policy
        return UserDefaults.standard.bool(forKey: AppConfig.hasAcceptedConsentKey)
    }()
    
    // Health profile state - checked from DB on auth
    // IMPORTANT: Start as false - only check when authenticated
    @State private var hasCompletedHealthProfile: Bool = false
    @State private var isCheckingHealthProfile: Bool = false
    @State private var hasCheckedHealthProfile: Bool = false
    
    // App version state
    @State private var hasCheckedAppVersion: Bool = false
    
    // Notification permission state
    @State private var hasRequestedNotificationPermission: Bool = false
    
    @Environment(\.scenePhase) private var scenePhase
    
    // Deep link handling for widgets
    @State private var deepLinkDestination: DeepLinkDestination?
    
    // Notification delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - Init
    
    init() {
        configureGlobalAppearance()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            Group {
                // FIRST: Check app version before anything else
                if !hasCheckedAppVersion {
                    SplashView()
                        .task {
                            await checkAppVersion()
                            // Request notification permission after version check
                            await requestNotificationPermissionIfNeeded()
                        }
                } else if appVersionService.updateStatus.requiresAction {
                    // FORCE UPDATE: Block the app until user updates
                    ForceUpdateView(appVersionService: appVersionService, onSkip: nil)
                } else if !hasCompletedOnboarding {
                    OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                } else if !hasAcceptedConsent {
                    // Show consent screen after onboarding
                    ConsentView(hasAcceptedConsent: $hasAcceptedConsent)
                } else if authViewModel.authState == .unknown {
                    // Loading state - checking auth
                    SplashView()
                } else if authViewModel.isAuthenticated {
                    // CRITICAL: User MUST be authenticated to reach here
                    // Always check DB once per authenticated session BEFORE deciding to show questionnaire
                    if !hasCheckedHealthProfile || isCheckingHealthProfile {
                        SplashView()
                            .task {
                                await checkHealthProfileFromDB()
                            }
                    } else if !hasCompletedHealthProfile {
                        // Show health profile questionnaire ONLY if:
                        // 1. User is authenticated (already checked above)
                        // 2. Profile check is complete (hasCheckedHealthProfile == true)
                        // 3. No profile found (!hasCompletedHealthProfile)
                        
                        // TRIPLE-CHECK: Verify authentication one more time
                        if authViewModel.isAuthenticated && authViewModel.currentUser != nil {
                            OneQuestionPerScreenOnboardingView {
                                // Profile saved to DB - update state to proceed to main app
                                hasCompletedHealthProfile = true
                                // Refresh auth profile to load the new data
                                Task {
                                    await authViewModel.fetchHealthProfile()
                                }
                            }
                        } else {
                            // Safety: If somehow we got here without auth, show login
                            LoginView()
                        }
                    } else if lockViewModel.isLocked && UserDefaults.standard.bool(forKey: "biometricEnabled") {
                        // Show lock screen if enabled
                        LockScreenView()
                    } else {
                        // Show main app
                        ContentView()
                    }
                } else {
                    // NOT AUTHENTICATED - show login screen
                    // NEVER show questionnaire here - this is the login screen
                    LoginView()
                }
            }
            .animation(.easeInOut, value: authViewModel.authState)
            .animation(.easeInOut, value: hasCompletedOnboarding)
            .animation(.easeInOut, value: hasAcceptedConsent)
            .animation(.easeInOut, value: hasCompletedHealthProfile)
            .animation(.easeInOut, value: hasCheckedAppVersion)
            .withDependencies()
            .environmentObject(appVersionService)
            .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    // User just logged in - check if they have a health profile in DB
                    print("🔐 User authenticated - checking health profile...")
                    hasCompletedHealthProfile = false  // Reset until DB confirms
                    hasCheckedHealthProfile = false    // Force a DB check for this session
                    isCheckingHealthProfile = false    // Let the view trigger the check task
                } else {
                    // User logged out - reset state completely
                    print("🔐 User logged out - resetting health profile state")
                    hasCompletedHealthProfile = false
                    isCheckingHealthProfile = false  // Don't check until next login
                    hasCheckedHealthProfile = false
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
            }
            .onOpenURL { url in
                // Pass OAuth callbacks to Supabase SDK
                Task {
                    try? await SupabaseManager.shared.client.auth.session(from: url)
                }
                
                handleDeepLink(url: url)
            }
        }
    }
    
    // MARK: - Deep Link Handling
    
    private func handleDeepLink(url: URL) {
        // Handle widget deep links
        guard url.scheme == "swastricareapp" else { return }
        
        switch url.host {
        case "hydration":
            deepLinkDestination = .hydration
            print("🔗 Deep link: Opening Hydration")
        case "medications":
            deepLinkDestination = .medications
            print("🔗 Deep link: Opening Medications")
        default:
            break
        }
    }
    
    // MARK: - App Version Check
    
    /// Check app version on launch - blocks app if force update required
    private func checkAppVersion() async {
        print("📱 Checking app version...")
        let status = await appVersionService.checkForUpdates(force: true)
        
        await MainActor.run {
            hasCheckedAppVersion = true
        }
        
        print("📱 App version check complete: \(status)")
    }
    
    // MARK: - Notification Permission
    
    /// Request notification permission if not yet determined
    private func requestNotificationPermissionIfNeeded() async {
        // Only request once per app launch
        guard !hasRequestedNotificationPermission else {
            return
        }
        
        await MainActor.run {
            hasRequestedNotificationPermission = true
        }
        
        // Check current permission status
        let status = await NotificationService.shared.checkPermissionStatus()
        
        // Only request if permission hasn't been determined yet
        if status == .notDetermined {
            print("🔔 Requesting notification permission...")
            let granted = await NotificationService.shared.requestPermission()
            print("🔔 Notification permission: \(granted ? "granted" : "denied")")
        } else {
            print("🔔 Notification permission already determined: \(status)")
        }
    }
    
    // MARK: - Health Profile Check
    
    /// Check health profile from database - this is the source of truth (per user)
    /// IMPORTANT: This function ONLY runs when user is authenticated
    private func checkHealthProfileFromDB() async {
        // Avoid concurrent checks
        if await MainActor.run(body: { isCheckingHealthProfile }) {
            return
        }
        await MainActor.run {
            isCheckingHealthProfile = true
        }
        
        // Double-check authentication - NEVER check profile if not logged in
        guard authViewModel.isAuthenticated else {
            print("🚫 Health profile check: User NOT authenticated - skipping check")
            await MainActor.run {
                hasCompletedHealthProfile = false
                isCheckingHealthProfile = false
                hasCheckedHealthProfile = true
            }
            return
        }
        
        print("✅ Health profile check: User is authenticated, proceeding with check")
        
        // IMPORTANT: Add 2-second minimum delay to show splash screen animations
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2.0 seconds
        
        // Retry up to 3 times if session isn't ready
        var attempts = 0
        let maxAttempts = 3
        
        while attempts < maxAttempts {
            attempts += 1
            
            do {
                // Query database for THIS user's health profile
                let hasProfile = try await HealthProfileService.shared.hasHealthProfile()
                print("📋 Health profile check (attempt \(attempts)): \(hasProfile ? "✅ EXISTS - skip questionnaire" : "❌ NOT FOUND - show questionnaire")")
                
                await MainActor.run {
                    hasCompletedHealthProfile = hasProfile
                    isCheckingHealthProfile = false
                    hasCheckedHealthProfile = true
                }
                return // Success, exit
                
            } catch {
                print("⚠️ Health profile check attempt \(attempts) failed: \(error.localizedDescription)")
                
                if attempts < maxAttempts {
                    // Wait before retry
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                } else {
                    // All attempts failed - show questionnaire
                    print("❌ All health profile check attempts failed")
                    await MainActor.run {
                        hasCompletedHealthProfile = false
                        isCheckingHealthProfile = false
                        hasCheckedHealthProfile = true
                    }
                }
            }
        }
    }
    
    // MARK: - Scene Phase Handler
    
    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Lock the app when going to background
            if authViewModel.isAuthenticated && UserDefaults.standard.bool(forKey: "biometricEnabled") {
                lockViewModel.lock()
            }
            
        case .active:
            // Re-check app version periodically when becoming active
            Task {
                let status = await appVersionService.checkForUpdates(force: false)
                if status.requiresAction {
                    // Force update now required
                    await MainActor.run {
                        hasCheckedAppVersion = true
                    }
                }
            }
            
            // Refresh health data when app becomes active
            if authViewModel.isAuthenticated {
                let homeVM = DependencyContainer.shared.homeViewModel
                if homeVM.isAuthorized {
                    Task {
                        await homeVM.loadTodaysData()
                    }
                }
                
                // Refresh widget data and process pending actions
                Task {
                    // Process pending widget quick actions
                    await DependencyContainer.shared.hydrationViewModel.loadData()
                    await DependencyContainer.shared.medicationViewModel.refresh()
                }
            }
            
            // Clear notification badge
            Task { @MainActor in
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
            
        case .inactive:
            break
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Global Appearance Configuration
    
    private func configureGlobalAppearance() {
        // iOS 26 Liquid Glass appearance for UIKit components
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithDefaultBackground()
        UIToolbar.appearance().standardAppearance = toolbarAppearance
        UIToolbar.appearance().scrollEdgeAppearance = toolbarAppearance
    }
}

// MARK: - Deep Link Destination

enum DeepLinkDestination {
    case hydration
    case medications
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Initialize notification service (sets up delegate)
        _ = NotificationService.shared
        print("🔔 NotificationService initialized")
        
        // Register for remote notifications
        NotificationService.shared.registerForRemoteNotifications()
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await NotificationService.shared.handleDeviceToken(deviceToken)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationService.shared.handleRemoteNotificationError(error)
    }
}
