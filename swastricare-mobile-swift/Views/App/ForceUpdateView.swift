//
//  ForceUpdateView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//  Displays force update or optional update prompts
//

import SwiftUI

// MARK: - Force Update View

struct ForceUpdateView: View {
    
    @ObservedObject var appVersionService: AppVersionService
    @Environment(\.colorScheme) var colorScheme
    
    let onSkip: (() -> Void)?
    
    @State private var isAnimating = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    private var isForced: Bool {
        if case .forceUpdateRequired = appVersionService.updateStatus {
            return true
        }
        return false
    }
    
    private var latestVersion: String {
        switch appVersionService.updateStatus {
        case .forceUpdateRequired(let version), .updateAvailable(let version, _):
            return version
        default:
            return appVersionService.versionInfo?.latestVersion ?? "Unknown"
        }
    }
    
    var body: some View {
        ZStack {
            // Premium Background
            PremiumBackground()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Update Icon
                updateIcon
                
                // Title & Message
                titleSection
                
                // Version Info
                versionInfoSection
                
                Spacer()
                
                // Action Buttons
                actionButtons
                
                // Skip option (only for optional updates)
                if !isForced, let skip = onSkip {
                    skipButton(action: skip)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            isAnimating = true
        }
    }
    
    // MARK: - Update Icon
    
    private var updateIcon: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: isForced ? [
                            Color(hex: "FF512F").opacity(0.3),
                            Color.clear
                        ] : [
                            Color(hex: "2E3192").opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 120
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Icon background
            RoundedRectangle(cornerRadius: 40)
                .fill(Material.ultraThinMaterial)
                .frame(width: 120, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 40)
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.2)
                                : Color.black.opacity(0.1),
                            lineWidth: 0.5
                        )
                )
            
            // Icon
            Image(systemName: isForced ? "exclamationmark.arrow.circlepath" : "arrow.down.app.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: isForced
                            ? [Color(hex: "FF512F"), Color(hex: "DD2476")]
                            : [Color(hex: "2E3192"), Color(hex: "1BFFFF")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .scaleEffect(scale)
        .opacity(opacity)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text(appVersionService.versionInfo?.updateTitle ?? (isForced ? "Update Required" : "Update Available"))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? .primary : Color(hex: "2E3192"))
                .multilineTextAlignment(.center)
            
            Text(appVersionService.versionInfo?.updateMessage ?? defaultMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
        }
        .opacity(opacity)
    }
    
    private var defaultMessage: String {
        if isForced {
            return "A critical update is required to continue using Swastricare. Please update to the latest version for the best experience."
        } else {
            return "A new version of Swastricare is available with improvements and bug fixes."
        }
    }
    
    // MARK: - Version Info Section
    
    private var versionInfoSection: some View {
        HStack(spacing: 24) {
            versionBadge(
                label: "Current",
                version: appVersionService.currentVersion,
                isHighlighted: false
            )
            
            Image(systemName: "arrow.right")
                .font(.title2)
                .foregroundColor(.secondary)
            
            versionBadge(
                label: "Latest",
                version: latestVersion,
                isHighlighted: true
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.1)
                                : Color.black.opacity(0.05),
                            lineWidth: 0.5
                        )
                )
        )
        .opacity(opacity)
    }
    
    private func versionBadge(label: String, version: String, isHighlighted: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text("v\(version)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(isHighlighted ? Color(hex: "11998e") : .primary)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        Button(action: {
            appVersionService.openAppStore()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.app.fill")
                Text("Update Now")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isForced
                        ? [Color(hex: "FF512F"), Color(hex: "DD2476")]
                        : [Color(hex: "2E3192"), Color(hex: "1BFFFF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .opacity(opacity)
    }
    
    private func skipButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Maybe Later")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
        .opacity(opacity)
    }
}

// MARK: - Optional Update Alert Modifier

struct OptionalUpdateAlertModifier: ViewModifier {
    @ObservedObject var appVersionService: AppVersionService
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ForceUpdateView(
                    appVersionService: appVersionService,
                    onSkip: { isPresented = false }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
    let service = AppVersionService.shared
    ForceUpdateView(appVersionService: service, onSkip: nil)
}

#Preview("Optional Update") {
    let service = AppVersionService.shared
    ForceUpdateView(appVersionService: service, onSkip: { print("Skipped") })
}
