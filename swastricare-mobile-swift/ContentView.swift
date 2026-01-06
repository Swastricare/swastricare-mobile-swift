//
//  ContentView.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI
import Auth

struct ContentView: View {
    @State private var currentTab: Tab = .home
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Premium Background Layer
            PremiumBackground()
            
            // Main Content Layer
            Group {
                switch currentTab {
                case .home:
                    HomeView()
                case .tracker:
                    TrackerView()
                case .ai:
                    FunctionalAIView()
                case .vault:
                    VaultView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Fixed Bottom Navigation Bar
            GlassDock(currentTab: $currentTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    ContentView()
}
