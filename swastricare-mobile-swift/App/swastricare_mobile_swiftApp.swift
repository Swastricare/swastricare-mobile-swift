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
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Init
    
    init() {
        configureGlobalAppearance()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.authState == .unknown {
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

