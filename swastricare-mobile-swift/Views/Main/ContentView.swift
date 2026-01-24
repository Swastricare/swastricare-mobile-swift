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
    case ai = "AI"
    case vault = "Vault"
    case profile = "Profile"
    
    var icon: String {
        switch self {
        case .vitals: return "heart.text.square.fill"
        case .ai: return "sparkles"
        case .vault: return "lock.doc"
        case .profile: return "person.circle"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    
    // MARK: - State
    
    @State private var currentTab: Tab = .vitals
    @StateObject private var homeViewModel = DependencyContainer.shared.homeViewModel
    
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
            
            // AI Tab
            NavigationStack {
                AIView()
                    .modifier(ToolbarBackgroundVisibilityModifier())
            }
            .tabItem {
                Label(Tab.ai.rawValue, systemImage: Tab.ai.icon)
            }
            .tag(Tab.ai)
            
            // Vault Tab
            NavigationStack {
                VaultView()
                    .modifier(ToolbarBackgroundVisibilityModifier())
            }
            .tabItem {
                Label(Tab.vault.rawValue, systemImage: Tab.vault.icon)
            }
            .tag(Tab.vault)
            
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
        }
        .onChange(of: currentTab) { oldTab, newTab in
            // Haptic feedback on tab change
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Refresh health data when switching to vitals
            if homeViewModel.isAuthorized && newTab == .vitals {
                Task {
                    await homeViewModel.loadTodaysData()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToAITab"))) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentTab = .ai
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

