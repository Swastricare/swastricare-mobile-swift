//
//  swastricare_mobile_swiftApp.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI
import Supabase

@main
struct swastricare_mobile_swiftApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var biometricAuth = BiometricAuthManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showMainApp = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showMainApp {
                    ZStack {
                        // Main Content
                        Group {
                            if authManager.isAuthenticated {
                                ContentView()
                            } else {
                                AuthView()
                            }
                        }
                        
                        // Biometric Lock Screen Overlay
                        if biometricAuth.isLocked && authManager.isAuthenticated {
                            LockScreenView()
                                .transition(.opacity)
                                .zIndex(999)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: biometricAuth.isLocked)
                    .transition(.opacity)
                } else {
                    SplashView(isActive: $showMainApp)
                }
            }
            .onOpenURL { url in
                Task {
                    await handleOAuthCallback(url: url)
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
            }
        }
    }
    
    private func handleOAuthCallback(url: URL) async {
        do {
            try await SupabaseManager.shared.client.auth.session(from: url)
            await authManager.checkAuthStatus()
        } catch {
            print("OAuth callback error: \(error)")
        }
    }
    
    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Lock the app when going to background
            if authManager.isAuthenticated {
                biometricAuth.lock()
            }
            
        case .active:
            // App became active (from background or initial launch)
            // If user is authenticated and app is locked, authentication will auto-trigger in LockScreenView
            
            // Load fresh health data when app becomes active
            if authManager.isAuthenticated && healthManager.isAuthorized {
                Task {
                    await healthManager.fetchAllHealthData()
                    print("✅ Health data refreshed on app activation")
                }
            }
            
        case .inactive:
            // App is temporarily inactive (e.g., during phone call, notification center)
            break
            
        @unknown default:
            break
        }
    }
}
