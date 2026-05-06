//
//  ProfileView.swift
//  swastricare-mobile-swift
//
//  Android-parity Settings screen.
//

import SwiftUI

struct ProfileView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel = DependencyContainer.shared.profileViewModel
    @EnvironmentObject private var appVersionService: AppVersionService
    @EnvironmentObject private var deepLinkHandler: DeepLinkHandler
    @Environment(\.openURL) private var openURL

    // MARK: - State

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var activeSheet: ProfileSheet?
    @State private var showAccountView = false
    @State private var showHealthDataSync = false
    @State private var showRemindersSettings = false
    @State private var showActivityGoals = false
    @State private var showFamilyComingSoon = false
    @State private var showAboutComingSoon = false
    @State private var showFamilyFromDeepLink = false
    @State private var deepLinkInviteCode: String?

    // MARK: - Tokens (match Android)

    private let aiTeal = Color(hex: "22C5A6")
    private let cardBorder = Color(hex: "E6E8EB")
    private let bannerStart = Color(hex: "D9F0E4")
    private let bannerEnd = Color(hex: "C2E0EE")
    private let bannerInk = Color(hex: "0F2027")

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    titleBlock
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 16)

                    profileBanner
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)

                    sectionLabel("Account")
                    accountCard

                    sectionLabel("Preferences")
                    preferencesCard

                    sectionLabel("Support")
                    supportCard

                    Spacer().frame(height: 20)

                    logOutCard

                    footerLinks
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .trackScreen("Profile")
        .navigationDestination(isPresented: $showAccountView) { AccountView() }
        .navigationDestination(isPresented: $showHealthDataSync) { HealthDataSettingsView() }
        .navigationDestination(isPresented: $showRemindersSettings) { RemindersSettingsView() }
        .navigationDestination(isPresented: $showActivityGoals) { GoalsSettingsView() }
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
        .alert("Sign Out", isPresented: $viewModel.showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Family", isPresented: $showFamilyComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Coming soon")
        }
        .alert("About", isPresented: $showAboutComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Coming soon")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .terms: TermsContentView()
            case .privacy: PrivacyContentView()
            case .appUpdate: ForceUpdateView(appVersionService: appVersionService, onSkip: { activeSheet = nil })
            }
        }
    }

    enum ProfileSheet: Identifiable {
        case terms, privacy, appUpdate
        var id: String {
            switch self {
            case .terms: return "terms"
            case .privacy: return "privacy"
            case .appUpdate: return "appUpdate"
            }
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.poppins(.bold, size: 28))
                .foregroundColor(.primary)
            Text("Manage your profile and preferences")
                .font(.poppins(.regular, size: 13))
                .foregroundColor(.primary.opacity(0.5))
        }
    }

    // MARK: - Profile Banner

    private var profileBanner: some View {
        Button(action: { showAccountView = true }) {
            ZStack(alignment: .trailing) {
                LinearGradient(
                    colors: [bannerStart, bannerEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                MountainsBackdrop()
                    .frame(width: 140)
                    .frame(maxHeight: .infinity)

                HStack(spacing: 12) {
                    bannerAvatar
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bannerName)
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundColor(bannerInk)
                            .lineLimit(1)
                        Text(viewModel.userEmail)
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(bannerInk.opacity(0.6))
                            .lineLimit(1)
                        Spacer().frame(height: 2)
                        activeBadge
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(bannerInk.opacity(0.5))
                }
                .padding(.horizontal, 14)
            }
            .frame(height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var bannerName: String {
        let name = viewModel.userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Set up your profile" : name
    }

    private var bannerAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 56, height: 56)
            if let url = viewModel.userAvatarURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    initialAvatar(size: 52)
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
            } else {
                initialAvatar(size: 52)
            }
        }
    }

    private func initialAvatar(size: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.aiTeal, Color(hex: "4A90E2")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(Circle())
            Text(String(viewModel.userName.prefix(1)).uppercased())
                .font(.poppins(.bold, size: size * 0.4))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }

    private var activeBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(AppColors.accentGreen)
                .frame(width: 6, height: 6)
            Text(activeBadgeText)
                .font(.poppins(.medium, size: 11))
                .foregroundColor(bannerInk.opacity(0.7))
        }
    }

    private var activeBadgeText: String {
        let days = daysActive
        return days <= 0 ? "Active today" : "Active for \(days) days"
    }

    private var daysActive: Int {
        guard let createdAt = viewModel.user?.createdAt else { return 0 }
        let diff = Date().timeIntervalSince(createdAt)
        return max(0, Int(diff / 86400))
    }

    // MARK: - Cards

    private var accountCard: some View {
        SettingsCard {
            SettingsRow(
                icon: "person",
                label: "Personal Information",
                subtitle: "Update your personal details",
                tint: aiTeal
            ) { showAccountView = true }
            RowDivider()
            SettingsRow(
                icon: "person.2",
                label: "Family",
                subtitle: "Manage your family group",
                value: "Coming soon",
                tint: aiTeal
            ) { showFamilyComingSoon = true }
            RowDivider()
            SettingsRow(
                icon: "heart",
                label: "Health Data Sync",
                subtitle: "Apple Health, devices & more",
                tint: aiTeal
            ) { showHealthDataSync = true }
        }
    }

    private var preferencesCard: some View {
        SettingsCard {
            SettingsRow(
                icon: "bell",
                label: "Notifications",
                subtitle: "Customize your notification settings",
                tint: aiTeal
            ) { showRemindersSettings = true }
            RowDivider()
            SettingsRow(
                icon: "flag",
                label: "Activity Goals",
                subtitle: "Set daily steps, distance & calorie goals",
                tint: aiTeal
            ) { showActivityGoals = true }
            RowDivider()
            SettingsToggleRow(
                icon: viewModel.biometricIcon,
                label: "Biometric Lock",
                isOn: viewModel.biometricEnabled,
                isLoading: viewModel.isTogglingBiometric,
                tint: aiTeal
            ) {
                Task { await viewModel.toggleBiometric() }
            }
        }
    }

    private var supportCard: some View {
        SettingsCard {
            SettingsRow(
                icon: "bubble.left.and.bubble.right",
                label: "Contact Us",
                subtitle: "Get in touch with our support team",
                tint: aiTeal
            ) {
                if let url = URL(string: "https://swastricare.com") {
                    openURL(url)
                }
            }
            RowDivider()
            SettingsRow(
                icon: "info.circle",
                label: "About",
                subtitle: "Version \(viewModel.appVersion)",
                tint: aiTeal
            ) { showAboutComingSoon = true }
        }
    }

    private var logOutCard: some View {
        SettingsCard {
            LogOutRow(isLoading: viewModel.isLoading) {
                viewModel.showSignOutConfirmation = true
            }
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: 8) {
            Text("Version \(viewModel.appVersion)")
                .font(.poppins(.regular, size: 12))
                .foregroundColor(.primary.opacity(0.5))

            HStack(spacing: 12) {
                Button(action: { activeSheet = .terms }) {
                    Text("Terms of Service")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(aiTeal)
                }
                Text("•")
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.primary.opacity(0.5))
                Button(action: { activeSheet = .privacy }) {
                    Text("Privacy Policy")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(aiTeal)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.poppins(.semiBold, size: 11))
            .tracking(0.8)
            .foregroundColor(.primary.opacity(0.4))
            .padding(.leading, 24)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }
}

// MARK: - Mountains backdrop (Canvas)

private struct MountainsBackdrop: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // Sun
            let sunRadius = h * 0.11
            let sunCenter = CGPoint(x: w * 0.55, y: h * 0.32)
            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: sunCenter.x - sunRadius,
                    y: sunCenter.y - sunRadius,
                    width: sunRadius * 2,
                    height: sunRadius * 2
                )),
                with: .color(Color(hex: "FFE6A8"))
            )

            // Back mountain
            var back = Path()
            back.move(to: CGPoint(x: w * 0.20, y: h))
            back.addLine(to: CGPoint(x: w * 0.55, y: h * 0.30))
            back.addLine(to: CGPoint(x: w * 0.85, y: h))
            back.closeSubpath()
            ctx.fill(back, with: .color(.white.opacity(0.55)))

            // Front mountain
            var front = Path()
            front.move(to: CGPoint(x: w * 0.45, y: h))
            front.addLine(to: CGPoint(x: w * 0.78, y: h * 0.42))
            front.addLine(to: CGPoint(x: w, y: h))
            front.closeSubpath()
            ctx.fill(front, with: .color(.white.opacity(0.85)))

            // Snow cap
            var cap = Path()
            cap.move(to: CGPoint(x: w * 0.74, y: h * 0.50))
            cap.addLine(to: CGPoint(x: w * 0.78, y: h * 0.42))
            cap.addLine(to: CGPoint(x: w * 0.82, y: h * 0.50))
            cap.addLine(to: CGPoint(x: w * 0.80, y: h * 0.55))
            cap.addLine(to: CGPoint(x: w * 0.77, y: h * 0.52))
            cap.closeSubpath()
            ctx.fill(cap, with: .color(Color(hex: "E9F5FA")))

            // Horizon line
            var horizon = Path()
            horizon.move(to: CGPoint(x: 0, y: h * 0.78))
            horizon.addLine(to: CGPoint(x: w, y: h * 0.78))
            ctx.stroke(horizon, with: .color(.white.opacity(0.4)), lineWidth: 1)
        }
    }
}

// MARK: - Card / row building blocks

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "E6E8EB"), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

private struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 64)
    }
}

private struct IconBadge: View {
    let icon: String
    var tint: Color = .primary.opacity(0.75)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.clear)
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(tint)
        }
        .frame(width: 36, height: 36)
    }
}

private struct SettingsRow: View {
    let icon: String
    let label: String
    var subtitle: String? = nil
    var value: String? = nil
    var tint: Color = .primary.opacity(0.75)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconBadge(icon: icon, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.poppins(.medium, size: 15))
                        .foregroundColor(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(.primary.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if let value = value {
                    Text(value)
                        .font(.poppins(.regular, size: 13))
                        .foregroundColor(.primary.opacity(0.5))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let label: String
    let isOn: Bool
    var isLoading: Bool = false
    var tint: Color = .primary.opacity(0.75)
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(icon: icon, tint: tint)
            Text(label)
                .font(.poppins(.medium, size: 15))
                .foregroundColor(.primary)
            Spacer(minLength: 8)
            if isLoading {
                ProgressView().scaleEffect(0.8)
            } else {
                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .tint(AppColors.accentGreen)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

private struct LogOutRow: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.red.opacity(0.10))
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.red)
                }
                .frame(width: 36, height: 36)

                Text("Log Out")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(.red)

                Spacer(minLength: 8)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.red)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
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

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppVersionService.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(DeepLinkHandler())
    }
}
