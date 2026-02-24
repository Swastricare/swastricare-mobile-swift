//
//  ContentView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit
import Combine

// MARK: - App Tab Enum

enum AppTab: String, CaseIterable {
    case home = "Home"
    case ai = "AI"
    case vault = "Vault"
    case profile = "Profile"
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .ai: return "sparkles"
        case .vault: return "lock.doc"
        case .profile: return "person.circle"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    
    // MARK: - State
    
    @State private var currentTab: AppTab = .home
    @StateObject private var homeViewModel = DependencyContainer.shared.homeViewModel
    @State private var hasConfiguredTabBar = false
    @EnvironmentObject private var deepLinkHandler: DeepLinkHandler
    
    // MARK: - Init
    
    init() {
        // Configure transparent tab bar with blur effect
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.clear
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // MARK: - Body
    
  var body: some View {
    TabView(selection: $currentTab) {
        
        // Home
        Tab(AppTab.home.rawValue,
            systemImage: AppTab.home.icon,
            value: AppTab.home) {
            
            NavigationStack {
                MovementsHomeView()
                    .modifier(ToolbarBackgroundVisibilityModifier())
            }
        }
        
        // AI
       
        
        // Vault
        Tab(AppTab.vault.rawValue,
            systemImage: AppTab.vault.icon,
            value: AppTab.vault) {
            
            NavigationStack {
                VaultView()
                    .modifier(ToolbarBackgroundVisibilityModifier())
            }
        }
        
        // Profile
        Tab(AppTab.profile.rawValue,
            systemImage: AppTab.profile.icon,
            value: AppTab.profile) {
            
            NavigationStack {
                ProfileView()
                    .modifier(ToolbarBackgroundVisibilityModifier())
            }
        }
         Tab(AppTab.ai.rawValue,
            systemImage: AppTab.ai.icon,
            value: AppTab.ai,
            role: .search) {
            
            NavigationStack {
                AIView(onBack: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentTab = .home
                    }
                })
                    .modifier(ToolbarBackgroundVisibilityModifier())
                    .toolbar(.hidden, for: .tabBar) // 👈 hides tab bar
            }
        }
    }

        .task {
            // Fetch user + health profile once when main app appears (shared by Profile/Settings)
            await DependencyContainer.shared.profileViewModel.loadUser()
            // Fetch vault documents once when main app appears; use cached data in Vault tab
            await DependencyContainer.shared.vaultViewModel.loadDocuments()
            // Load hydration data and schedule reminders as soon as main app appears, so users
            // get push notifications even if they never open the Vitals tab or add any hydration entry
            await DependencyContainer.shared.hydrationViewModel.loadData()
        }
        .onAppear {
            configureAITabColor()
            AppAnalyticsService.shared.log(eventName: "app_open", eventType: "action", properties: [:])
            AppAnalyticsService.shared.logScreen(AppTab.home.rawValue)
        }
        .onChange(of: currentTab) { oldTab, newTab in
            AppAnalyticsService.shared.logTabSelected(tab: newTab.rawValue.lowercased())
            // Haptic feedback on tab change
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            // Re-apply green color to AI tab after switching
            DispatchQueue.main.async {
                self.applyGreenToAITab()
            }
            
            // Refresh health data when switching to home (including hydration reminder scheduling)
            if homeViewModel.isAuthorized && newTab == .home {
                Task {
                    await homeViewModel.loadTodaysData()
                    await DependencyContainer.shared.hydrationViewModel.loadData()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToAITab"))) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentTab = .ai
            }
        }
        .onReceive(deepLinkHandler.$currentDeepLink.compactMap { $0 }) { deepLink in
            route(deepLink: deepLink)
        }
        .onReceive(deepLinkHandler.$pendingWorkout.compactMap { $0 }) { pending in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .home
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(
                    name: .deepLinkOpenLiveTracking,
                    object: nil,
                    userInfo: [DeepLinkUserInfoKey.workoutType: pending.type]
                )
            }
        }
    }

    // MARK: - Deep Link Routing

    private func route(deepLink: DeepLink) {
        switch deepLink {
        case .home:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .home
            }

        case .hydration:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .home
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .deepLinkOpenHydration, object: nil)
            }

        case .medications:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .home
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .deepLinkOpenMedications, object: nil)
            }

        case .heartRate:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .home
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .deepLinkOpenHeartRate, object: nil)
            }

        case .steps, .run:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .home
            }

        case .activeWorkout:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .home
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .deepLinkOpenLiveTracking, object: nil)
            }

        case .startRun(let type):
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .home
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(
                    name: .deepLinkOpenLiveTracking,
                    object: nil,
                    userInfo: [DeepLinkUserInfoKey.workoutType: type]
                )
            }
        case .familyJoin(code: let code):
            // Family lives under Profile → Family. Route user to Profile,
            // then broadcast the invite code so Family UI can present Join flow.
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .profile
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                deepLinkHandler.pendingFamilyInviteCode = code
                NotificationCenter.default.post(
                    name: .deepLinkFamilyJoin,
                    object: nil,
                    userInfo: [DeepLinkUserInfoKey.familyInviteCode: code]
                ) 
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func configureAITabColor() {
        guard !hasConfiguredTabBar else { return }
        
        // Try multiple times with increasing delays to ensure it applies
        for delay in [0.1, 0.3, 0.5, 0.7] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.applyGreenToAITab()
            }
        }
        
        hasConfiguredTabBar = true
    }
    
    private func applyGreenToAITab() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let tabBarController = window.rootViewController?.children.first as? UITabBarController,
           let items = tabBarController.tabBar.items,
           items.count > 1 {
            
            // Create green icon that stays green always
            let greenIcon = UIImage(systemName: AppTab.ai.icon)?
                .withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
            
            // Apply to both selected and unselected states (AI is now at index 1)
            items[1].image = greenIcon
            items[1].selectedImage = greenIcon
        }
    }
}

// MARK: - Toolbar Background Visibility Modifier

struct ToolbarBackgroundVisibilityModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.toolbarBackgroundVisibility(.automatic, for: .navigationBar)
        } else {
            content
        }
    }
}


#Preview {
    ContentView()
}

