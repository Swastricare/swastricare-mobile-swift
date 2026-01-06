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
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                } else {
                    AuthView()
                }
            }
            .onOpenURL { url in
                Task {
                    await handleOAuthCallback(url: url)
                }
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
}
