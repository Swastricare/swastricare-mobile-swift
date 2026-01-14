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
                Label {
                    Text(Tab.ai.rawValue)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: Tab.ai.icon)
                        .symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeating)
                }
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

