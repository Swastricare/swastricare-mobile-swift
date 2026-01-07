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
    case home = "Home"
    case tracker = "Tracker"
    case ai = "AI"
    case vault = "Vault"
    case profile = "Profile"
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .tracker: return "chart.bar"
        case .ai: return "sparkles"
        case .vault: return "lock.doc"
        case .profile: return "person.circle"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    
    // MARK: - State
    
    @State private var currentTab: Tab = .home
    @StateObject private var homeViewModel = DependencyContainer.shared.homeViewModel
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: $currentTab) {
            // Home Tab
            NavigationStack {
                HomeView()
                    .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
            }
            .tabItem {
                Label(Tab.home.rawValue, systemImage: Tab.home.icon)
            }
            .tag(Tab.home)
            
            // Tracker Tab
            NavigationStack {
                TrackerView()
                    .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
            }
            .tabItem {
                Label(Tab.tracker.rawValue, systemImage: Tab.tracker.icon)
            }
            .tag(Tab.tracker)
            
            // AI Tab
            NavigationStack {
                AIView()
                    .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
            }
            .tabItem {
                Label(Tab.ai.rawValue, systemImage: Tab.ai.icon)
            }
            .tag(Tab.ai)
            
            // Vault Tab
            NavigationStack {
                VaultView()
                    .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
            }
            .tabItem {
                Label(Tab.vault.rawValue, systemImage: Tab.vault.icon)
            }
            .tag(Tab.vault)
            
            // Profile Tab
            NavigationStack {
                ProfileView()
                    .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
            }
            .tabItem {
                Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
            }
            .tag(Tab.profile)
        }
        .onChange(of: currentTab) { oldTab, newTab in
            // Refresh health data when switching to home or tracker
            if homeViewModel.isAuthorized && (newTab == .home || newTab == .tracker) {
                Task {
                    await homeViewModel.loadTodaysData()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

