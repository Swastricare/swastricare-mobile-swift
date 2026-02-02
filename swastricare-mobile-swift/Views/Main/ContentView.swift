//
//  ContentView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit

// MARK: - Tab Enum

enum Tab: String, CaseIterable {
    case vitals = "Vitals"
    case vault = "Vault"
    case ai = "AI"
    case run = "Steps"
    case profile = "Profile"
    
    var icon: String {
        switch self {
        case .vitals: return "heart.text.square.fill"
        case .vault: return "lock.doc"
        case .ai: return "sparkles"
        case .run: return "figure.run"
        case .profile: return "person.circle"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    
    // MARK: - State
    
    @State private var currentTab: Tab = .vitals
    @StateObject private var homeViewModel = DependencyContainer.shared.homeViewModel
    @State private var hasConfiguredTabBar = false
    
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
            // Vitals Tab
            NavigationStack {
                HomeView()
                    .modifier(ToolbarBackgroundVisibilityModifier())
            }
            .tabItem {
                Label(Tab.vitals.rawValue, systemImage: Tab.vitals.icon)
            }
            .tag(Tab.vitals)
            
            // Vault Tab
            NavigationStack {
                VaultView()
                    .modifier(ToolbarBackgroundVisibilityModifier())
            }
            .tabItem {
                Label(Tab.vault.rawValue, systemImage: Tab.vault.icon)
            }
            .tag(Tab.vault)
            
            // AI Tab - Center of Attraction
            NavigationStack {
                AIView()
                    .modifier(ToolbarBackgroundVisibilityModifier())
            }
            .tabItem {
                Label(Tab.ai.rawValue, systemImage: Tab.ai.icon)
            }
            .tag(Tab.ai)
            
            // Run Tab - Steps & Activity Tracking
            NavigationStack {
                RunActivityView()
                    .modifier(ToolbarBackgroundVisibilityModifier())
            }
            .tabItem {
                Label(Tab.run.rawValue, systemImage: Tab.run.icon)
            }
            .tag(Tab.run)
            
            // Profile Tab
            NavigationStack {
                ProfileView()
                    .modifier(ToolbarBackgroundVisibilityModifier())
            }
            .tabItem {
                Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
            }
            .tag(Tab.profile)
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
            AppAnalyticsService.shared.logScreen(Tab.vitals.rawValue)
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
            
            // Refresh health data when switching to vitals (including hydration reminder scheduling)
            if homeViewModel.isAuthorized && newTab == .vitals {
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
           items.count > 2 {
            
            // Create green icon that stays green always
            let greenIcon = UIImage(systemName: Tab.ai.icon)?
                .withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
            
            // Apply to both selected and unselected states
            items[2].image = greenIcon
            items[2].selectedImage = greenIcon
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

