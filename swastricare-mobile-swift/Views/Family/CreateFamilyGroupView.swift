//
//  CreateFamilyGroupView.swift
//  swastricare-mobile-swift
//
//  Create a new family group
//

import SwiftUI

struct CreateFamilyGroupView: View {
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case name, description
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        formSection
                        
                        infoSection
                        
                        createButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.resetCreateGroupState()
                        dismiss()
                    }
                }
            }
            .onAppear {
                focusedField = .name
            }
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
                    .frame(width: 80, height: 80)
                    .shadow(color: AppColors.accentBlue.opacity(0.3), radius: 15, y: 5)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 6) {
                Text("Create Your Family Group")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("Share health data and care for your loved ones together.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                TextField("e.g., The Smiths", text: $viewModel.newGroupName)
                    .font(.system(size: 17))
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                focusedField == .name ? AppColors.accentBlue : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .focused($focusedField, equals: .name)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Description")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("(Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                TextField("A brief description of your family group", text: $viewModel.newGroupDescription, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(3...5)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                focusedField == .description ? AppColors.accentBlue : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .focused($focusedField, equals: .description)
            }
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What you can do")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                FeatureRow(
                    icon: "heart.text.square.fill",
                    title: "Share Health Data",
                    description: "View and manage health records together"
                )
                
                FeatureRow(
                    icon: "pills.fill",
                    title: "Medication Tracking",
                    description: "Help family members stay on track"
                )
                
                FeatureRow(
                    icon: "person.badge.plus",
                    title: "Invite Members",
                    description: "Add caregivers and family members"
                )
                
                FeatureRow(
                    icon: "lock.shield.fill",
                    title: "Privacy Controls",
                    description: "Control who can see what"
                )
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Create Button
    
    private var createButton: some View {
        Button {
            Task {
                if await viewModel.createFamilyGroup() {
                    dismiss()
                }
            }
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Family Group")
                }
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.accentBlue)
        .disabled(viewModel.newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSaving)
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AppColors.accentBlue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    CreateFamilyGroupView(viewModel: FamilyViewModel())
}
