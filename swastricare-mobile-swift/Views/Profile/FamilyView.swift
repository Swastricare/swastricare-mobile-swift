//
//  FamilyView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit

// MARK: - Design Tokens (mirrors Android FamilyScreen.kt)

private let pageBg = Color.white
private let cardBg = Color.white
private let cardBorder = Color(red: 0.94, green: 0.94, blue: 0.96) // #E5E7EB-ish hairline
private let subtitleColor = Color(red: 0.42, green: 0.45, blue: 0.50) // #6B7280
private let headerColor = Color(red: 0.07, green: 0.09, blue: 0.16)   // ~#111827
private let dangerColor = Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444
private let aiTeal = AppColors.accentBlue // AITeal #22C5A6

// MARK: - Reusable Card Container

private struct FlatCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardBorder, lineWidth: 1)
            )
    }
}

// MARK: - Primary (solid AITeal) Button

private struct TealPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    Text(title)
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isDisabled ? aiTeal.opacity(0.45) : aiTeal)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Outlined (AITeal stroke) Button

private struct TealOutlineButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.poppins(.semiBold, size: 15))
                }
                Text(title)
                    .font(.poppins(.semiBold, size: 15))
            }
            .foregroundStyle(aiTeal)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(aiTeal, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flat Outlined Text Field

private struct FlatTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var autocapitalization: TextInputAutocapitalization = .sentences

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.poppins(.medium, size: 12))
                .foregroundStyle(focused ? aiTeal : subtitleColor)

            TextField(placeholder, text: $text)
                .font(.poppins(.regular, size: 15))
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .focused($focused)
                .tint(aiTeal)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focused ? aiTeal : cardBorder, lineWidth: focused ? 1.5 : 1)
                )
        }
    }
}

// MARK: - Better Together Banner

private struct BetterTogetherBanner: View {
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Full-bleed banner illustration (Android: matchParentSize + Crop)
                Image("family-banner")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // Text overlay — sized to 55% of card width to leave room for
                // the family illustration on the right (Android: fillMaxWidth(0.55f))
                VStack(alignment: .leading, spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(aiTeal.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(aiTeal)
                    }
                    Text("Better together")
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundStyle(headerColor)
                    Text("Add your loved ones and help them stay on track with their medications.")
                        .font(.poppins(.regular, size: 12))
                        .foregroundStyle(subtitleColor)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(width: geo.size.width * 0.55, alignment: .leading)
            }
        }
        .frame(height: 160)
        .background(aiTeal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Main View

struct FamilyView: View {
    @EnvironmentObject private var deepLinkHandler: DeepLinkHandler
    @StateObject private var vm = DependencyContainer.shared.familyViewModel

    @State private var familyName: String = ""
    @State private var showCopied = false
    @State private var showLeaveConfirmation = false
    @State private var memberToRemove: FamilyMember?
    @State private var showRemoveConfirmation = false
    @State private var showInviteSheet = false
    @State private var editMode = false

    init(initialInviteCode: String? = nil) {
        if let code = initialInviteCode, !code.isEmpty {
            // Handled in onAppear via deepLinkHandler
        }
    }

    var body: some View {
        ZStack {
            pageBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerBlock
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    Spacer().frame(height: 16)

                    if vm.isLoading && !vm.hasFamily {
                        loadingView
                    } else if vm.hasFamily {
                        familyGroupView
                    } else {
                        noFamilyView
                    }

                    Spacer().frame(height: 32)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.hasFamily {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInviteSheet = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(aiTeal.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "person.badge.plus")
                                .font(.poppins(.semiBold, size: 14))
                                .foregroundStyle(aiTeal)
                        }
                    }
                }
            }
        }
        .onAppear {
            if let pending = deepLinkHandler.pendingFamilyInviteCode, !pending.isEmpty {
                vm.joinCode = pending.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            deepLinkHandler.clearFamilyInviteCode()

            Task {
                await vm.loadFamily()
            }
        }
        .onChange(of: vm.hasFamily) { _, hasFamily in
            if !hasFamily { editMode = false }
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
        .sheet(isPresented: $showInviteSheet) {
            inviteSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .top) {
            notificationBanner
        }
        .trackScreen("Family")
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Family")
                .font(.poppins(.bold, size: 30))
                .foregroundStyle(headerColor)
            Text("Manage your family members and their medications in one place.")
                .font(.poppins(.regular, size: 13))
                .foregroundStyle(subtitleColor)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.1)
                .tint(aiTeal)
            Text("Loading family...")
                .font(.poppins(.regular, size: 14))
                .foregroundStyle(subtitleColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - No Family View

    private var noFamilyView: some View {
        VStack(spacing: 20) {
            BetterTogetherBanner()
                .padding(.horizontal, 16)

            // Create family card
            FlatCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Create your family")
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundStyle(headerColor)
                    Text("Start a new family group and invite your loved ones.")
                        .font(.poppins(.regular, size: 12))
                        .foregroundStyle(subtitleColor)

                    FlatTextField(
                        label: "Group name",
                        placeholder: "e.g. Sharma Family",
                        text: $familyName,
                        autocapitalization: .words
                    )

                    TealPrimaryButton(
                        title: "Create Family Group",
                        isLoading: vm.isLoading,
                        isDisabled: familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading
                    ) {
                        Task { await vm.createFamily(name: familyName) }
                    }
                }
            }
            .padding(.horizontal, 16)

            // "or" divider
            HStack(spacing: 12) {
                Rectangle()
                    .fill(cardBorder)
                    .frame(height: 1)
                Text("or")
                    .font(.poppins(.regular, size: 12))
                    .foregroundStyle(subtitleColor)
                Rectangle()
                    .fill(cardBorder)
                    .frame(height: 1)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 4)

            // Join family card
            FlatCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Join with invite code")
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundStyle(headerColor)
                    Text("Already have an invite? Enter the code to join your family's health group.")
                        .font(.poppins(.regular, size: 12))
                        .foregroundStyle(subtitleColor)

                    FlatTextField(
                        label: "Invite code",
                        placeholder: "e.g. ABC123",
                        text: $vm.joinCode,
                        autocapitalization: .characters
                    )

                    TealPrimaryButton(
                        title: "Join Group",
                        isLoading: vm.isJoining,
                        isDisabled: vm.joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isJoining
                    ) {
                        Task { await vm.joinFamily() }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Has Family View

    private var familyGroupView: some View {
        VStack(spacing: 20) {
            BetterTogetherBanner()
                .padding(.horizontal, 16)

            // "Your Family" header
            HStack {
                Text("Your Family")
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundStyle(headerColor)
                Spacer()
                if vm.isOwner {
                    Button {
                        editMode.toggle()
                    } label: {
                        Text(editMode ? "Done" : "Edit")
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundStyle(aiTeal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            // Member rows
            VStack(spacing: 8) {
                if vm.members.isEmpty {
                    FlatCard {
                        Text("No members yet. Tap the invite icon to share your code.")
                            .font(.poppins(.regular, size: 13))
                            .foregroundStyle(subtitleColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                } else {
                    ForEach(vm.members, id: \.id) { member in
                        memberRowWrapper(member: member)
                    }
                }
            }

            // Add member button
            VStack(spacing: 6) {
                TealOutlineButton(title: "Add Family Member", icon: "plus") {
                    showInviteSheet = true
                }
                .padding(.horizontal, 16)

                Text("Invite and manage family members")
                    .font(.poppins(.regular, size: 12))
                    .foregroundStyle(subtitleColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Member Row

    @ViewBuilder
    private func memberRowWrapper(member: FamilyMember) -> some View {
        let canRemove = editMode && member.role != .owner

        if editMode {
            memberRow(member: member, canRemove: canRemove, isInEditMode: true)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
                .onTapGesture {
                    if canRemove {
                        memberToRemove = member
                        showRemoveConfirmation = true
                    }
                }
        } else {
            NavigationLink {
                FamilyMemberDashboardView(
                    targetHealthProfileId: member.healthProfileId.uuidString
                )
            } label: {
                memberRow(member: member, canRemove: false, isInEditMode: false)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                AppAnalyticsService.shared.logFamilyMemberViewed()
            })
        }
    }

    private func memberRow(member: FamilyMember, canRemove: Bool, isInEditMode: Bool) -> some View {
        let displayName = member.fullName ?? "Member"
        let subtitle: String = {
            switch member.role {
            case .owner: return "Group owner"
            case .caregiver: return "Caregiver"
            case .viewer: return "Viewer"
            case .limited: return "Limited"
            }
        }()

        return HStack(spacing: 12) {
            // Avatar — prefer the member's avatar URL from the embedded
            // health_profiles row; fall back to initials in a teal circle when
            // unavailable or while loading.
            ZStack {
                Circle()
                    .fill(aiTeal.opacity(0.15))
                    .frame(width: 44, height: 44)

                if let urlString = member.avatarUrl,
                   !urlString.isEmpty,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .empty, .failure:
                            Text(memberInitials(member))
                                .font(.poppins(.bold, size: 13))
                                .foregroundStyle(aiTeal)
                        @unknown default:
                            Text(memberInitials(member))
                                .font(.poppins(.bold, size: 13))
                                .foregroundStyle(aiTeal)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Text(memberInitials(member))
                        .font(.poppins(.bold, size: 13))
                        .foregroundStyle(aiTeal)
                }
            }

            // Name + subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(.poppins(.semiBold, size: 15))
                        .foregroundStyle(headerColor)

                    if member.role == .owner {
                        Text("OWNER")
                            .font(.poppins(.semiBold, size: 10))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(aiTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text(member.role.displayName.uppercased())
                            .font(.poppins(.semiBold, size: 10))
                            .foregroundStyle(Color(red: 0.30, green: 0.34, blue: 0.40))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                Text(subtitle)
                    .font(.poppins(.regular, size: 12))
                    .foregroundStyle(subtitleColor)
            }

            Spacer()

            // Trailing icon
            if isInEditMode {
                if canRemove {
                    Image(systemName: "trash")
                        .font(.poppins(.regular, size: 16))
                        .foregroundStyle(dangerColor)
                        .frame(width: 22, height: 22)
                } else {
                    Color.clear.frame(width: 22, height: 22)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.poppins(.semiBold, size: 13))
                    .foregroundStyle(subtitleColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Invite Sheet

    private var inviteSheet: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Title + description
                VStack(spacing: 6) {
                    Text("Invite a member")
                        .font(.poppins(.semiBold, size: 18))
                        .foregroundStyle(headerColor)
                    Text("Share this code with anyone you want to add to your family group.")
                        .font(.poppins(.regular, size: 13))
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                // Code box
                Button {
                    if !vm.inviteCode.isEmpty {
                        UIPasteboard.general.string = vm.inviteCode
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            showCopied = true
                        }
                        AppAnalyticsService.shared.logFamilyInviteSent()
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text("INVITE CODE")
                            .font(.poppins(.semiBold, size: 11))
                            .tracking(1.5)
                            .foregroundStyle(subtitleColor)
                        Text(vm.inviteCode.isEmpty ? "------" : vm.inviteCode)
                            .font(.poppins(.bold, size: 32))
                            .tracking(6)
                            .foregroundStyle(aiTeal)
                        HStack(spacing: 4) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.poppins(.regular, size: 11))
                            Text(showCopied ? "Code copied" : "Tap to copy code")
                                .font(.poppins(.medium, size: 11))
                        }
                        .foregroundStyle(aiTeal)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(aiTeal.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(vm.inviteCode.isEmpty)

                // Actions row
                HStack(spacing: 12) {
                    if vm.isOwner {
                        Button {
                            Task { await vm.regenerateCode() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.poppins(.semiBold, size: 14))
                                Text("Generate")
                                    .font(.poppins(.semiBold, size: 15))
                            }
                            .foregroundStyle(aiTeal)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(aiTeal, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    ShareLink(item: vm.shareLink) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .font(.poppins(.semiBold, size: 14))
                            Text("Copy Link")
                                .font(.poppins(.semiBold, size: 15))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(aiTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        AppAnalyticsService.shared.logFamilyInviteSent()
                    })
                }

                if !vm.isOwner {
                    Button {
                        showInviteSheet = false
                        showLeaveConfirmation = true
                    } label: {
                        Text("Leave Family Group")
                            .font(.poppins(.medium, size: 15))
                            .foregroundStyle(dangerColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color.white)
    }

    // MARK: - Notification Banner

    @ViewBuilder
    private var notificationBanner: some View {
        if let errorMsg = vm.error {
            bannerView(text: errorMsg, color: dangerColor, icon: "exclamationmark.triangle.fill")
                .onTapGesture { vm.clearError() }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation { vm.clearError() }
                    }
                }
        } else if let successMsg = vm.successMessage {
            bannerView(text: successMsg, color: aiTeal, icon: "checkmark.circle.fill")
                .onTapGesture { vm.clearSuccess() }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { vm.clearSuccess() }
                    }
                }
        } else if showCopied {
            bannerView(text: "Invite code copied!", color: aiTeal, icon: "doc.on.doc.fill")
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
                .font(.poppins(.regular, size: 14))
            Text(text)
                .font(.poppins(.regular, size: 14))
                .lineLimit(2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.25), value: vm.error)
        .animation(.easeInOut(duration: 0.25), value: vm.successMessage)
        .animation(.easeInOut(duration: 0.25), value: showCopied)
    }

    // MARK: - Helpers

    private func memberInitials(_ member: FamilyMember) -> String {
        guard let name = member.fullName, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2, let f = parts[0].first, let s = parts[1].first {
            return "\(f)\(s)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FamilyView()
            .environmentObject(DeepLinkHandler())
    }
}
