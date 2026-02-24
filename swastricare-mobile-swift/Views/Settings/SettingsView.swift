//
//  SettingsView.swift
//  swastricare-mobile-swift
//
//  Modern Settings Screen with Movements+ Design System
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = DependencyContainer.shared.profileViewModel
    @StateObject private var hydrationViewModel = HydrationViewModel()
    @EnvironmentObject private var appVersionService: AppVersionService
    
    @AppStorage(AppConfig.appThemeKey) private var appThemeRaw: String = AppTheme.system.rawValue
    
    @State private var isLoading = false
    @State private var loadingProgress: Double = 0.0
    @State private var loadingMessage: String = "Loading settings..."
    @State private var activeSheet: ProfileSheet?
    @State private var hasAppeared = false
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.top, 8)
                        
                        profileHeaderSection
                            .padding(.top, 24)
                        
                        quickActionsSection
                            .padding(.top, 24)
                        
                        healthProfileSection
                            .padding(.top, 24)
                        
                        preferencesSection
                            .padding(.top, 24)
                        
                        accountSection
                            .padding(.top, 24)
                        
                        footerSection
                            .padding(.top, 32)
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Sign Out", isPresented: $viewModel.showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $viewModel.showDeleteAccountConfirmation) {
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
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(UIColor.systemBackground)
    }
    
    // MARK: - Loading
    
    private func loadSettings() async {
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
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(MovementsColors.limeGreen.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 50))
                    .foregroundColor(MovementsColors.limeGreen)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            VStack(spacing: 12) {
                Text(loadingMessage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("\(Int(loadingProgress * 100))%")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(MovementsColors.limeGreen)
                        .frame(width: geometry.size.width * loadingProgress, height: 6)
                        .animation(.linear(duration: 0.2), value: loadingProgress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(MovementsColors.card(for: colorScheme))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            Text("Settings")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Circle()
                .fill(Color.clear)
                .frame(width: 44, height: 44)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -20)
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [MovementsColors.limeGreen.opacity(0.3), Color(hex: "4ECDC4").opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                
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
            }
            
            VStack(spacing: 8) {
                Text(viewModel.userName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(viewModel.userEmail)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text("Member since \(viewModel.memberSince)")
                        .font(.system(size: 12))
                }
                .foregroundColor(MovementsColors.limeGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(MovementsColors.limeGreen.opacity(0.15))
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(MovementsColors.card(for: colorScheme))
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: hasAppeared)
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [MovementsColors.limeGreen, Color(hex: "4ECDC4")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 100, height: 100)
            .overlay(
                Text(String(viewModel.userName.prefix(1)).uppercased())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.black)
            )
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            HStack(spacing: 12) {
                QuickActionCard(
                    icon: "person.3.fill",
                    title: "Family",
                    subtitle: "Manage",
                    color: Color(hex: "FF6B6B"),
                    colorScheme: colorScheme
                ) {
                    // Navigate to Family
                }
                
                QuickActionCard(
                    icon: "drop.fill",
                    title: "Hydration",
                    subtitle: "Settings",
                    color: Color(hex: "5AC8FA"),
                    colorScheme: colorScheme
                ) {
                    activeSheet = .hydrationSettings
                }
                
                QuickActionCard(
                    icon: "bell.fill",
                    title: "Alerts",
                    subtitle: viewModel.notificationsEnabled ? "On" : "Off",
                    color: Color(hex: "FF9500"),
                    colorScheme: colorScheme
                ) {
                    viewModel.notificationsEnabled.toggle()
                }
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
    }
    
    // MARK: - Health Profile Section
    
    private var healthProfileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Health Profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.hasHealthProfile && !viewModel.isLoadingHealthProfile {
                    Button {
                        Task { await viewModel.refreshHealthProfile() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                            Text("Refresh")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(MovementsColors.limeGreen)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                if viewModel.isLoadingHealthProfile {
                    ForEach(0..<4, id: \.self) { index in
                        HealthProfileShimmerRow()
                        if index < 3 {
                            Divider()
                                .background(Color.primary.opacity(0.1))
                        }
                    }
                } else if viewModel.hasHealthProfile {
                    SettingsHealthRow(icon: "person.fill", iconColor: MovementsColors.limeGreen, label: "Name", value: viewModel.profileName, isFirst: true)
                    Divider().background(Color.primary.opacity(0.1))
                    SettingsHealthRow(icon: "figure.stand", iconColor: Color(hex: "AF52DE"), label: "Gender", value: viewModel.profileGender)
                    Divider().background(Color.primary.opacity(0.1))
                    SettingsHealthRow(icon: "calendar", iconColor: Color(hex: "FF9500"), label: "Age", value: viewModel.profileAge)
                    Divider().background(Color.primary.opacity(0.1))
                    SettingsHealthRow(icon: "ruler.fill", iconColor: Color(hex: "34C759"), label: "Height", value: viewModel.profileHeight)
                    Divider().background(Color.primary.opacity(0.1))
                    SettingsHealthRow(icon: "scalemass.fill", iconColor: Color(hex: "5AC8FA"), label: "Weight", value: viewModel.profileWeight)
                    Divider().background(Color.primary.opacity(0.1))
                    SettingsHealthRow(icon: "heart.fill", iconColor: Color(hex: "FF2D55"), label: "BMI", value: viewModel.profileBMI, isLast: true)
                } else {
                    noHealthProfileView
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(MovementsColors.card(for: colorScheme))
            )
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
    }
    
    private var noHealthProfileView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(MovementsColors.limeGreen.opacity(0.15))
                    .frame(width: 70, height: 70)
                
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 32))
                    .foregroundColor(MovementsColors.limeGreen)
            }
            
            VStack(spacing: 6) {
                Text("No health profile found")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Complete your health profile during onboarding")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    // MARK: - Preferences Section
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                // Appearance
                SettingsCustomRow(
                    icon: "circle.lefthalf.filled",
                    iconColor: Color(hex: "5856D6"),
                    title: "Appearance",
                    subtitle: AppTheme(rawValue: appThemeRaw)?.displayName ?? "System",
                    isFirst: true
                ) {
                    Menu {
                        ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                            Button {
                                appThemeRaw = theme.rawValue
                            } label: {
                                Label(theme.displayName, systemImage: theme.iconName)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(AppTheme(rawValue: appThemeRaw)?.displayName ?? "System")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                        )
                    }
                }
                
                Divider().background(Color.primary.opacity(0.1))
                
                // Biometric
                SettingsSwitchRow(
                    icon: viewModel.biometricIcon,
                    iconColor: Color(hex: "34C759"),
                    title: viewModel.biometricTypeName,
                    isOn: Binding(
                        get: { viewModel.biometricEnabled },
                        set: { _ in Task { await viewModel.toggleBiometric() } }
                    ),
                    isLoading: viewModel.isTogglingBiometric
                )
                
                Divider().background(Color.primary.opacity(0.1))
                
                // Health Sync
                SettingsSwitchRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: Color(hex: "FF9500"),
                    title: "Auto Sync Health",
                    isOn: $viewModel.healthSyncEnabled,
                    isLast: true
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(MovementsColors.card(for: colorScheme))
            )
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                // App Version
                appVersionRow
                
                Divider().background(Color.primary.opacity(0.1))
                
                // Terms
                SettingsNavigationRow(
                    icon: "doc.text.fill",
                    iconColor: Color(hex: "5AC8FA"),
                    title: "Terms & Conditions"
                ) {
                    activeSheet = .terms
                }
                
                Divider().background(Color.primary.opacity(0.1))
                
                // Privacy
                SettingsNavigationRow(
                    icon: "hand.raised.fill",
                    iconColor: Color(hex: "AF52DE"),
                    title: "Privacy Policy"
                ) {
                    activeSheet = .privacy
                }
                
                Divider().background(Color.primary.opacity(0.1))
                
                // Sign Out
                SettingsActionRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    iconColor: Color(hex: "FF3B30"),
                    title: "Sign Out",
                    isDestructive: true,
                    isLoading: viewModel.isLoading
                ) {
                    viewModel.showSignOutConfirmation = true
                }
                
                Divider().background(Color.primary.opacity(0.1))
                
                // Delete Account
                SettingsActionRow(
                    icon: "trash.fill",
                    iconColor: Color(hex: "FF3B30"),
                    title: "Delete Account",
                    isDestructive: true,
                    isLast: true
                ) {
                    viewModel.showDeleteAccountConfirmation = true
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(MovementsColors.card(for: colorScheme))
            )
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
    }
    
    private var appVersionRow: some View {
        Button(action: {
            if appVersionService.updateStatus.hasUpdate {
                activeSheet = .appUpdate
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            appVersionService.updateStatus.hasUpdate
                                ? Color(hex: "34C759").opacity(0.15)
                                : MovementsColors.limeGreen.opacity(0.15)
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: appVersionService.updateStatus.hasUpdate ? "arrow.down.app.fill" : "app.badge.checkmark.fill")
                        .font(.system(size: 18))
                        .foregroundColor(
                            appVersionService.updateStatus.hasUpdate
                                ? Color(hex: "34C759")
                                : MovementsColors.limeGreen
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Version")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(viewModel.appVersion)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if appVersionService.updateStatus.hasUpdate {
                    Text("Update Available")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color(hex: "34C759"))
                        )
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .disabled(!appVersionService.updateStatus.hasUpdate)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "FF2D55"))
                
                Text("Made with care for your health")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Text("Version \(viewModel.appVersion)")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: hasAppeared)
    }
}

// MARK: - Quick Action Card

private struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(MovementsColors.card(for: colorScheme))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Settings Health Row

private struct SettingsHealthRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var isFirst: Bool = false
    var isLast: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Health Profile Shimmer Row

private struct HealthProfileShimmerRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 36, height: 36)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 14)
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 60, height: 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .shimmering()
    }
}

// MARK: - Settings Custom Row

private struct SettingsCustomRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var isFirst: Bool = false
    var isLast: Bool = false
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Settings Switch Row

private struct SettingsSwitchRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool
    var isLoading: Bool = false
    var isFirst: Bool = false
    var isLast: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(MovementsColors.limeGreen)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Settings Navigation Row

private struct SettingsNavigationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Settings Action Row

private struct SettingsActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var isDestructive: Bool = false
    var isLoading: Bool = false
    var isLast: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isDestructive ? iconColor : .primary)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .disabled(isLoading)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppVersionService.shared)
    }
}
