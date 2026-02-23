//
//  JoinFamilyView.swift
//  swastricare-mobile-swift
//
//  Join family group with invite code - Enhanced UI
//

import SwiftUI

struct JoinFamilyView: View {
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss

    @FocusState private var isFocused: Bool
    @State private var codeCharacters: [String] = Array(repeating: "", count: 8)

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView {
                    VStack(spacing: 28) {
                        headerSection
                        
                        codeInputSection
                        
                        if viewModel.isLookingUpInvite {
                            lookingUpView
                        } else if let result = viewModel.lookupResult {
                            groupPreviewCard(result)
                        }
                        
                        joinButton
                        
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Join Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.resetInviteState()
                        dismiss()
                    }
                }
            }
            .onAppear { isFocused = true }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accentGreen, Color(hex: "38ef7d")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: AppColors.accentGreen.opacity(0.3), radius: 12, y: 4)
                
                Image(systemName: "ticket.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 6) {
                Text("Enter Invite Code")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("Enter the 8-character code shared with you to join a family group.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Code Input Section
    
    private var codeInputSection: some View {
        VStack(spacing: 12) {
            TextField("", text: $viewModel.inviteCode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .kerning(8)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .multilineTextAlignment(.center)
                .padding(.vertical, 20)
                .padding(.horizontal)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            viewModel.lookupResult != nil
                                ? AppColors.accentGreen
                                : (isFocused ? AppColors.accentBlue : Color.clear),
                            lineWidth: 2
                        )
                )
                .focused($isFocused)
                .onChange(of: viewModel.inviteCode) { _, newValue in
                    let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                    if filtered != newValue {
                        viewModel.inviteCode = filtered
                    }
                    if filtered.count >= 8 {
                        viewModel.inviteCode = String(filtered.prefix(8))
                        Task { await viewModel.lookupInvite() }
                    } else {
                        viewModel.lookupResult = nil
                    }
                }
            
            HStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(
                            index < viewModel.inviteCode.count
                                ? AppColors.accentBlue
                                : Color.secondary.opacity(0.2)
                        )
                        .frame(width: 8, height: 8)
                }
            }
            
            Text("\(viewModel.inviteCode.count)/8 characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Looking Up View
    
    private var lookingUpView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Looking up invite...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Group Preview Card
    
    private func groupPreviewCard(_ result: FamilyInviteWithGroup) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.accentGreen)
                
                Text("Valid Invite Found!")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentGreen)
                
                Spacer()
            }
            
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
                        .frame(width: 50, height: 50)
                    
                    Text(String((result.familyGroup?.name ?? "F").prefix(2)).uppercased())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.familyGroup?.name ?? "Family Group")
                        .font(.headline)
                    
                    if let desc = result.familyGroup?.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                Label {
                    Text(FamilyMemberRole(rawValue: result.role ?? "viewer")?.displayName ?? "Viewer")
                        .font(.caption)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: FamilyMemberRole(rawValue: result.role ?? "viewer")?.icon ?? "eye.fill")
                        .font(.caption)
                }
                .foregroundColor(AppColors.accentBlue)
                
                if let expiresAt = result.expiresAt {
                    Label {
                        Text("Expires \(expiresAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                    } icon: {
                        Image(systemName: "clock")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.accentGreen.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.accentGreen.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Join Button
    
    private var joinButton: some View {
        Button {
            Task {
                if await viewModel.acceptInvite() {
                    dismiss()
                }
            }
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "person.badge.plus")
                    Text("Join Family")
                }
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.accentGreen)
        .disabled(viewModel.lookupResult == nil || viewModel.isSaving)
    }
}

#Preview {
    JoinFamilyView(viewModel: FamilyViewModel())
}
