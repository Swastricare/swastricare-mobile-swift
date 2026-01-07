//
//  ProfileView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI

struct ProfileView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.profileViewModel
    
    // MARK: - Body
    
    var body: some View {
        List {
            // Profile Header
            profileHeader
            
            // Account Section
            accountSection
            
            // Settings Section
            settingsSection
            
            // About Section
            aboutSection
            
            // Sign Out
            signOutSection
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .alert(
            "Sign Out",
            isPresented: $viewModel.showSignOutConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            // Load user data in background when view appears
            await viewModel.loadUser()
        }
    }
    
    // MARK: - Subviews
    
    private var profileHeader: some View {
        Section {
            HStack(spacing: 16) {
                // Avatar
                if let avatarURL = viewModel.userAvatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } placeholder: {
                        defaultAvatar
                    }
                } else {
                    defaultAvatar
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.userName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(viewModel.userEmail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Member since \(viewModel.memberSince)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(PremiumColor.royalBlue)
            .frame(width: 80, height: 80)
            .overlay(
                Text(String(viewModel.userName.prefix(1)).uppercased())
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
    }
    
    private var accountSection: some View {
        Section("Account") {
            NavigationLink(destination: Text("Edit Profile")) {
                Label("Edit Profile", systemImage: "person.fill")
            }
            
            NavigationLink(destination: Text("Health Data")) {
                Label("Health Data", systemImage: "heart.text.square.fill")
            }
            
            NavigationLink(destination: Text("Connected Apps")) {
                Label("Connected Apps", systemImage: "app.connected.to.app.below.fill")
            }
        }
    }
    
    private var settingsSection: some View {
        Section("Settings") {
            Toggle(isOn: $viewModel.notificationsEnabled) {
                Label("Notifications", systemImage: "bell.fill")
            }
            
            Toggle(isOn: $viewModel.biometricEnabled) {
                Label(viewModel.biometricTypeName, systemImage: viewModel.biometricIcon)
            }
            .onChange(of: viewModel.biometricEnabled) { oldValue, newValue in
                // Only verify when enabling (from false to true)
                if newValue && !oldValue {
                    Task { await viewModel.toggleBiometric() }
                }
            }
            
            Toggle(isOn: $viewModel.healthSyncEnabled) {
                Label("Auto Sync Health", systemImage: "arrow.triangle.2.circlepath")
            }
            
            NavigationLink(destination: Text("Privacy")) {
                Label("Privacy", systemImage: "hand.raised.fill")
            }
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            NavigationLink(destination: Text("Help & Support")) {
                Label("Help & Support", systemImage: "questionmark.circle.fill")
            }
            
            NavigationLink(destination: Text("Terms of Service")) {
                Label("Terms of Service", systemImage: "doc.text.fill")
            }
            
            NavigationLink(destination: Text("Privacy Policy")) {
                Label("Privacy Policy", systemImage: "lock.shield.fill")
            }
            
            HStack {
                Label("Version", systemImage: "info.circle.fill")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var signOutSection: some View {
        Section {
            Button(action: {
                viewModel.showSignOutConfirmation = true
            }) {
                HStack {
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Sign Out")
                            .foregroundColor(.red)
                    }
                    Spacer()
                }
            }
            .disabled(viewModel.isLoading)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}

