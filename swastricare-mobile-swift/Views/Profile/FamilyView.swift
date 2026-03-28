//
//  FamilyView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit

// MARK: - Family Gradient

private let familyGradient = LinearGradient(
    colors: [Color(hex: "10B981"), Color(hex: "34D399")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// MARK: - Family Hero Illustration

private struct FamilyHeroIllustration: View {
    @State private var floating = false

    var body: some View {
        ZStack {
            // Outer glow orb
            Circle()
                .fill(AppColors.family.opacity(0.15))
                .frame(width: 140, height: 140)
                .blur(radius: 20)

            // Overlapping person circles
            ZStack {
                // Left person
                personCircle(color: Color(hex: "34D399"), size: 52, offset: CGSize(width: -34, height: 8))

                // Right person
                personCircle(color: Color(hex: "059669"), size: 52, offset: CGSize(width: 34, height: 8))

                // Center (front) person — larger, on top
                personCircle(color: AppColors.family, size: 62, offset: .zero)
            }
        }
        .offset(y: floating ? -6 : 0)
        .animation(
            .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
            value: floating
        )
        .onAppear { floating = true }
    }

    private func personCircle(color: Color, size: CGFloat, offset: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(color.opacity(0.6), lineWidth: 1.5))

            Image(systemName: "person.fill")
                .font(.system(size: size * 0.38))
                .foregroundStyle(color)
        }
        .offset(offset)
    }
}

// MARK: - Custom Tab Pill Picker

private struct FamilyTabPicker: View {
    @Binding var selected: FamilyTab

    var body: some View {
        HStack(spacing: 0) {
            tabPill(tab: .create, label: "Create", icon: "plus.circle.fill")
            tabPill(tab: .join,   label: "Join",   icon: "person.badge.plus")
        }
        .padding(4)
        .glass(cornerRadius: 16)
    }

    private func tabPill(tab: FamilyTab, label: String, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                selected = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(selected == tab ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Group {
                    if selected == tab {
                        familyGradient
                    } else {
                        Color.clear
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Styled Text Field

private struct FamilyTextField: View {
    let placeholder: String
    @Binding var text: String
    var isMonospaced: Bool = false
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isFocused: Bool = false
    var trailingButton: AnyView? = nil

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isMonospaced {
                    TextField(placeholder, text: $text)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled()
                } else {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(autocapitalization)
                }
            }
            .padding(.vertical, 13)
            .padding(.leading, 14)
            .padding(.trailing, trailingButton == nil ? 14 : 4)

            if let btn = trailingButton {
                btn
                    .padding(.trailing, 8)
            }
        }
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.family.opacity(isFocused ? 0.7 : 0.25), lineWidth: isFocused ? 1.5 : 1)
        )
    }
}

// MARK: - Gradient Action Button

private struct FamilyActionButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isDisabled {
                        Color.gray.opacity(0.3)
                    } else {
                        familyGradient
                    }
                }
            )
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: isDisabled ? .clear : AppColors.family.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Main View

struct FamilyView: View {
    @EnvironmentObject private var deepLinkHandler: DeepLinkHandler
    @StateObject private var vm = DependencyContainer.shared.familyViewModel

    @State private var selectedTab: FamilyTab = .create
    @State private var familyName: String = ""
    @State private var showCopied = false
    @State private var showLeaveConfirmation = false
    @State private var memberToRemove: FamilyMember?
    @State private var showRemoveConfirmation = false
    @State private var nameFieldFocused = false
    @State private var codeFieldFocused = false

    // Staggered animation
    @State private var animateContent = false
    @State private var animateHero = false
    @State private var animateTitle = false
    @State private var animateSubtitle = false
    @State private var animatePicker = false

    init(initialInviteCode: String? = nil) {
        if let code = initialInviteCode, !code.isEmpty {
            // Will be handled in onAppear
        }
    }

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView {
                VStack(spacing: 20) {
                    if vm.isLoading && !vm.hasFamily {
                        loadingView
                    } else if vm.hasFamily {
                        familyGroupView
                    } else {
                        noFamilyView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Family")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Handle deep link invite code
            if let pending = deepLinkHandler.pendingFamilyInviteCode, !pending.isEmpty {
                vm.joinCode = pending.trimmingCharacters(in: .whitespacesAndNewlines)
                selectedTab = .join
            }
            deepLinkHandler.clearFamilyInviteCode()

            Task {
                await vm.loadFamily()
                triggerEntrance()
            }
        }
        .alert("Leave Family", isPresented: $showLeaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task { await vm.leaveFamily() }
            }
        } message: {
            Text("Are you sure you want to leave this family group? You will lose access to shared health data.")
        }
        .alert("Remove Member", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {
                memberToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let member = memberToRemove {
                    Task { await vm.removeMember(member) }
                }
                memberToRemove = nil
            }
        } message: {
            if let member = memberToRemove {
                Text("Remove \(member.fullName ?? "this member") from the family group?")
            }
        }
        .overlay(alignment: .top) {
            notificationBanner
        }
        .trackScreen("Family")
    }

    // MARK: - Entrance Sequencing

    private func triggerEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            animateHero = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.12)) {
            animateTitle = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.22)) {
            animateSubtitle = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            animatePicker = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
            animateContent = true
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.family)
            Text("Loading family...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - No Family View

    private var noFamilyView: some View {
        VStack(spacing: 24) {
            // Hero illustration
            FamilyHeroIllustration()
                .padding(.top, 16)
                .opacity(animateHero ? 1 : 0)
                .scaleEffect(animateHero ? 1 : 0.6)

            // Title & subtitle
            VStack(spacing: 8) {
                Text("Family Health")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(familyGradient)
                    .opacity(animateTitle ? 1 : 0)
                    .offset(y: animateTitle ? 0 : 14)

                Text("Create a family group or join one to share\nand manage health data together.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(animateSubtitle ? 1 : 0)
                    .offset(y: animateSubtitle ? 0 : 10)
            }

            // Custom tab picker
            FamilyTabPicker(selected: $selectedTab)
                .opacity(animatePicker ? 1 : 0)
                .offset(y: animatePicker ? 0 : 8)

            // Cards
            if selectedTab == .create {
                createFamilyCard
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                joinFamilyCard
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.75), value: selectedTab)
    }

    // MARK: - Create Family Card

    private var createFamilyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header row
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColors.family.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.family)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create Your Family")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Start a group and invite members")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            FamilyTextField(
                placeholder: "Family name (e.g., Sharma Family)",
                text: $familyName,
                autocapitalization: .words,
                isFocused: nameFieldFocused
            )
            .onTapGesture { nameFieldFocused = true }

            FamilyActionButton(
                title: "Create Family",
                isLoading: vm.isLoading,
                isDisabled: familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading
            ) {
                Task { await vm.createFamily(name: familyName) }
            }
        }
        .padding(20)
        .glass()
    }

    // MARK: - Join Family Card

    private var joinFamilyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header row
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColors.family.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.family)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Join a Family")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Enter the code shared by the group owner")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            FamilyTextField(
                placeholder: "Invite code (e.g., ABC12345)",
                text: $vm.joinCode,
                isMonospaced: true,
                autocapitalization: .characters,
                isFocused: codeFieldFocused,
                trailingButton: AnyView(
                    Button {
                        vm.joinCode = (UIPasteboard.general.string ?? "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 13))
                            Text("Paste")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(AppColors.family)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.family.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                )
            )
            .onTapGesture { codeFieldFocused = true }

            FamilyActionButton(
                title: "Join Family",
                isLoading: vm.isJoining,
                isDisabled: vm.joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isJoining
            ) {
                Task { await vm.joinFamily() }
            }
        }
        .padding(20)
        .glass()
    }

    // MARK: - Family Group View (has family)

    private var familyGroupView: some View {
        VStack(spacing: 20) {
            // Group Header
            groupHeaderCard
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : -18)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: animateContent)

            // Invite Section
            inviteCard
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.08), value: animateContent)

            // Members Section
            membersCard
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 25)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.14), value: animateContent)

            // Leave Group Button (not for owner)
            if !vm.isOwner {
                leaveButton
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 30)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.2), value: animateContent)
            }
        }
    }

    // MARK: - Group Header Card

    private var groupHeaderCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Emerald accent bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(familyGradient)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(vm.familyGroup?.name ?? "My Family")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        // Member count badge
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                            Text("\(vm.memberCount) member\(vm.memberCount == 1 ? "" : "s")")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(AppColors.family)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(AppColors.family.opacity(0.12))
                        .clipShape(Capsule())

                        // Role badge
                        if let role = vm.currentMemberRole {
                            HStack(spacing: 4) {
                                Image(systemName: role.icon)
                                    .font(.system(size: 9))
                                Text(role.displayName)
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(role.color)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(role.color.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                // Family icon cluster
                ZStack {
                    Circle()
                        .fill(AppColors.family.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppColors.family)
                }
            }
        }
        .padding(20)
        .glass()
    }

    // MARK: - Invite Card

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Invite Members", systemImage: "envelope.badge.fill")
                .font(.headline)
                .foregroundStyle(AppColors.family)

            if !vm.inviteCode.isEmpty {
                // Code display with green glow
                ZStack {
                    // Subtle glow behind code
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.family.opacity(0.08))
                        .blur(radius: 8)

                    HStack {
                        Text(vm.inviteCode)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .tracking(4)
                            .foregroundStyle(.primary)
                            .shimmer()

                        Spacer()

                        // Copy icon button with checkmark animation
                        Button {
                            UIPasteboard.general.string = vm.inviteCode
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                showCopied = true
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(AppColors.family.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                Image(systemName: showCopied ? "checkmark" : "doc.on.doc.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(showCopied ? .green : AppColors.family)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.65), value: showCopied)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(14)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.family.opacity(0.25), lineWidth: 1)
                    )
                }

                // Share & Regenerate Buttons
                HStack(spacing: 12) {
                    ShareLink(item: vm.shareLink) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Share Link")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(familyGradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: AppColors.family.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        AppAnalyticsService.shared.logFamilyInviteSent()
                    })

                    if vm.isOwner {
                        Button {
                            Task { await vm.regenerateCode() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("New Code")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppColors.family.opacity(0.12))
                            .foregroundStyle(AppColors.family)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            } else {
                Text("No invite code available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .glass()
    }

    // MARK: - Members Card

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Members", systemImage: "person.2.fill")
                .font(.headline)
                .foregroundStyle(AppColors.family)

            if vm.members.isEmpty {
                Text("No members yet. Share your invite code to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(vm.members.enumerated()), id: \.element.id) { index, member in
                    memberRow(member: member, index: index)

                    if index < vm.members.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
        }
        .padding(20)
        .glass()
    }

    // MARK: - Member Row

    private func memberRow(member: FamilyMember, index: Int) -> some View {
        HStack(spacing: 12) {
            // Gradient avatar circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [member.role.color, member.role.color.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: member.role.color.opacity(0.25), radius: 4, x: 0, y: 2)

                Text(memberInitial(member))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Name & badges
            VStack(alignment: .leading, spacing: 4) {
                Text(member.fullName ?? "Unknown")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 6) {
                    // Role pill
                    HStack(spacing: 3) {
                        Image(systemName: member.role.icon)
                            .font(.system(size: 9))
                        Text(member.role.displayName)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(member.role.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(member.role.color.opacity(0.12))
                    .clipShape(Capsule())

                    if let relationship = member.relationship, !relationship.isEmpty {
                        Text(relationship)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Remove button (owner only, can't remove self)
            if vm.isOwner && member.role != .owner {
                Button {
                    memberToRemove = member
                    showRemoveConfirmation = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .opacity(animateContent ? 1 : 0)
        .offset(x: animateContent ? 0 : -20)
        .animation(
            .spring(response: 0.45, dampingFraction: 0.72).delay(0.18 + Double(index) * 0.07),
            value: animateContent
        )
        .onTapGesture {
            AppAnalyticsService.shared.logFamilyMemberViewed()
        }
    }

    // MARK: - Leave Button

    private var leaveButton: some View {
        Button {
            showLeaveConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .medium))
                Text("Leave Family Group")
                    .fontWeight(.medium)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.red.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Notification Banner

    @ViewBuilder
    private var notificationBanner: some View {
        if let errorMsg = vm.error {
            bannerView(text: errorMsg, color: .red, icon: "exclamationmark.triangle.fill")
                .onTapGesture { vm.clearError() }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation { vm.clearError() }
                    }
                }
        } else if let successMsg = vm.successMessage {
            bannerView(text: successMsg, color: AppColors.family, icon: "checkmark.circle.fill")
                .onTapGesture { vm.clearSuccess() }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { vm.clearSuccess() }
                    }
                }
        } else if showCopied {
            bannerView(text: "Invite code copied!", color: AppColors.family, icon: "doc.on.doc.fill")
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopied = false
                        }
                    }
                }
        }
    }

    private func bannerView(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
            Text(text)
                .font(.subheadline)
                .lineLimit(2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.25), value: vm.error)
        .animation(.easeInOut(duration: 0.25), value: vm.successMessage)
        .animation(.easeInOut(duration: 0.25), value: showCopied)
    }

    // MARK: - Helpers

    private func memberInitial(_ member: FamilyMember) -> String {
        if let name = member.fullName, let first = name.first {
            return String(first).uppercased()
        }
        return "?"
    }
}

// MARK: - Family Tab

private enum FamilyTab {
    case create
    case join
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FamilyView()
            .environmentObject(DeepLinkHandler())
    }
}
