//
//  SettingsView.swift
//  swastricare-mobile-swift
//
//  Settings Screen with Linear Loading Progress
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = DependencyContainer.shared.profileViewModel
    @StateObject private var hydrationViewModel = HydrationViewModel()
    @EnvironmentObject private var appVersionService: AppVersionService
    
    @State private var isLoading = false
    @State private var loadingProgress: Double = 0.0
    @State private var loadingMessage: String = "Loading settings..."
    @State private var activeSheet: ProfileSheet?
    
    var body: some View {
        ZStack {
            PremiumBackground()
            
            if isLoading {
                // Loading State with Linear Progress
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Animated Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "2E3192").opacity(0.2), Color(hex: "4A90E2").opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .blur(radius: 20)
                        
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color(hex: "2E3192"))
                            .symbolEffect(.pulse, options: .repeating)
                    }
                    
                    // Loading Message
                    VStack(spacing: 12) {
                        Text(loadingMessage)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut, value: loadingMessage)
                        
                        Text("\(Int(loadingProgress * 100))%")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 40)
                    
                    // Linear Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)
                            
                            // Progress Fill
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * loadingProgress, height: 6)
                                .animation(.linear(duration: 0.2), value: loadingProgress)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
            } else {
                // Settings Content
                List {
                    // Profile Header
                    profileHeader
                    
                    // Health Profile Section
                    healthProfileSection
                    
                    // Family Section
                    familySection

                    // Goals Section
                    goalsSection

                    // Hydration Section
                    hydrationSection
                    
                    // Settings Section
                    settingsSection
                    
                    // Sign Out and Delete Account
                    signOutSection
                    
                    // Version at bottom
                    Section {
                        EmptyView()
                    } footer: {
                        versionFooter
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .terms:
                TermsContentView()
            case .privacy:
                PrivacyContentView()
            case .hydrationSettings:
                HydrationSettingsView(viewModel: hydrationViewModel)
            case .appUpdate:
                ForceUpdateView(appVersionService: appVersionService, onSkip: { activeSheet = nil })
            }
        }
        .task {
            await loadSettings()
        }
        .trackScreen("Settings")
    }

    // MARK: - Loading
    
    private func loadSettings() async {
        // Health profile loaded once in ContentView; use cached data. Refresh via button in health profile section.
        isLoading = true
        loadingProgress = 0.0
        loadingMessage = "Loading preferences..."
        
        await hydrationViewModel.loadData()
        
        await MainActor.run {
            loadingProgress = 1.0
            isLoading = false
        }
    }
    
    // MARK: - Sheet Type
    
    enum ProfileSheet: Identifiable {
        case terms
        case privacy
        case hydrationSettings
        case appUpdate
        
        var id: String {
            switch self {
            case .terms: return "terms"
            case .privacy: return "privacy"
            case .hydrationSettings: return "hydrationSettings"
            case .appUpdate: return "appUpdate"
            }
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
                HealthProfileRow(icon: "person.fill", iconColor: AppColors.accentBlue, label: "Name", value: viewModel.profileName)

                // Gender
                HealthProfileRow(icon: "person.2.fill", iconColor: AppColors.accentBlue, label: "Gender", value: viewModel.profileGender)

                // Age
                HealthProfileRow(icon: "calendar", iconColor: AppColors.accentBlue, label: "Age", value: viewModel.profileAge)

                // Height
                HealthProfileRow(icon: "ruler.fill", iconColor: AppColors.accentBlue, label: "Height", value: viewModel.profileHeight)

                // Weight
                HealthProfileRow(icon: "scalemass.fill", iconColor: AppColors.accentBlue, label: "Weight", value: viewModel.profileWeight)

                // BMI
                HealthProfileRow(icon: "figure.stand", iconColor: AppColors.accentBlue, label: "BMI", value: viewModel.profileBMI)

                // Blood Type
                if viewModel.profileBloodType != "Not set" {
                    HealthProfileRow(icon: "drop.fill", iconColor: AppColors.accentBlue, label: "Blood Type", value: viewModel.profileBloodType)
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
    
    // MARK: - Family Section
    
    private var familySection: some View {
        Section {
            NavigationLink(destination: FamilyView()) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accentBlue.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "person.3.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.accentBlue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Family")
                            .font(.headline)
                        
                        Text("Manage family members' health")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        } header: {
            Text("Family")
        } footer: {
            Text("Track and manage health profiles for your family members")
                .font(.caption)
        }
    }
    
    private var goalsSection: some View {
        Section {
            NavigationLink(destination: GoalsSettingsView()) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accentBlue.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "target")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.accentBlue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Goals")
                            .font(.headline)

                        Text("Steps, diet, hydration & more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        } header: {
            Text("Goals")
        } footer: {
            Text("Set daily targets for activity, nutrition and hydration")
                .font(.caption)
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
                Spacer()
                Text("\(hydrationViewModel.dailyGoal) ml")
                    .foregroundColor(.secondary)
            }
            
            // Hydration Settings
            Button(action: { activeSheet = .hydrationSettings }) {
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
    }
    
    private var settingsSection: some View {
        Section {
            NavigationLink(destination: RemindersSettingsView()) {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reminders & Notifications")
                                .foregroundColor(.primary)
                            Text("Hydration, medication, diet, cycle, AI")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(AppColors.accentBlue)
                    }
                }
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

            // Dynamic Island toggle
            HStack {
                Label("Dynamic Island", systemImage: "antenna.radiowaves.left.and.right")
                Spacer()
                if HealthLiveActivityManager.shared.isActive {
                    Text("ON")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }
                Toggle("", isOn: Binding(
                    get: { HealthLiveActivityManager.shared.isActive },
                    set: { newValue in
                        Task {
                            if newValue {
                                await HealthLiveActivityManager.shared.startHealthTracking(userName: viewModel.userName ?? "User")
                            } else {
                                await HealthLiveActivityManager.shared.endHealthTracking()
                            }
                        }
                    }
                ))
                .labelsHidden()
            }

            // App Version Row - always visible
            appVersionRow
        } header: {
            Text("Settings")
        }
    }
    
    // MARK: - App Version Row
    
    private var appVersionRow: some View {
        Button(action: {
            if appVersionService.updateStatus.hasUpdate {
                activeSheet = .appUpdate
            }
        }) {
            HStack {
                Label {
                    Text("App Version")
                } icon: {
                    Image(systemName: appVersionService.updateStatus.hasUpdate ? "arrow.down.app.fill" : "app.badge.checkmark.fill")
                        .foregroundColor(AppColors.accentBlue)
                }
                
                Spacer()
                
                // Version text
                Text(viewModel.appVersion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Update indicator
                if appVersionService.updateStatus.hasUpdate {
                    Text("Update")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "11998e"), Color(hex: "38ef7d")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .foregroundColor(.primary)
        .disabled(!appVersionService.updateStatus.hasUpdate)
    }
    
    @ViewBuilder
    private var signOutSection: some View {
        Section {
            Button(action: {
                viewModel.showSignOutConfirmation = true
            }) {
                if viewModel.isLoading {
                    HStack {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                }
            }
            .disabled(viewModel.isLoading)
            
            Button(action: {
                viewModel.showDeleteAccountConfirmation = true
            }) {
                Label("Delete Account", systemImage: "trash.fill")
                    .foregroundColor(.red)
            }
            .disabled(viewModel.isLoading)
        } footer: {
            Text("Permanently delete your account and all associated data.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var versionFooter: some View {
        VStack(spacing: 8) {
            Text("Version \(viewModel.appVersion)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button(action: {
                    activeSheet = .terms
                }) {
                    Text("Terms & Conditions")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    activeSheet = .privacy
                }) {
                    Text("Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppVersionService.shared)
    }
}
