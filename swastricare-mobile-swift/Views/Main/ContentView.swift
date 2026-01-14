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
    case family = "Family"
    case profile = "Profile"
    
    var icon: String {
        switch self {
        case .vitals: return "heart.text.square.fill"
        case .vault: return "lock.doc"
        case .ai: return "sparkles"
        case .family: return "person.2"
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
            
            // Family Tab
            NavigationStack {
                FamilyPlaceholderView()
                    .modifier(ToolbarBackgroundVisibilityModifier())
            }
            .tabItem {
                Label(Tab.family.rawValue, systemImage: Tab.family.icon)
            }
            .tag(Tab.family)
            
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
        .onAppear {
            configureAITabColor()
        }
        .onChange(of: currentTab) { oldTab, newTab in
            // Haptic feedback on tab change
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Re-apply green color to AI tab after switching
            DispatchQueue.main.async {
                self.applyGreenToAITab()
            }
            
            // Refresh health data when switching to vitals
            if homeViewModel.isAuthorized && newTab == .vitals {
                Task {
                    await homeViewModel.loadTodaysData()
                }
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

// MARK: - Family Placeholder View

struct FamilyPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Family")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Coming Soon")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Family")
    }
}

#Preview {
    ContentView()
}

