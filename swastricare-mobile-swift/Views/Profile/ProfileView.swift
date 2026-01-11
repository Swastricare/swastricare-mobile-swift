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
    @StateObject private var hydrationViewModel = DependencyContainer.shared.hydrationViewModel
    
    // MARK: - State
    
    @State private var showHydrationSettings = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            PremiumBackground()
            
            List {
                // Profile Header
                profileHeader
                
                // Health Profile Section
                healthProfileSection
                
                // Hydration Section
                hydrationSection
                
                // Settings Section
                settingsSection
                
                // About Section
                aboutSection
                
                // Sign Out
                signOutSection
            }
            .scrollContentBackground(.hidden)
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
        .alert(
            "Delete Account",
            isPresented: $viewModel.showDeleteAccountConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
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
            VStack(spacing: 16) {
                // Avatar
                if let avatarURL = viewModel.userAvatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } placeholder: {
                        defaultAvatar
                    }
                } else {
                    defaultAvatar
                }
                
                // Info
                VStack(spacing: 6) {
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
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .listRowBackground(Color.clear)
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 100, height: 100)
            .overlay(
                Text(String(viewModel.userName.prefix(1)).uppercased())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            )
            .shadow(color: Color(hex: "2E3192").opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    private var healthProfileSection: some View {
        Section {
            if viewModel.isLoadingHealthProfile {
                // Loading shimmer state
                ForEach(0..<5, id: \.self) { _ in
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 16)
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 80, height: 16)
                    }
                    .shimmering()
                }
            } else if viewModel.hasHealthProfile {
                // Name
                HealthProfileRow(icon: "person.fill", iconColor: .blue, label: "Name", value: viewModel.profileName)
                
                // Gender
                HealthProfileRow(icon: "person.2.fill", iconColor: .purple, label: "Gender", value: viewModel.profileGender)
                
                // Age
                HealthProfileRow(icon: "calendar", iconColor: .orange, label: "Age", value: viewModel.profileAge)
                
                // Height
                HealthProfileRow(icon: "ruler.fill", iconColor: .green, label: "Height", value: viewModel.profileHeight)
                
                // Weight
                HealthProfileRow(icon: "scalemass.fill", iconColor: .cyan, label: "Weight", value: viewModel.profileWeight)
                
                // BMI
                HealthProfileRow(icon: "figure.stand", iconColor: .indigo, label: "BMI", value: viewModel.profileBMI)
                
                // Blood Type
                if viewModel.profileBloodType != "Not set" {
                    HealthProfileRow(icon: "drop.fill", iconColor: .red, label: "Blood Type", value: viewModel.profileBloodType)
                }
            } else {
                // No profile found
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("No health profile found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Complete your health profile during onboarding")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            }
        } header: {
            HStack {
                Text("Health Profile")
                Spacer()
                if viewModel.hasHealthProfile && !viewModel.isLoadingHealthProfile {
                    Button {
                        Task { await viewModel.refreshHealthProfile() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    private var hydrationSection: some View {
        Section("Hydration") {
            // Activity Level for hydration
            HStack {
                Label("Activity Level", systemImage: hydrationViewModel.preferences.activityLevel.icon)
                Spacer()
                Text(hydrationViewModel.preferences.activityLevel.displayName)
                    .foregroundColor(.secondary)
            }
            
            // Hydration Goal
            HStack {
                Label("Daily Goal", systemImage: "drop.fill")
                    .foregroundColor(.cyan)
                Spacer()
                Text("\(hydrationViewModel.dailyGoal) ml")
                    .foregroundColor(.secondary)
            }
            
            // Hydration Settings
            Button(action: { showHydrationSettings = true }) {
                HStack {
                    Label("Hydration Preferences", systemImage: "gearshape.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
        .task {
            await hydrationViewModel.loadData()
        }
        .sheet(isPresented: $showHydrationSettings) {
            HydrationSettingsView(viewModel: hydrationViewModel)
        }
    }
    
    private var settingsSection: some View {
        Section("Settings") {
            Toggle(isOn: $viewModel.notificationsEnabled) {
                Label("Notifications", systemImage: "bell.fill")
            }
            
            // Biometric toggle - uses custom binding to verify before enabling
            HStack {
                Label(viewModel.biometricTypeName, systemImage: viewModel.biometricIcon)
                Spacer()
                if viewModel.isTogglingBiometric {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Toggle("", isOn: Binding(
                        get: { viewModel.biometricEnabled },
                        set: { _ in
                            Task { await viewModel.toggleBiometric() }
                        }
                    ))
                    .labelsHidden()
                }
            }
            
            Toggle(isOn: $viewModel.healthSyncEnabled) {
                Label("Auto Sync Health", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle.fill")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var signOutSection: some View {
                Section {
            Button(action: {
                viewModel.showDeleteAccountConfirmation = true
            }) {
                HStack {
                    Spacer()
                    Label("Delete Account", systemImage: "trash.fill")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            .disabled(viewModel.isLoading)
        } footer: {
            Text("Permanently delete your account and all associated data.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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

// MARK: - Health Profile Row

struct HealthProfileRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
            }
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2) * phase)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}

