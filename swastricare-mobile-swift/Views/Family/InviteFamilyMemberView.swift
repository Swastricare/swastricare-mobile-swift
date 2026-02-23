//
//  InviteFamilyMemberView.swift
//  swastricare-mobile-swift
//
//  Generate and share family invite codes - Enhanced UI
//

import SwiftUI
import UIKit

struct InviteFamilyMemberView: View {
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showShareSheet = false
    @State private var copiedToClipboard = false

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        if let invite = viewModel.currentInvite {
                            inviteCodeCard(invite)
                        } else {
                            roleSelectionSection
                            
                            generateButton
                        }

                        if !viewModel.pendingInvites.isEmpty && viewModel.currentInvite == nil {
                            pendingInvitesSection
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        viewModel.resetInviteState()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let invite = viewModel.currentInvite {
                    FamilyInviteShareSheet(items: [shareText(for: invite)])
                }
            }
            .task { await viewModel.loadPendingInvites() }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accentBlue, AppColors.accentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: AppColors.accentBlue.opacity(0.3), radius: 12, y: 4)
                
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 6) {
                Text(viewModel.currentInvite != nil ? "Invite Ready!" : "Invite Someone")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(viewModel.currentInvite != nil
                     ? "Share this code with someone to invite them to your family."
                     : "Generate an invite code to add someone to \(viewModel.selectedGroup?.name ?? "your family").")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Role Selection Section
    
    private var roleSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Access Level")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 10) {
                RoleOption(
                    role: .caregiver,
                    isSelected: viewModel.inviteRole == .caregiver
                ) {
                    viewModel.inviteRole = .caregiver
                }
                
                RoleOption(
                    role: .viewer,
                    isSelected: viewModel.inviteRole == .viewer
                ) {
                    viewModel.inviteRole = .viewer
                }
                
                RoleOption(
                    role: .limited,
                    isSelected: viewModel.inviteRole == .limited
                ) {
                    viewModel.inviteRole = .limited
                }
            }
        }
    }
    
    // MARK: - Generate Button
    
    private var generateButton: some View {
        Button {
            Task { _ = await viewModel.createInvite() }
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "ticket.fill")
                    Text("Generate Invite Code")
                }
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.accentBlue)
        .disabled(viewModel.isSaving || viewModel.selectedGroup == nil)
    }
    
    // MARK: - Invite Code Card
    
    private func inviteCodeCard(_ invite: FamilyInvite) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Invite Code")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(invite.inviteCode)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .kerning(6)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accentBlue, AppColors.accentPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                HStack(spacing: 16) {
                    Label(invite.role.displayName, systemImage: invite.role.icon)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accentBlue)
                    
                    Label("Expires \(invite.formattedExpiresAt)", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = invite.inviteCode
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        copiedToClipboard = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copiedToClipboard = false }
                    }
                } label: {
                    HStack {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                        Text(copiedToClipboard ? "Copied!" : "Copy")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.bordered)
                .tint(copiedToClipboard ? .green : .primary)

                Button {
                    showShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accentBlue)
            }
            
            Button {
                viewModel.currentInvite = nil
            } label: {
                Text("Create Another Invite")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.accentBlue.opacity(0.3), AppColors.accentPurple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Pending Invites Section

    private var pendingInvitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pending Invites")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(viewModel.pendingInvites.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.accentBlue, in: Capsule())
            }

            VStack(spacing: 10) {
                ForEach(viewModel.pendingInvites) { invite in
                    PendingInviteRow(invite: invite) {
                        Task { await viewModel.revokeInvite(invite) }
                    }
                }
            }
        }
    }

    private func shareText(for invite: FamilyInvite) -> String {
        let groupName = viewModel.selectedGroup?.name ?? "my family"

        return """
        Join \(groupName) on SwasthiCare! 🏥

        Your invite code: \(invite.inviteCode)

        Open the SwasthiCare app → Family → Join with Invite Code

        Code expires \(invite.formattedExpiresAt).
        """
    }
}

// MARK: - Role Option

private struct RoleOption: View {
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
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: role.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(roleColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(role.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(role.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? roleColor : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(roleColor)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? roleColor.opacity(0.08) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? roleColor.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pending Invite Row

private struct PendingInviteRow: View {
    let invite: FamilyInvite
    let onRevoke: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invite.inviteCode)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .kerning(1)
                
                HStack(spacing: 8) {
                    Label(invite.role.displayName, systemImage: invite.role.icon)
                        .font(.caption2)
                        .foregroundColor(AppColors.accentBlue)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("Expires \(invite.formattedExpiresAt)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onRevoke) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Share Sheet

struct FamilyInviteShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    InviteFamilyMemberView(viewModel: FamilyViewModel())
}
