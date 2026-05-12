//
//  ForceUpdateView.swift
//  swastricare-mobile-swift
//
//  Update Required / Update Available presentations. Mirrors the redesigned
//  Android screens — pure white surface, AITeal accent, leafy hero + bottom
//  band, three benefit rows. ForceUpdateView is the blocking full-screen.
//  OptionalUpdateCard is the dismissible sheet card.
//

import SwiftUI

// MARK: - Force Update View (blocking full screen)

struct ForceUpdateView: View {

    @ObservedObject var appVersionService: AppVersionService

    /// When provided, the "Not Now" link is shown. Used by callers that want a
    /// non-blocking variant; the navigation root keeps this nil for true force
    /// updates so back gestures cannot escape the screen.
    let onSkip: (() -> Void)?

    private var resolvedTitle: String {
        appVersionService.versionInfo?.updateTitle ?? "Update Required"
    }

    private var resolvedMessage: String {
        appVersionService.versionInfo?.updateMessage
            ?? "A new version of the app is available. Update now to continue using all features and improvements."
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Decorative leafy band at the bottom
            VStack {
                Spacer()
                Image("update-bottom")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .bottom)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 8)

                    Image("update-hero")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)

                    Spacer().frame(height: 8)

                    Text(resolvedTitle)
                        .font(.poppins(.bold, size: 26))
                        .foregroundColor(Color(hex: "0F172A"))
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 10)

                    Text(resolvedMessage)
                        .font(.poppins(.regular, size: 14))
                        .foregroundColor(Color(hex: "64748B"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .lineSpacing(4)

                    Spacer().frame(height: 28)

                    VStack(spacing: 18) {
                        UpdateBenefitRow(
                            systemImage: "shield",
                            title: "Better Performance",
                            subtitle: "Faster and more reliable experience"
                        )
                        UpdateBenefitRow(
                            systemImage: "star",
                            title: "New Features",
                            subtitle: "Exciting features and improvements"
                        )
                        UpdateBenefitRow(
                            systemImage: "lock",
                            title: "Enhanced Security",
                            subtitle: "Stronger protection for your data"
                        )
                    }

                    Spacer().frame(height: 40)

                    Button(action: { appVersionService.openAppStore() }) {
                        Text("Update Now")
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(AppColors.aiTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    if let onSkip {
                        Button(action: onSkip) {
                            Text("Not Now")
                                .font(.poppins(.medium, size: 14))
                                .foregroundColor(Color(hex: "64748B"))
                                .padding(8)
                        }
                        .padding(.top, 6)
                    }

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 24)
            }
        }
        .trackScreen("ForceUpdate")
    }
}

// MARK: - Optional Update Card (sheet)

struct OptionalUpdateCard: View {

    @ObservedObject var appVersionService: AppVersionService
    let onDismiss: () -> Void

    private var resolvedTitle: String {
        appVersionService.versionInfo?.updateTitle ?? "Update Available"
    }

    private var resolvedMessage: String {
        let fallback: String
        if let v = appVersionService.versionInfo?.latestVersion {
            fallback = "Version \(v) is available with improvements and bug fixes."
        } else {
            fallback = "A new version is available with improvements and bug fixes."
        }
        return appVersionService.versionInfo?.updateMessage ?? fallback
    }

    var body: some View {
        VStack(spacing: 0) {
            Image("update-hero")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 150)

            Text(resolvedTitle)
                .font(.poppins(.bold, size: 22))
                .foregroundColor(Color(hex: "0F172A"))
                .multilineTextAlignment(.center)

            Spacer().frame(height: 8)

            Text(resolvedMessage)
                .font(.poppins(.regular, size: 14))
                .foregroundColor(Color(hex: "64748B"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)

            Spacer().frame(height: 22)

            Button(action: {
                appVersionService.openAppStore()
                onDismiss()
            }) {
                Text("Update Now")
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColors.aiTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())

            Button(action: onDismiss) {
                Text("Maybe Later")
                    .font(.poppins(.medium, size: 14))
                    .foregroundColor(Color(hex: "64748B"))
                    .padding(.vertical, 10)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .background(Color.white)
        .trackScreen("OptionalUpdate")
    }
}

// MARK: - Benefit Row

private struct UpdateBenefitRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.aiTeal.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppColors.aiTeal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(Color(hex: "0F172A"))
                Text(subtitle)
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(Color(hex: "64748B"))
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Optional Update Alert Modifier

struct OptionalUpdateAlertModifier: ViewModifier {
    @ObservedObject var appVersionService: AppVersionService
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                OptionalUpdateCard(
                    appVersionService: appVersionService,
                    onDismiss: { isPresented = false }
                )
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Color.white)
            }
    }
}

extension View {
    func optionalUpdateAlert(
        appVersionService: AppVersionService,
        isPresented: Binding<Bool>
    ) -> some View {
        modifier(OptionalUpdateAlertModifier(
            appVersionService: appVersionService,
            isPresented: isPresented
        ))
    }
}

// MARK: - Preview

#Preview("Force Update") {
    ForceUpdateView(appVersionService: AppVersionService.shared, onSkip: nil)
}

#Preview("Optional Update Card") {
    OptionalUpdateCard(
        appVersionService: AppVersionService.shared,
        onDismiss: {}
    )
}
