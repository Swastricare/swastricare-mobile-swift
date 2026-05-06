//
//  AccountView.swift
//  swastricare-mobile-swift
//
//  Android-parity Edit Profile screen.
//

import SwiftUI

struct AccountView: View {

    @StateObject private var viewModel = DependencyContainer.shared.profileViewModel
    @EnvironmentObject private var appVersionService: AppVersionService
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
    @State private var showDeleteConfirm = false

    private let bloodTypes = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]

    private let aiGreen = Color(hex: "22C55E")
    private let dangerRed = Color(hex: "EF4444")

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

    private var canSave: Bool {
        hasChanges && isValidForm && !isSaving
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    avatarBlock
                        .padding(.vertical, 16)

                    sectionHeader("Personal")
                    profileCard {
                        underlineField(label: "Full Name", value: $editedName, placeholder: "Full Name")
                        fieldDivider
                        underlineField(label: "Phone", value: $editedPhone, placeholder: "Add phone number", keyboardType: .phonePad)
                        fieldDivider
                        underlineField(label: "Bio", value: $editedBio, placeholder: "Write something about you")
                        fieldDivider
                        genderRow
                        fieldDivider
                        dateOfBirthRow
                        fieldDivider
                        underlineField(label: "City", value: $editedCity, placeholder: "Your city")
                    }

                    sectionHeader("Body Stats")
                    profileCard {
                        sliderRow(
                            label: "Height",
                            value: "\(Int(editedHeightCm)) cm",
                            binding: $editedHeightCm,
                            range: 100...250,
                            step: 1
                        )
                        fieldDivider
                        sliderRow(
                            label: "Weight",
                            value: String(format: "%.1f kg", editedWeightKg),
                            binding: $editedWeightKg,
                            range: 20...250,
                            step: 0.5
                        )
                        fieldDivider
                        bmiRow
                        fieldDivider
                        bloodTypeRow
                    }

                    sectionHeader("Account")
                    profileCard {
                        infoRow(label: "Email", value: viewModel.userEmail)
                        fieldDivider
                        infoRow(label: "Member Since", value: viewModel.memberSince)
                        fieldDivider
                        infoRow(label: "Version", value: viewModel.appVersion)
                    }

                    Spacer().frame(height: 12)

                    dangerZone
                        .padding(.horizontal, 16)

                    Spacer().frame(height: 32)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { Task { await saveProfile() } }) {
                    if isSaving {
                        ProgressView().tint(aiGreen)
                    } else {
                        Text("Save")
                            .font(.poppins(.bold, size: 15))
                            .foregroundColor(canSave ? aiGreen : .primary.opacity(0.3))
                    }
                }
                .disabled(!canSave)
            }
        }
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
        .alert("Delete Account", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
        .trackScreen("Account")
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

    // MARK: - Avatar block

    private var avatarBlock: some View {
        VStack(spacing: 6) {
            if let url = viewModel.userAvatarURL {
                AsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } placeholder: {
                    avatarFallback
                }
            } else {
                avatarFallback
            }
            Text(viewModel.userEmail)
                .font(.poppins(.regular, size: 13))
                .foregroundColor(.primary.opacity(0.45))
        }
    }

    private var avatarFallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "2E3192"), Color(hex: "4A90E2")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(Circle())
            Text(String(editedName.prefix(1)).uppercased())
                .font(.poppins(.bold, size: 30))
                .foregroundColor(.white)
        }
        .frame(width: 80, height: 80)
    }

    // MARK: - Section components

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.poppins(.semiBold, size: 12))
                .tracking(0.8)
                .foregroundColor(.primary.opacity(0.35))
            Spacer()
        }
        .padding(.leading, 20)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func profileCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
                .padding(.horizontal, 16)
        )
    }

    private var fieldDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
    }

    // MARK: - Underline field

    private func underlineField(
        label: String,
        value: Binding<String>,
        placeholder: String,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Text(label)
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.primary.opacity(0.5))
                .frame(width: 90, alignment: .leading)

            TextField(placeholder, text: value)
                .font(.poppins(.regular, size: 15))
                .foregroundColor(.primary)
                .tint(aiGreen)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .phonePad ? .never : .words)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Gender row

    private var genderRow: some View {
        HStack(spacing: 0) {
            Text("Gender")
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.primary.opacity(0.5))
                .frame(width: 90, alignment: .leading)

            Menu {
                ForEach(Gender.allCases, id: \.self) { g in
                    Button(g.displayName) { editedGender = g }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(editedGender.displayName)
                        .font(.poppins(.regular, size: 15))
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.primary.opacity(0.3))
                    Spacer()
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Date of birth row

    @State private var showDatePicker = false

    private var dateOfBirthRow: some View {
        Button(action: { showDatePicker = true }) {
            HStack(spacing: 0) {
                Text("Date of Birth")
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(.primary.opacity(0.5))
                    .frame(width: 90, alignment: .leading)

                HStack(spacing: 4) {
                    Text(formatDate(editedDateOfBirth))
                        .font(.poppins(.regular, size: 15))
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.primary.opacity(0.3))
                    Spacer()
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private var datePickerSheet: some View {
        VStack(spacing: 16) {
            Text("Date of Birth")
                .font(.poppins(.bold, size: 18))
                .padding(.top, 20)

            DatePicker(
                "",
                selection: $editedDateOfBirth,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .tint(aiGreen)

            Button(action: { showDatePicker = false }) {
                Text("Done")
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(aiGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .presentationDetents([.medium])
    }

    // MARK: - Body stats rows

    private func sliderRow(
        label: String,
        value: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(.primary.opacity(0.5))
                Spacer()
                Text(value)
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 4)

            Slider(value: binding, in: range, step: step)
                .tint(.primary.opacity(0.5))
                .frame(height: 32)
        }
        .padding(.vertical, 4)
    }

    private var bmiRow: some View {
        let heightM = editedHeightCm / 100
        let bmi = heightM > 0 ? editedWeightKg / (heightM * heightM) : 0
        return HStack {
            Text("BMI")
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.primary.opacity(0.5))
            Spacer()
            Text("\(String(format: "%.1f", bmi)) · \(bmiCategory(bmi))")
                .font(.poppins(.semiBold, size: 15))
                .foregroundColor(bmiColor(bmi))
        }
        .padding(.vertical, 12)
    }

    private var bloodTypeRow: some View {
        HStack {
            Text("Blood Type")
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.primary.opacity(0.5))
            Spacer()
            Menu {
                Button("Not set") { editedBloodType = "" }
                ForEach(bloodTypes, id: \.self) { t in
                    Button(t) { editedBloodType = t }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(editedBloodType.isEmpty ? "Not set" : editedBloodType)
                        .font(.poppins(.regular, size: 15))
                        .foregroundColor(editedBloodType.isEmpty ? .primary.opacity(0.3) : .primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.primary.opacity(0.3))
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Account info

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.primary.opacity(0.5))
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Danger zone

    private var dangerZone: some View {
        Button(action: { showDeleteConfirm = true }) {
            HStack {
                Spacer()
                Text("Delete Account")
                    .font(.poppins(.semiBold, size: 15))
                    .foregroundColor(dangerRed)
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(dangerRed.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

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

            var changedFields: [String] = []
            let hp = viewModel.healthProfile
            if trimmedName != viewModel.userName { changedFields.append("name") }
            if trimmedPhone != (viewModel.user?.phone ?? "") { changedFields.append("phone") }
            if trimmedBio != (viewModel.user?.bio ?? "") { changedFields.append("bio") }
            if editedGender != (hp?.gender ?? .preferNotToSay) { changedFields.append("gender") }
            if !Calendar.current.isDate(editedDateOfBirth, inSameDayAs: hp?.dateOfBirth ?? editedDateOfBirth) { changedFields.append("dateOfBirth") }
            if editedHeightCm != (hp?.heightCm ?? 170) { changedFields.append("heightCm") }
            if editedWeightKg != (hp?.weightKg ?? 70) { changedFields.append("weightKg") }
            if editedBloodType != (hp?.bloodType ?? "") { changedFields.append("bloodType") }
            if trimmedCity != (hp?.city ?? "") { changedFields.append("city") }
            AppAnalyticsService.shared.logProfileUpdated(fieldsChanged: changedFields.isEmpty ? ["profile"] : changedFields)
            showSaveSuccess = true
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }

    // MARK: - BMI helpers

    private func bmiColor(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return Color(hex: "FF9F0A")
        case 18.5..<25: return Color(hex: "34C759")
        case 25..<30: return Color(hex: "FF9F0A")
        default: return Color(hex: "FF3B30")
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

#Preview {
    NavigationStack {
        AccountView()
            .environmentObject(AppVersionService.shared)
    }
}
