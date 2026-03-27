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
    @StateObject private var hydrationViewModel = HydrationViewModel()
    @EnvironmentObject private var appVersionService: AppVersionService
    @EnvironmentObject private var deepLinkHandler: DeepLinkHandler
    
    // MARK: - State
    
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var activeSheet: ProfileSheet?
    @State private var showFamilyFromDeepLink = false
    @State private var deepLinkInviteCode: String?
    @State private var showAccountView = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            PremiumBackground()
            
            List {
                profileHeader
                
                if !viewModel.hasPhone && viewModel.user != nil {
                    phoneMissingBanner
                }
                
                accountSection
                
                if viewModel.hasHealthProfile {
                    quickStatsSection
                }
                
                hydrationSection

                healthDataSection

                settingsSection
                
                signOutSection
                
                Section {
                    EmptyView()
                } footer: {
                    versionFooter
                }
            }
            .scrollContentBackground(.hidden)
            .navigationDestination(isPresented: $showAccountView) {
                AccountView()
            }
        }
        .onAppear {
            AppAnalyticsService.shared.logScreen("Profile")
        }
        .navigationDestination(isPresented: $showFamilyFromDeepLink) {
            FamilyView(initialInviteCode: deepLinkInviteCode ?? deepLinkHandler.pendingFamilyInviteCode)
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkFamilyJoin)) { notification in
            if let code = notification.userInfo?[DeepLinkUserInfoKey.familyInviteCode] as? String, !code.isEmpty {
                deepLinkInviteCode = code
                deepLinkHandler.pendingFamilyInviteCode = code
                showFamilyFromDeepLink = true
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
    }
    
    // MARK: - Sheet Type
    
    enum ProfileSheet: Identifiable {
        case terms, privacy, hydrationSettings, appUpdate
        
        var id: String {
            switch self {
            case .terms: return "terms"
            case .privacy: return "privacy"
            case .hydrationSettings: return "hydrationSettings"
            case .appUpdate: return "appUpdate"
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        Section {
            Button(action: { showAccountView = true }) {
                let trimmedBio = viewModel.userBio.trimmingCharacters(in: .whitespacesAndNewlines)
                
                VStack(spacing: 10) {
                    if let avatarURL = viewModel.userAvatarURL {
                        AsyncImage(url: avatarURL) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                        } placeholder: {
                            defaultAvatar
                        }
                    } else {
                        defaultAvatar
                    }
                    
                    VStack(spacing: 2) {
                        Text(viewModel.userName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        if !trimmedBio.isEmpty {
                            Text(trimmedBio)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.top, 4)
                        }
                        
                        Text("Member since \(viewModel.memberSince)")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.top, trimmedBio.isEmpty ? 4 : 8)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Text("Tap to edit profile")
                    //     .font(.caption2)
                    //     .fontWeight(.medium)
                    //     .foregroundColor(Color(hex: "2E3192"))
                    //     .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
            .frame(width: 90, height: 90)
            .overlay(
                Text(String(viewModel.userName.prefix(1)).uppercased())
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            )
            .shadow(color: Color(hex: "2E3192").opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Phone Missing Banner
    
    private var phoneMissingBanner: some View {
        Section {
            Button(action: { showAccountView = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "phone.badge.plus")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add your phone number")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Keep your account secure")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .listRowBackground(Color.orange.opacity(0.06))
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section {
            Button(action: { showAccountView = true }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "2E3192").opacity(0.2), Color(hex: "4A90E2").opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "person.text.rectangle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account Data")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Edit profile, body stats, location")
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
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        } header: {
            Text("Account")
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsSection: some View {
        Section {
            if viewModel.isLoadingHealthProfile {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            } else {
                VStack(spacing: 12) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        QuickStatCard(
                            icon: "ruler.fill",
                            value: viewModel.profileHeight,
                            label: "Height",
                            color: .green
                        )
                        QuickStatCard(
                            icon: "scalemass.fill",
                            value: viewModel.profileWeight,
                            label: "Weight",
                            color: .cyan
                        )
                        QuickStatCard(
                            icon: "figure.stand",
                            value: viewModel.profileBMI,
                            label: "BMI",
                            color: .indigo
                        )
                    }
                    
                    HStack(spacing: 16) {
                        if viewModel.profileGender != "Not set" {
                            Label(viewModel.profileGender, systemImage: "person.2.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if viewModel.profileAge != "Not set" {
                            Label(viewModel.profileAge, systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if viewModel.profileBloodType != "Not set" {
                            Label(viewModel.profileBloodType, systemImage: "drop.fill")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                        }
                        Spacer()
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
        } header: {
            HStack {
                Text("Quick Stats")
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
    
    // MARK: - Hydration
    
    private var hydrationSection: some View {
        Section("Hydration") {
            HStack {
                Label {
                    Text("Activity Level")
                } icon: {
                    Image(systemName: hydrationViewModel.preferences.activityLevel.icon)
                        .foregroundColor(Color(hex: "F59E0B"))
                }
                Spacer()
                Text(hydrationViewModel.preferences.activityLevel.displayName)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label {
                    Text("Daily Goal")
                } icon: {
                    Image(systemName: "drop.fill")
                        .foregroundColor(Color(hex: "06B6D4"))
                }
                Spacer()
                Text("\(hydrationViewModel.dailyGoal) ml")
                    .foregroundColor(.secondary)
            }

            Button(action: { activeSheet = .hydrationSettings }) {
                HStack {
                    Label {
                        Text("Hydration Preferences")
                    } icon: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(Color(hex: "64748B"))
                    }
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
    }
    
    // MARK: - Health Data

    private var healthDataSection: some View {
        Section {
            NavigationLink {
                HealthDataSettingsView()
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health")
                                .foregroundColor(.primary)
                            Text("Manage health data permissions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
        } header: {
            Text("Health Data")
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        Section {
            NavigationLink {
                ThemeSettingsView()
            } label: {
                HStack {
                    Label {
                        Text("Theme")
                    } icon: {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "7C3AED"), Color(hex: "A78BFA")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    Spacer()
                    Text(themeManager.currentTheme.displayName)
                        .foregroundColor(.secondary)
                }
            }

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
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }

            HStack {
                Label {
                    Text(viewModel.biometricTypeName)
                } icon: {
                    Image(systemName: viewModel.biometricIcon)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "0EA5E9"), Color(hex: "38BDF8")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                Spacer()
                if viewModel.isTogglingBiometric {
                    ProgressView().scaleEffect(0.8)
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
                        .foregroundStyle(
                            appVersionService.updateStatus.hasUpdate
                                ? LinearGradient(
                                    colors: [Color(hex: "11998e"), Color(hex: "38ef7d")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color(hex: "2E3192"), Color(hex: "654ea3")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                }
                
                Spacer()
                
                Text(viewModel.appVersion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if appVersionService.updateStatus.hasUpdate {
                    Text("Update")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color(hex: "11998e"), Color(hex: "38ef7d")],
                                    startPoint: .leading, endPoint: .trailing
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
    
    // MARK: - Sign Out
    
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
    
    // MARK: - Footer
    
    private var versionFooter: some View {
        VStack(spacing: 8) {
            Text("Version \(viewModel.appVersion)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button(action: { activeSheet = .terms }) {
                    Text("Terms & Conditions")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text("•").font(.caption).foregroundColor(.secondary)
                
                Button(action: { activeSheet = .privacy }) {
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

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Health Profile Row (kept for backward compatibility with SettingsView)

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

// ShimmerModifier moved to DesignSystem.swift

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppVersionService.shared)
    }
}
