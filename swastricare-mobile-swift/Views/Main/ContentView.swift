//
//  ContentView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit
import Combine

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
        VStack(spacing: 0) {
        OfflineBanner()
        TabView(selection: $currentTab) {
            // Vitals Tab
            NavigationStack {
                HomeViewV2()
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
            AppAnalyticsService.shared.log(eventName: "app_open", eventType: "action", properties: [:])
            AppAnalyticsService.shared.logScreen(Tab.vitals.rawValue)
        }
        .onChange(of: currentTab) { oldTab, newTab in
            AppAnalyticsService.shared.logTabSelected(tab: newTab.rawValue.lowercased())
            // Haptic feedback on tab change
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

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
        .onReceive(deepLinkHandler.$currentDeepLink.compactMap { $0 }) { deepLink in
            route(deepLink: deepLink)
        }
        .onReceive(deepLinkHandler.$pendingWorkout.compactMap { $0 }) { pending in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .run
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(
                    name: .deepLinkOpenLiveTracking,
                    object: nil,
                    userInfo: [DeepLinkUserInfoKey.workoutType: pending.type]
                )
            }
        }
        } // VStack
    }

    // MARK: - Deep Link Routing

    private func route(deepLink: DeepLink) {
        switch deepLink {
        case .home:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .vitals
            }

        case .hydration:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .vitals
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .deepLinkOpenHydration, object: nil)
            }

        case .medications:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .vitals
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .deepLinkOpenMedications, object: nil)
            }

        case .heartRate:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .vitals
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .deepLinkOpenHeartRate, object: nil)
            }

        case .steps, .run:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .run
            }

        case .activeWorkout:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .run
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .deepLinkOpenLiveTracking, object: nil)
            }

        case .startRun(let type):
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .run
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
        case .referral:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentTab = .profile
            }
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

