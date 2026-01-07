//
//  swastricare_mobile_swiftApp.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - App Entry Point
//

import SwiftUI
import UIKit

@main
struct swastricare_mobile_swiftApp: App {
    
    // MARK: - State
    
    @StateObject private var authViewModel = DependencyContainer.shared.authViewModel
    @StateObject private var lockViewModel = DependencyContainer.shared.lockScreenViewModel
    @State private var hasCompletedOnboarding: Bool = {
        if AppConfig.isTestingMode {
            return false
        }
        return UserDefaults.standard.bool(forKey: AppConfig.hasSeenOnboardingKey)
    }()
    
    @Environment(\.scenePhase) private var scenePhase
    
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
                if !hasCompletedOnboarding {
                    OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                } else if authViewModel.authState == .unknown {
                    // Loading state
                    SplashView()
                } else if authViewModel.isAuthenticated {
                    // Authenticated - show main app or lock screen
                    if lockViewModel.isLocked && UserDefaults.standard.bool(forKey: "biometricEnabled") {
                        LockScreenView()
                    } else {
                        ContentView()
                    }
                } else {
                    // Not authenticated - show login
                    LoginView()
                }
            }
            .animation(.easeInOut, value: authViewModel.authState)
            .animation(.easeInOut, value: hasCompletedOnboarding)
            .withDependencies()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
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
            // Refresh health data when app becomes active
            if authViewModel.isAuthenticated {
                let homeVM = DependencyContainer.shared.homeViewModel
                if homeVM.isAuthorized {
                    Task {
                        await homeVM.loadTodaysData()
                    }
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
