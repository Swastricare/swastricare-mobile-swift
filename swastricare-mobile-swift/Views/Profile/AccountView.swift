//
//  AccountView.swift
//  swastricare-mobile-swift
//
//  Account Data Screen - Comprehensive user profile editor
//

import SwiftUI

struct AccountView: View {
    
    @StateObject private var viewModel = DependencyContainer.shared.profileViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Editable State
    
    @State private var editedName: String = ""
    @State private var editedPhone: String = ""
    @State private var editedBio: String = ""
    @State private var editedGender: Gender = .preferNotToSay
    @State private var editedDateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var editedHeightCm: Double = 170
    @State private var editedWeightKg: Double = 70
    @State private var editedBloodType: String = ""
    @State private var editedCity: String = ""
    
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var saveError: String?
    
    private let bloodTypes = ["", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]
    
    private var hasChanges: Bool {
        let hp = viewModel.healthProfile
        return editedName != viewModel.userName
            || editedPhone != (viewModel.user?.phone ?? "")
            || editedBio != (viewModel.user?.bio ?? "")
            || editedGender != (hp?.gender ?? .preferNotToSay)
            || editedHeightCm != (hp?.heightCm ?? 170)
            || editedWeightKg != (hp?.weightKg ?? 70)
            || editedBloodType != (hp?.bloodType ?? "")
            || editedCity != (hp?.city ?? "")
            || !Calendar.current.isDate(editedDateOfBirth, inSameDayAs: hp?.dateOfBirth ?? editedDateOfBirth)
    }
    
    private var isValidForm: Bool {
        !editedName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        ZStack {
            PremiumBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    avatarSection
                    
                    if (viewModel.user?.phone ?? "").isEmpty {
                        phoneMissingBanner
                    }
                    
                    personalInfoSection
                    
                    bodyStatsSection
                    
                    locationSection
                    
                    accountDetailsSection
                    
                    saveButton
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadCurrentValues() }
        .alert("Profile Updated", isPresented: $showSaveSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your account information has been saved successfully.")
        }
        .alert("Error", isPresented: .constant(saveError != nil)) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }
    
    private func loadCurrentValues() {
        let hp = viewModel.healthProfile
        editedName = viewModel.userName
        editedPhone = viewModel.user?.phone ?? ""
        editedBio = viewModel.user?.bio ?? ""
        editedGender = hp?.gender ?? .preferNotToSay
        editedDateOfBirth = hp?.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
        editedHeightCm = hp?.heightCm ?? 170
        editedWeightKg = hp?.weightKg ?? 70
        editedBloodType = hp?.bloodType ?? ""
        editedCity = hp?.city ?? ""
    }
    
    // MARK: - Avatar
    
    private var avatarSection: some View {
        VStack(spacing: 8) {
            if let avatarURL = viewModel.userAvatarURL {
                AsyncImage(url: avatarURL) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                } placeholder: {
                    avatarPlaceholder
                }
            } else {
                avatarPlaceholder
            }
            
            Text(viewModel.userEmail)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 88, height: 88)
            .overlay(
                Text(String(editedName.prefix(1)).uppercased())
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
            )
            .shadow(color: Color(hex: "2E3192").opacity(0.25), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Phone Missing Banner
    
    private var phoneMissingBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.badge.plus")
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Add your phone number")
                    .font(.system(size: 15, weight: .semibold))
                Text("Keep your account secure and recoverable")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Personal Info
    
    private var personalInfoSection: some View {
        AccountSection(title: "Personal Information") {
            VStack(spacing: 16) {
                AccountEditField(
                    title: "Full Name",
                    icon: "person.fill",
                    iconColor: .blue,
                    text: $editedName
                )
                
                AccountEditField(
                    title: "Phone Number",
                    icon: "phone.fill",
                    iconColor: .green,
                    text: $editedPhone,
                    keyboardType: .phonePad,
                    placeholder: "Add phone number"
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bio")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "text.quote")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                            .padding(.top, 10)
                        
                        TextField("Write something about yourself...", text: $editedBio, axis: .vertical)
                            .font(.system(size: 16))
                            .lineLimit(3...5)
                            .tint(Color(hex: "2E3192"))
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gender")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.indigo)
                            .frame(width: 24)
                        
                        Picker("Gender", selection: $editedGender) {
                            ForEach(Gender.allCases, id: \.self) { gender in
                                Text(gender.displayName).tag(gender)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.primary)
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date of Birth")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        DatePicker(
                            "",
                            selection: $editedDateOfBirth,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .tint(Color(hex: "2E3192"))
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - Body Stats
    
    private var bodyStatsSection: some View {
        AccountSection(title: "Body Stats") {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Height")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(editedHeightCm)) cm")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "2E3192"))
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "ruler.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        Slider(value: $editedHeightCm, in: 100...250, step: 1)
                            .tint(Color(hex: "2E3192"))
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Weight")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f kg", editedWeightKg))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "2E3192"))
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(.cyan)
                            .frame(width: 24)
                        
                        Slider(value: $editedWeightKg, in: 20...250, step: 0.5)
                            .tint(Color(hex: "2E3192"))
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                
                // BMI (computed, read-only)
                let heightM = editedHeightCm / 100
                let bmi = heightM > 0 ? editedWeightKg / (heightM * heightM) : 0
                HStack(spacing: 12) {
                    Image(systemName: "figure.stand")
                        .foregroundColor(.indigo)
                        .frame(width: 24)
                    Text("BMI")
                        .font(.system(size: 16))
                    Spacer()
                    Text(String(format: "%.1f", bmi))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(bmiColor(bmi))
                    Text(bmiCategory(bmi))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Blood Type")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "drop.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        Picker("Blood Type", selection: $editedBloodType) {
                            Text("Not set").tag("")
                            ForEach(bloodTypes.filter { !$0.isEmpty }, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.primary)
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - Location
    
    private var locationSection: some View {
        AccountSection(title: "Location") {
            AccountEditField(
                title: "City",
                icon: "location.fill",
                iconColor: .teal,
                text: $editedCity,
                placeholder: "Your city"
            )
        }
    }
    
    // MARK: - Account Details (Read-Only)
    
    private var accountDetailsSection: some View {
        AccountSection(title: "Account Details") {
            VStack(spacing: 0) {
                AccountReadOnlyRow(
                    icon: "envelope.fill",
                    iconColor: .indigo,
                    label: "Email",
                    value: viewModel.userEmail
                )
                
                Divider().padding(.leading, 52)
                
                AccountReadOnlyRow(
                    icon: "calendar.badge.clock",
                    iconColor: .orange,
                    label: "Member Since",
                    value: viewModel.memberSince
                )
            }
        }
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button(action: {
            Task { await saveProfile() }
        }) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Changes").fontWeight(.bold)
                }
            }
            .font(.system(size: 17))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                hasChanges && isValidForm
                    ? Color(hex: "2E3192")
                    : Color.gray.opacity(0.3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: hasChanges && isValidForm ? Color(hex: "2E3192").opacity(0.3) : .clear,
                radius: 12, y: 6
            )
        }
        .disabled(isSaving || !hasChanges || !isValidForm)
        .padding(.top, 4)
    }
    
    // MARK: - Save Action
    
    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            let trimmedName = editedName.trimmingCharacters(in: .whitespaces)
            let trimmedPhone = editedPhone.trimmingCharacters(in: .whitespaces)
            let trimmedBio = editedBio.trimmingCharacters(in: .whitespaces)
            let trimmedCity = editedCity.trimmingCharacters(in: .whitespaces)
            
            if viewModel.hasHealthProfile {
                try await viewModel.updateFullProfile(
                    fullName: trimmedName,
                    phone: trimmedPhone,
                    bio: trimmedBio,
                    gender: editedGender,
                    dateOfBirth: editedDateOfBirth,
                    heightCm: editedHeightCm,
                    weightKg: editedWeightKg,
                    bloodType: editedBloodType,
                    city: trimmedCity
                )
            } else {
                try await viewModel.updateUserProfile(
                    fullName: trimmedName,
                    phone: trimmedPhone,
                    bio: trimmedBio
                )
            }
            showSaveSuccess = true
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    // MARK: - BMI Helpers
    
    private func bmiColor(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return .orange
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }
    
    private func bmiCategory(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }
}

// MARK: - Section Container

private struct AccountSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
            
            VStack(spacing: 16) {
                content
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
    }
}

// MARK: - Editable Field

private struct AccountEditField: View {
    let title: String
    let icon: String
    let iconColor: Color
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var placeholder: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                TextField(placeholder.isEmpty ? title : placeholder, text: $text)
                    .font(.system(size: 16))
                    .tint(Color(hex: "2E3192"))
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .phonePad ? .never : .words)
            }
            .padding(14)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: - Read-Only Row

private struct AccountReadOnlyRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(value.isEmpty ? "Not available" : value)
                    .font(.system(size: 16))
            }
            
            Spacer()
            
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

#Preview {
    NavigationStack {
        AccountView()
    }
}
