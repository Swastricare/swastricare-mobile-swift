//
//  FamilyMemberDetailView.swift
//  swastricare-mobile-swift
//
//  Detailed view for family member with role management
//

import SwiftUI

struct FamilyMemberDetailView: View {
    let member: FamilyMember
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showRoleSheet = false
    @State private var showRemoveConfirmation = false
    @State private var selectedRole: FamilyMemberRole
    @State private var showProfileSwitchToast = false
    
    init(member: FamilyMember, viewModel: FamilyViewModel) {
        self.member = member
        self.viewModel = viewModel
        self._selectedRole = State(initialValue: member.role)
    }
    
    private var isOwner: Bool {
        viewModel.isOwnerOfSelectedGroup
    }
    
    private var canEditMember: Bool {
        isOwner && member.role != .owner
    }
    
    private var canViewMemberData: Bool {
        member.canView
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileHeader
                        
                        if canViewMemberData {
                            viewHealthDataButton
                        }
                        
                        infoSection
                        
                        if canEditMember {
                            roleSection
                            
                            permissionsSection
                            
                            dangerZone
                        } else if member.role == .owner {
                            ownerBadge
                        }
                    }
                    .padding()
                }
                
                if showProfileSwitchToast {
                    VStack {
                        Spacer()
                        toastView
                            .padding(.bottom, 40)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4), value: showProfileSwitchToast)
                }
            }
            .navigationTitle("Member Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showRoleSheet) {
                RoleSelectionSheet(
                    currentRole: member.role,
                    selectedRole: $selectedRole,
                    onSave: {
                        Task {
                            await viewModel.updateMemberRole(member, to: selectedRole)
                            dismiss()
                        }
                    }
                )
            }
            .confirmationDialog(
                "Remove \(member.displayName)?",
                isPresented: $showRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove from Family", role: .destructive) {
                    Task {
                        await viewModel.removeMember(member)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This person will no longer have access to this family group's health data.")
            }
        }
    }
    
    // MARK: - View Health Data Button
    
    private var viewHealthDataButton: some View {
        Button {
            switchToMemberProfile()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.accentBlue, AppColors.accentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("View Health Data")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Switch to viewing \(member.displayName)'s health")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accentBlue, AppColors.accentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [AppColors.accentBlue.opacity(0.1), AppColors.accentPurple.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accentBlue.opacity(0.3), AppColors.accentPurple.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var toastView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.green)
            
            Text("Now viewing \(member.displayName)'s data")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
    
    private func switchToMemberProfile() {
        let profileId = member.healthProfileId
        
        Task { @MainActor in
            ActiveProfileManager.shared.switchToFamilyMember(
                healthProfileId: profileId,
                name: member.displayName,
                relationship: member.relationship
            )
            
            withAnimation {
                showProfileSwitchToast = true
            }
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            withAnimation {
                showProfileSwitchToast = false
            }
            
            try? await Task.sleep(nanoseconds: 300_000_000)
            dismiss()
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
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
                    .frame(width: 100, height: 100)
                    .shadow(color: Color(hex: member.roleColor.primary).opacity(0.3), radius: 15, y: 5)
                
                Text(member.initials)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(member.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if member.role == .owner {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.accentBlue)
                    }
                }
                
                HStack(spacing: 12) {
                    Label(member.role.displayName, systemImage: member.role.icon)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: member.roleColor.primary))
                    
                    if let relationship = member.relationship {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(relationship)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 0) {
                InfoRow(
                    icon: "person.fill",
                    title: "Gender",
                    value: member.memberGender?.capitalized ?? "Not specified",
                    color: .blue
                )
                
                Divider().padding(.leading, 44)
                
                InfoRow(
                    icon: "calendar",
                    title: "Age",
                    value: member.ageString.isEmpty ? "Not specified" : member.ageString,
                    color: .purple
                )
                
                Divider().padding(.leading, 44)
                
                InfoRow(
                    icon: "clock.fill",
                    title: "Joined",
                    value: member.joinedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown",
                    color: .green
                )
                
                if member.status != .active {
                    Divider().padding(.leading, 44)
                    
                    InfoRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Status",
                        value: member.status.rawValue.capitalized,
                        color: .orange
                    )
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Role Section
    
    private var roleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Role")
                .font(.headline)
                .fontWeight(.semibold)
            
            Button {
                showRoleSheet = true
            } label: {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(hex: member.roleColor.primary).opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: member.role.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: member.roleColor.primary))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.role.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(member.role.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Permissions Section
    
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 0) {
                PermissionRow(title: "View Health Data", isEnabled: member.canView)
                Divider().padding(.leading, 44)
                PermissionRow(title: "Edit Health Data", isEnabled: member.canEdit)
                Divider().padding(.leading, 44)
                PermissionRow(title: "Add Medications", isEnabled: member.canAddMedications)
                Divider().padding(.leading, 44)
                PermissionRow(title: "Add Appointments", isEnabled: member.canAddAppointments)
                Divider().padding(.leading, 44)
                PermissionRow(title: "View Documents", isEnabled: member.canViewMedicalDocuments)
                Divider().padding(.leading, 44)
                PermissionRow(title: "Manage Members", isEnabled: member.canManageMembers)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Owner Badge
    
    private var ownerBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 24))
                .foregroundColor(AppColors.accentBlue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Family Owner")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("This member owns this family group and has full control.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [AppColors.accentBlue.opacity(0.1), AppColors.accentPurple.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.accentBlue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Danger Zone
    
    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Danger Zone")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.red)
            
            Button {
                showRemoveConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "person.badge.minus")
                        .font(.system(size: 18))
                    
                    Text("Remove from Family")
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                .foregroundColor(.red)
                .padding()
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let title: String
    let isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isEnabled ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: isEnabled ? "checkmark" : "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isEnabled ? .green : .gray)
            }
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(isEnabled ? "Allowed" : "Denied")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isEnabled ? .green : .secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Role Selection Sheet

private struct RoleSelectionSheet: View {
    let currentRole: FamilyMemberRole
    @Binding var selectedRole: FamilyMemberRole
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let availableRoles: [FamilyMemberRole] = [.caregiver, .viewer, .limited]
    
    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Select the access level for this family member.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(availableRoles, id: \.self) { role in
                                RoleOptionCard(
                                    role: role,
                                    isSelected: selectedRole == role
                                ) {
                                    selectedRole = role
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Button {
                            onSave()
                        } label: {
                            Text("Save Changes")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.accentBlue)
                        .disabled(selectedRole == currentRole)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Change Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Role Option Card

private struct RoleOptionCard: View {
    let role: FamilyMemberRole
    let isSelected: Bool
    let action: () -> Void
    
    private var roleColor: Color {
        switch role {
        case .owner: return AppColors.accentBlue
        case .caregiver: return AppColors.accentGreen
        case .viewer: return Color.blue
        case .limited: return Color.gray
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(roleColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: role.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(roleColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(role.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(role.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? roleColor : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(roleColor)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? roleColor.opacity(0.08) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? roleColor.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let member: FamilyMember = try! JSONDecoder().decode(
        FamilyMember.self,
        from: """
        {
          "id": "123e4567-e89b-12d3-a456-426614174000",
          "family_group_id": "123e4567-e89b-12d3-a456-426614174001",
          "health_profile_id": "123e4567-e89b-12d3-a456-426614174002",
          "role": "caregiver",
          "status": "active",
          "can_view": true,
          "can_edit": true
        }
        """.data(using: .utf8)!
    )

    return FamilyMemberDetailView(
        member: member,
        viewModel: FamilyViewModel()
    )
}
