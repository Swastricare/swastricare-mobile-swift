//
//  FamilyView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit

struct FamilyView: View {
    @EnvironmentObject private var deepLinkHandler: DeepLinkHandler
    @StateObject private var vm = DependencyContainer.shared.familyViewModel

    @State private var selectedTab: FamilyTab = .create
    @State private var familyName: String = ""
    @State private var showCopied = false
    @State private var showLeaveConfirmation = false
    @State private var memberToRemove: FamilyMember?
    @State private var showRemoveConfirmation = false

    // Staggered animation
    @State private var animateContent = false

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
                withAnimation(.easeOut(duration: 0.5)) {
                    animateContent = true
                }
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
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading family...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - No Family View

    private var noFamilyView: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.family)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)

                Text("Family Health")
                    .font(.title2.bold())
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 15)

                Text("Create a family group or join one to share and manage health data together.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 10)
            }
            .padding(.top, 20)

            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Create").tag(FamilyTab.create)
                Text("Join").tag(FamilyTab.join)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)
            .opacity(animateContent ? 1 : 0)

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
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
    }

    // MARK: - Create Family Card

    private var createFamilyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Create Your Family", systemImage: "plus.circle.fill")
                .font(.headline)
                .foregroundStyle(AppColors.family)

            Text("Start a family group and invite members to share health tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Family name (e.g., Sharma Family)", text: $familyName)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)

            Button {
                Task { await vm.createFamily(name: familyName) }
            } label: {
                HStack {
                    if vm.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Create Family")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColors.family)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)
            .opacity(familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
        }
        .padding(20)
        .glass()
    }

    // MARK: - Join Family Card

    private var joinFamilyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Join a Family", systemImage: "person.badge.plus")
                .font(.headline)
                .foregroundStyle(AppColors.family)

            Text("Enter the invite code shared by your family group owner.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("Invite code (e.g., ABC12345)", text: $vm.joinCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                Button {
                    vm.joinCode = (UIPasteboard.general.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title3)
                        .foregroundStyle(AppColors.family)
                }
            }

            Button {
                Task { await vm.joinFamily() }
            } label: {
                HStack {
                    if vm.isJoining {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Join Family")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColors.family)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(vm.joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isJoining)
            .opacity(vm.joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
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
                .offset(y: animateContent ? 0 : 20)

            // Invite Section
            inviteCard
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 25)

            // Members Section
            membersCard
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 30)

            // Leave Group Button (not for owner)
            if !vm.isOwner {
                leaveButton
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 35)
            }
        }
    }

    // MARK: - Group Header Card

    private var groupHeaderCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.familyGroup?.name ?? "My Family")
                        .font(.title2.bold())

                    Text("\(vm.memberCount) member\(vm.memberCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "person.3.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AppColors.family)
            }

            if let role = vm.currentMemberRole {
                HStack {
                    Image(systemName: role.icon)
                        .font(.caption)
                    Text("You are the \(role.displayName)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(role.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(role.color.opacity(0.15))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .glass()
    }

    // MARK: - Invite Card

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Invite Members", systemImage: "envelope.badge.fill")
                .font(.headline)
                .foregroundStyle(AppColors.family)

            if !vm.inviteCode.isEmpty {
                // Invite Code Display
                HStack {
                    Text(vm.inviteCode)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .tracking(3)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = vm.inviteCode
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopied = true
                        }
                    } label: {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.body)
                            .foregroundStyle(AppColors.family)
                            .padding(10)
                            .background(AppColors.family.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(14)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Share & Regenerate Buttons
                HStack(spacing: 12) {
                    ShareLink(item: vm.shareLink) {
                        Label("Share Link", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.family)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    if vm.isOwner {
                        Button {
                            Task { await vm.regenerateCode() }
                        } label: {
                            Label("New Code", systemImage: "arrow.triangle.2.circlepath")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.tertiarySystemBackground))
                                .foregroundStyle(AppColors.family)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    memberRow(member: member)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : CGFloat(10 + index * 5))
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.08), value: animateContent)

                    if index < vm.members.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .padding(20)
        .glass()
    }

    // MARK: - Member Row

    private func memberRow(member: FamilyMember) -> some View {
        HStack(spacing: 12) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(member.role.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Text(memberInitial(member))
                    .font(.headline)
                    .foregroundStyle(member.role.color)
            }

            // Name & info
            VStack(alignment: .leading, spacing: 3) {
                Text(member.fullName ?? "Unknown")
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 6) {
                    // Role badge
                    HStack(spacing: 3) {
                        Image(systemName: member.role.icon)
                            .font(.system(size: 9))
                        Text(member.role.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
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
    }

    // MARK: - Leave Button

    private var leaveButton: some View {
        Button {
            showLeaveConfirmation = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Leave Family Group")
                    .fontWeight(.medium)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
