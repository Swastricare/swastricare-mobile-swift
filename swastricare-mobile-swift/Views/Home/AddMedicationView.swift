//
//  AddMedicationView.swift
//  swastricare-mobile-swift
//
//  Single-scroll form for adding medications with drug search,
//  custom time pickers, and flexible duration options.
//

import SwiftUI

// MARK: - Duration Mode

private enum DurationMode: String, CaseIterable {
    case ongoing, preset, manual, quantity

    var label: String {
        switch self {
        case .ongoing:  return "Ongoing"
        case .preset:   return "Preset"
        case .manual:   return "End Date"
        case .quantity: return "Quantity"
        }
    }

    var icon: String {
        switch self {
        case .ongoing:  return "infinity"
        case .preset:   return "timer"
        case .manual:   return "calendar"
        case .quantity: return "function"
        }
    }
}

// MARK: - Duration Preset

private struct DurationPreset: Identifiable, Equatable {
    let id: String
    let label: String
    let days: Int

    static let all: [DurationPreset] = [
        .init(id: "7d",  label: "7 days",    days: 7),
        .init(id: "14d", label: "14 days",   days: 14),
        .init(id: "1m",  label: "1 month",   days: 30),
        .init(id: "3m",  label: "3 months",  days: 90),
        .init(id: "6m",  label: "6 months",  days: 180),
    ]
}

// MARK: - Schedule Option

private enum ScheduleOption: String, CaseIterable {
    case once, twice, thrice, custom

    var label: String {
        switch self {
        case .once:   return "Once"
        case .twice:  return "Twice"
        case .thrice: return "Thrice"
        case .custom: return "Custom"
        }
    }

    var frequency: String {
        switch self {
        case .once:   return "1x"
        case .twice:  return "2x"
        case .thrice: return "3x"
        case .custom: return "⚙"
        }
    }

    var defaultTimeCount: Int {
        switch self {
        case .once:   return 1
        case .twice:  return 2
        case .thrice: return 3
        case .custom: return 1
        }
    }

    func toMedicationSchedule(times: [Date]) -> MedicationSchedule {
        switch self {
        case .once:   return .onceDaily
        case .twice:  return .twiceDaily
        case .thrice: return .thriceDaily
        case .custom: return .custom(times)
        }
    }
}

// MARK: - Theme Colors

private let medAccent = AppColors.medication          // #5856D6 — unified medication accent
private let tealGreen = Color(hex: "10B981")         // Emerald green for success states

// MARK: - AddMedicationView

struct AddMedicationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: MedicationViewModel

    // Form state
    @State private var name = ""
    @State private var dosage = ""
    @State private var dosageUnit = ""
    @State private var selectedType: MedicationType = .pill
    @State private var scheduleOption: ScheduleOption = .once
    @State private var scheduleTimes: [(label: String, time: Date)] = []
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var notes = ""

    // Duration
    @State private var durationMode: DurationMode = .ongoing
    @State private var selectedPreset: DurationPreset?

    // Quantity
    @State private var totalQuantity = ""
    @State private var dosagePerIntake = "1"

    // UI state
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showTimePickerForIndex: Int? = nil
    @State private var suppressSearch = false

    init(viewModel: MedicationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // Computed
    private var canSave: Bool { !name.isEmpty }

    private var dosesPerDay: Int {
        scheduleOption == .custom ? scheduleTimes.count : scheduleOption.defaultTimeCount
    }

    private var calculatedDays: Int? {
        guard let total = Int(totalQuantity), total > 0,
              let perDose = Int(dosagePerIntake), perDose > 0,
              dosesPerDay > 0 else { return nil }
        return Int(ceil(Double(total) / Double(dosesPerDay * perDose)))
    }

    private var calculatedEndDate: Date? {
        guard let days = calculatedDays else { return nil }
        return Calendar.current.date(byAdding: .day, value: days - 1, to: startDate)
    }

    private var isOngoing: Bool { durationMode == .ongoing }

    private var effectiveEndDate: Date? {
        switch durationMode {
        case .ongoing: return nil
        case .preset:
            guard let preset = selectedPreset else { return nil }
            return Calendar.current.date(byAdding: .day, value: preset.days, to: startDate)
        case .manual: return endDate
        case .quantity: return calculatedEndDate
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            medicationDetailsSection
                            drugInfoSection
                            typeSection
                            scheduleSection
                            durationSection
                            notesSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 120)
                    }

                    saveButton
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.clearDrugSearch()
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                resetScheduleTimes()
            }
            .onChange(of: scheduleOption) { _ in
                resetScheduleTimes()
            }
            .onChange(of: selectedPreset) { preset in
                if let preset = preset {
                    endDate = Calendar.current.date(byAdding: .day, value: preset.days, to: startDate) ?? endDate
                }
            }
            .onChange(of: calculatedEndDate) { newEnd in
                if durationMode == .quantity, let newEnd = newEnd {
                    endDate = newEnd
                }
            }
            .sheet(item: $showTimePickerForIndex) { index in
                TimePickerSheet(
                    label: scheduleTimes[index.self].label,
                    time: Binding(
                        get: { scheduleTimes[index].time },
                        set: { scheduleTimes[index].time = $0 }
                    )
                )
            }
        }
    }

    // MARK: - Section 1: Medication Details + Drug Search

    private var medicationDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Medication Details")

            // Name with search
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15))
                    TextField("Search or type medication name", text: $name)
                        .autocapitalization(.words)
                        .onChange(of: name) { newValue in
                            if suppressSearch {
                                suppressSearch = false
                                return
                            }
                            viewModel.searchDrug(query: newValue)
                        }
                    if viewModel.isSearching {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if !name.isEmpty {
                        Button {
                            name = ""
                            viewModel.clearDrugSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)

                // Suggestions dropdown
                if !viewModel.drugSuggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(viewModel.drugSuggestions) { drug in
                            Button {
                                suppressSearch = true
                                viewModel.clearDrugSearch()
                                name = drug.displayName
                                dosage = drug.dosage ?? ""
                                dosageUnit = drug.dosageUnit ?? ""
                                viewModel.selectDrug(drug)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "pills.fill")
                                        .foregroundColor(medAccent)
                                        .font(.system(size: 14))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(drug.displayName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.primary)
                                        if let generic = drug.genericName {
                                            Text(generic)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                            Divider().padding(.leading, 40)
                        }
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                }
            }

            // Dosage + Unit
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dosage")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("e.g., 500", text: $dosage)
                        .textFieldStyle(PremiumTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("mg, ml", text: $dosageUnit)
                        .textFieldStyle(PremiumTextFieldStyle())
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Drug Info Section (FDA)

    @ViewBuilder
    private var drugInfoSection: some View {
        if let details = viewModel.drugDetails {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Drug Information (FDA)")

                if let desc = details.description {
                    ExpandableInfoRow(
                        icon: "info.circle.fill",
                        label: "Indications",
                        text: desc,
                        color: medAccent
                    )
                }
                if let warnings = details.warnings {
                    ExpandableInfoRow(
                        icon: "exclamationmark.triangle.fill",
                        label: "Warnings",
                        text: warnings,
                        color: .red
                    )
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Section 2: Type

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Type")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(MedicationType.allCases, id: \.self) { type in
                        chipButton(
                            icon: type.icon,
                            label: type.displayName,
                            isSelected: selectedType == type
                        ) { selectedType = type }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Section 3: Schedule + Time Pickers

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Schedule")

            // Frequency chips
            HStack(spacing: 8) {
                ForEach(ScheduleOption.allCases, id: \.self) { option in
                    frequencyChip(option)
                }
            }

            // Editable time rows
            ForEach(scheduleTimes.indices, id: \.self) { index in
                editableTimeRow(index: index)
            }

            // Add time slot (custom only)
            if scheduleOption == .custom {
                Button {
                    let lastHour = Calendar.current.component(.hour, from: scheduleTimes.last?.time ?? Date())
                    let nextHour = min(lastHour + 4, 23)
                    let newTime = Calendar.current.date(bySettingHour: nextHour, minute: 0, second: 0, of: Date()) ?? Date()
                    let label = timeLabelForIndex(scheduleTimes.count)
                    scheduleTimes.append((label: label, time: newTime))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add Time Slot")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(medAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(medAccent.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Section 4: Duration (Full Customization)

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Duration")

            // Start date (today or earlier — no future dates)
            dateRow(label: "Start Date", date: $startDate, maxDate: Date())

            // Duration mode grid (2x2)
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach([DurationMode.ongoing, .preset], id: \.self) { mode in
                        durationModeChip(mode)
                    }
                }
                HStack(spacing: 8) {
                    ForEach([DurationMode.manual, .quantity], id: \.self) { mode in
                        durationModeChip(mode)
                    }
                }
            }

            // Preset durations
            if durationMode == .preset {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DurationPreset.all) { preset in
                            presetChip(preset)
                        }
                    }
                }

                if let preset = selectedPreset,
                   let presetEnd = Calendar.current.date(byAdding: .day, value: preset.days, to: startDate) {
                    calculatedDateBanner(text: "Ends \(formatDate(presetEnd))")
                }
            }

            // Manual end date
            if durationMode == .manual {
                dateRow(label: "End Date", date: $endDate, minDate: startDate)
            }

            // Quantity calculation
            if durationMode == .quantity {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Total tablets")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("e.g., 30", text: $totalQuantity)
                            .textFieldStyle(PremiumTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Per dose")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("1", text: $dosagePerIntake)
                            .textFieldStyle(PremiumTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                }

                if let days = calculatedDays, let calcEnd = calculatedEndDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalQuantity) tablets  x  \(dosagePerIntake) per dose  x  \(dosesPerDay)x/day")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        calculatedDateBanner(text: "\(days) days — ends \(formatDate(calcEnd))")
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Section 5: Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Notes (Optional)")

            TextEditor(text: $notes)
                .frame(height: 100)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(12)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        VStack {
            Button {
                saveMedication()
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save Medication")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(canSave ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? AppColors.medication : Color(UIColor.tertiarySystemFill))
                .cornerRadius(16)
            }
            .disabled(!canSave || isLoading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            Color(UIColor.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
        )
    }

    // MARK: - Reusable Components

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .tracking(0.5)
    }

    private func chipButton(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? medAccent : Color(UIColor.tertiarySystemFill))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func frequencyChip(_ option: ScheduleOption) -> some View {
        let isSelected = scheduleOption == option
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                scheduleOption = option
            }
        } label: {
            VStack(spacing: 2) {
                Text(option.frequency)
                    .font(.system(size: 18, weight: .bold))
                Text(option.label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : medAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? medAccent : Color(UIColor.tertiarySystemFill))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func editableTimeRow(index: Int) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                Text(scheduleTimes[index].label)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Text(formatTime(scheduleTimes[index].time))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(medAccent)

                if scheduleOption == .custom && scheduleTimes.count > 1 {
                    Button {
                        scheduleTimes.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red.opacity(0.6))
                            .font(.system(size: 14))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(UIColor.tertiarySystemFill))
        .cornerRadius(10)
        .onTapGesture {
            showTimePickerForIndex = index
        }
    }

    private func durationModeChip(_ mode: DurationMode) -> some View {
        let isSelected = durationMode == mode
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                durationMode = mode
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14))
                Text(mode.label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? medAccent : Color(UIColor.tertiarySystemFill))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func presetChip(_ preset: DurationPreset) -> some View {
        let isSelected = selectedPreset == preset
        return Button {
            selectedPreset = preset
        } label: {
            Text(preset.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? medAccent : Color(UIColor.tertiarySystemFill))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func dateRow(label: String, date: Binding<Date>, minDate: Date? = nil, maxDate: Date? = nil) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(medAccent)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Group {
                if let min = minDate, let max = maxDate {
                    DatePicker("", selection: date, in: min...max, displayedComponents: .date)
                } else if let min = minDate {
                    DatePicker("", selection: date, in: min..., displayedComponents: .date)
                } else if let max = maxDate {
                    DatePicker("", selection: date, in: ...max, displayedComponents: .date)
                } else {
                    DatePicker("", selection: date, displayedComponents: .date)
                }
            }
            .labelsHidden()
            .tint(medAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(UIColor.tertiarySystemFill))
        .cornerRadius(12)
    }

    private func calculatedDateBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(tealGreen)
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tealGreen)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(tealGreen.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tealGreen.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func resetScheduleTimes() {
        let calendar = Calendar.current
        let today = Date()

        switch scheduleOption {
        case .once:
            scheduleTimes = [
                ("Morning", calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today)
            ]
        case .twice:
            scheduleTimes = [
                ("Morning", calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today),
                ("Evening", calendar.date(bySettingHour: 20, minute: 0, second: 0, of: today) ?? today)
            ]
        case .thrice:
            scheduleTimes = [
                ("Morning", calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today),
                ("Afternoon", calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today) ?? today),
                ("Evening", calendar.date(bySettingHour: 20, minute: 0, second: 0, of: today) ?? today)
            ]
        case .custom:
            scheduleTimes = [
                ("Dose 1", calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today)
            ]
        }
    }

    private func timeLabelForIndex(_ index: Int) -> String {
        switch index {
        case 0: return "Morning"
        case 1: return "Afternoon"
        case 2: return "Evening"
        case 3: return "Night"
        default: return "Dose \(index + 1)"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func saveMedication() {
        isLoading = true

        let times = scheduleTimes.map(\.time)
        let schedule = scheduleOption.toMedicationSchedule(times: times)

        Task {
            do {
                try await viewModel.addMedication(
                    name: name,
                    dosage: [dosage, dosageUnit].filter { !$0.isEmpty }.joined(separator: " "),
                    type: selectedType,
                    scheduleTemplate: schedule,
                    scheduledTimes: times,
                    startDate: startDate,
                    endDate: isOngoing ? nil : effectiveEndDate,
                    isOngoing: isOngoing,
                    notes: notes.isEmpty ? nil : notes
                )
                await MainActor.run {
                    isLoading = false
                    viewModel.clearDrugSearch()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Expandable Info Row

private struct ExpandableInfoRow: View {
    let icon: String
    let label: String
    let text: String
    let color: Color
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 14))
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(color)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(color.opacity(0.5))
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary.opacity(0.7))
                    .lineSpacing(4)
                    .padding(.top, 8)
            }
        }
        .padding(12)
        .background(color.opacity(0.06))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Time Picker Sheet

private struct TimePickerSheet: View {
    let label: String
    @Binding var time: Date
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Set \(label) Time",
                    selection: $time,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Set \(label) Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}

// MARK: - Int Identifiable Extension (for sheet binding)

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Premium Text Field Style

struct PremiumTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(UIColor.tertiarySystemFill))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .foregroundColor(.primary)
    }
}

#Preview {
    AddMedicationView(viewModel: MedicationViewModel())
}
