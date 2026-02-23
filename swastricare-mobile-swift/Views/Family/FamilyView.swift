//
//  FamilyView.swift
//  swastricare-mobile-swift
//
//  Modern Family Management Screen with Premium UI
//

import SwiftUI

struct FamilyView: View {
    @StateObject private var viewModel = FamilyViewModel()
    @EnvironmentObject private var deepLinkHandler: DeepLinkHandler

    @State private var showJoinFamily = false
    @State private var showInvite = false
    @State private var showCreateGroup = false
    @State private var showMemberDetail = false
    @State private var selectedMemberForDetail: FamilyMember?

    var initialInviteCode: String?

    var body: some View {
        ZStack {
            PremiumBackground()

            if viewModel.isLoading {
                loadingView
            } else if !viewModel.hasGroups {
                emptyStateView
            } else {
                mainContent
            }
        }
        .navigationTitle("Family")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task { await viewModel.loadFamilyGroups() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    
                    Divider()
                    
                    Button {
                        showCreateGroup = true
                    } label: {
                        Label("Create Family Group", systemImage: "plus.circle")
                    }
                    
                    Button {
                        showJoinFamily = true
                    } label: {
                        Label("Join with Invite Code", systemImage: "ticket")
                    }
                    
                    if viewModel.isOwnerOfSelectedGroup {
                        Divider()
                        Button {
                            showInvite = true
                        } label: {
                            Label("Invite Someone", systemImage: "person.badge.plus")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .medium))
                }
            }
        }
        .sheet(isPresented: $showJoinFamily) {
            JoinFamilyView(viewModel: viewModel)
        }
        .sheet(isPresented: $showInvite) {
            InviteFamilyMemberView(viewModel: viewModel)
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateFamilyGroupView(viewModel: viewModel)
        }
        .sheet(item: $selectedMemberForDetail) { member in
            FamilyMemberDetailView(member: member, viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay {
            if let message = viewModel.successMessage {
                successToast(message: message)
            }
        }
        .task {
            await viewModel.loadFamilyGroups()

            if let code = initialInviteCode, !code.isEmpty {
                viewModel.inviteCode = code
                showJoinFamily = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkFamilyJoin)) { notification in
            if let code = notification.userInfo?[DeepLinkUserInfoKey.familyInviteCode] as? String, !code.isEmpty {
                viewModel.inviteCode = code
                deepLinkHandler.pendingFamilyInviteCode = code
                showJoinFamily = true
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading family...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(AppColors.accentBlue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accentBlue, AppColors.accentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("No Family Groups")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Create a family group to share health data with your loved ones, or join an existing one.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                Button {
                    showCreateGroup = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Family Group")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accentBlue)
                
                Button {
                    showJoinFamily = true
                } label: {
                    HStack {
                        Image(systemName: "ticket.fill")
                        Text("Join with Invite Code")
                    }
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }

    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if viewModel.allGroups.count > 1 {
                    groupSelector
                }
                
                if let group = viewModel.selectedGroup {
                    groupHeader(group)
                }
                
                membersSection
                
                if viewModel.isOwnerOfSelectedGroup {
                    invitesSection
                    
                    quickActionsSection
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Group Selector
    
    private var groupSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.allGroups) { group in
                    GroupChip(
                        group: group,
                        isSelected: viewModel.selectedGroup?.id == group.id,
                        isOwned: viewModel.familyGroups.contains(where: { $0.id == group.id })
                    ) {
                        Task { await viewModel.selectGroup(group) }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Group Header
    
    private func groupHeader(_ group: FamilyGroup) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.accentBlue, AppColors.accentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Text(String(group.name.prefix(2)).uppercased())
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 8) {
                        Label("\(group.memberCount) members", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if viewModel.isOwnerOfSelectedGroup {
                            Text("•")
                                .foregroundColor(.secondary)
                            Label("Owner", systemImage: "crown.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.accentBlue)
                        }
                    }
                }
                
                Spacer()
            }
            
            if let description = group.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Members Section
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Family Members")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if viewModel.isLoadingMembers {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            
            if viewModel.familyMembers.isEmpty && !viewModel.isLoadingMembers {
                emptyMembersCard
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.activeMembers) { member in
                        FamilyMemberCard(
                            member: member,
                            isOwner: viewModel.isOwnerOfSelectedGroup,
                            onTap: {
                                selectedMemberForDetail = member
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var emptyMembersCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            
            Text("No members yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if viewModel.isOwnerOfSelectedGroup {
                Button("Invite Someone") {
                    showInvite = true
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Invites Section
    
    private var invitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pending Invites")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !viewModel.pendingInvites.isEmpty {
                    Text("\(viewModel.pendingInvites.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.accentBlue, in: Capsule())
                }
            }
            .padding(.horizontal)
            
            if viewModel.pendingInvites.isEmpty {
                HStack {
                    Image(systemName: "ticket")
                        .foregroundColor(.secondary)
                    Text("No pending invites")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.pendingInvites) { invite in
                            InviteCard(invite: invite) {
                                Task { await viewModel.revokeInvite(invite) }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            QuickActionCard(
                icon: "person.badge.plus",
                title: "Invite",
                color: AppColors.accentGreen
            ) {
                showInvite = true
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Success Toast
    
    private func successToast(message: String) -> some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding()
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            .padding(.bottom, 32)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { viewModel.clearSuccess() }
            }
        }
    }
}

// MARK: - Group Chip

private struct GroupChip: View {
    let group: FamilyGroup
    let isSelected: Bool
    let isOwned: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isOwned {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white : AppColors.accentBlue)
                }
                
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(group.memberCount)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(
                            isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1)
                        )
                    )
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(
                    isSelected
                        ? LinearGradient(
                            colors: [AppColors.accentBlue, AppColors.accentPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(colors: [Color(.systemBackground)], startPoint: .leading, endPoint: .trailing)
                )
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? Color.clear : Color.secondary.opacity(0.2),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Family Member Card

private struct FamilyMemberCard: View {
    let member: FamilyMember
    let isOwner: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: member.roleColor.primary),
                                    Color(hex: member.roleColor.secondary)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Text(member.initials)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(member.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if member.role == .owner {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.accentBlue)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Label(member.role.displayName, systemImage: member.role.icon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let age = member.age {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("\(age) yrs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let relationship = member.relationship {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(relationship)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Invite Card

private struct InviteCard: View {
    let invite: FamilyInvite
    let onRevoke: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(invite.inviteCode)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .kerning(2)
                
                Spacer()
                
                Button(action: onRevoke) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("Expires \(invite.formattedExpiresAt)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            HStack(spacing: 6) {
                Image(systemName: invite.role.icon)
                    .font(.caption2)
                Text(invite.role.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(AppColors.accentBlue)
        }
        .padding()
        .frame(width: 180)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Quick Action Card

private struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        FamilyView()
            .environmentObject(DeepLinkHandler())
    }
}
