//
//  AddMedicationView.swift
//  swastricare-mobile-swift
//

import SwiftUI

// MARK: - Step Enum

private enum AddMedicationStep: Int, CaseIterable {
    case name = 0, dosage, type, schedule, duration, review

    var title: String {
        switch self {
        case .name:     return "What medication?"
        case .dosage:   return "What's the dosage?"
        case .type:     return "Medication type"
        case .schedule: return "How often?"
        case .duration: return "How long?"
        case .review:   return "Review & Save"
        }
    }

    var subtitle: String {
        switch self {
        case .name:     return "Search or type the medication name"
        case .dosage:   return "Enter the dosage amount and unit"
        case .type:     return "Choose the medication form"
        case .schedule: return "Set your daily reminder times"
        case .duration: return "Set the treatment period"
        case .review:   return "Confirm your medication details"
        }
    }
}

// MARK: - Duration Mode

private enum DurationMode: String, CaseIterable {
    case ongoing, preset, manual, quantity

    var label: String {
        switch self {
        case .ongoing:  return "Ongoing"
        case .preset:   return "Fixed Duration"
        case .manual:   return "End Date"
        case .quantity: return "By Quantity"
        }
    }

    var description: String {
        switch self {
        case .ongoing:  return "No end date, until stopped"
        case .preset:   return "Choose from common durations"
        case .manual:   return "Pick a specific end date"
        case .quantity: return "Based on total tablet count"
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
        .init(id: "7d",  label: "7 days",   days: 7),
        .init(id: "14d", label: "14 days",  days: 14),
        .init(id: "1m",  label: "1 month",  days: 30),
        .init(id: "3m",  label: "3 months", days: 90),
        .init(id: "6m",  label: "6 months", days: 180),
    ]
}

// MARK: - Schedule Option

private enum ScheduleOption: String, CaseIterable {
    case once, twice, thrice, custom

    var label: String {
        switch self {
        case .once:   return "Once"
        case .twice:  return "Twice"
        case .thrice: return "Three times"
        case .custom: return "Custom"
        }
    }

    var subtitle: String {
        switch self {
        case .once:   return "1 dose per day"
        case .twice:  return "2 doses per day"
        case .thrice: return "3 doses per day"
        case .custom: return "Set your own times"
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

// MARK: - AddMedicationView

struct AddMedicationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: MedicationViewModel

    @State private var currentStep: AddMedicationStep = .name

    // Form fields
    @State private var name = ""
    @State private var dosage = ""
    @State private var dosageUnit = ""
    @State private var selectedType: MedicationType = .pill
    @State private var scheduleOption: ScheduleOption = .once
    @State private var scheduleTimes: [(label: String, time: Date)] = []
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var durationMode: DurationMode = .ongoing
    @State private var selectedPreset: DurationPreset?
    @State private var totalQuantity = ""
    @State private var dosagePerIntake = "1"

    // UI flags
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showTimePickerForIndex: Int? = nil
    @State private var suppressSearch = false

    private let accent = AppColors.accentBlue

    init(viewModel: MedicationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var canProceed: Bool {
        if currentStep == .name { return !name.isEmpty }
        return true
    }

    private var isOngoing: Bool { durationMode == .ongoing }

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

    private var effectiveEndDate: Date? {
        switch durationMode {
        case .ongoing:  return nil
        case .preset:
            guard let preset = selectedPreset else { return nil }
            return Calendar.current.date(byAdding: .day, value: preset.days, to: startDate)
        case .manual:   return endDate
        case .quantity: return calculatedEndDate
        }
    }

    private var fullDosage: String {
        [dosage, dosageUnit].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private var durationSummary: String {
        switch durationMode {
        case .ongoing:  return "Ongoing"
        case .preset:   return selectedPreset?.label ?? "Preset"
        case .manual:   return "Until \(formatDate(endDate))"
        case .quantity:
            if let days = calculatedDays { return "\(days) days" }
            return "By quantity"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                topNavBar
                progressBarView

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        stepHeader
                        stepBody
                            .id(currentStep)
                            .transition(.opacity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 110)
                }
            }

            bottomBar
        }
        .onAppear { resetScheduleTimes() }
        .onChange(of: scheduleOption) { _ in resetScheduleTimes() }
        .onChange(of: selectedPreset) { preset in
            if let preset = preset {
                endDate = Calendar.current.date(byAdding: .day, value: preset.days, to: startDate) ?? endDate
            }
        }
        .onChange(of: calculatedEndDate) { newEnd in
            if durationMode == .quantity, let newEnd = newEnd { endDate = newEnd }
        }
        .sheet(item: $showTimePickerForIndex) { index in
            TimePickerSheet(
                label: scheduleTimes[index].label,
                time: Binding(
                    get: { scheduleTimes[index].time },
                    set: { scheduleTimes[index].time = $0 }
                )
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .trackScreen("AddMedication")
    }

    // MARK: - Top Nav Bar

    private var topNavBar: some View {
        HStack {
            Button {
                if currentStep == .name {
                    viewModel.clearDrugSearch()
                    dismiss()
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentStep = AddMedicationStep(rawValue: currentStep.rawValue - 1)!
                    }
                }
            } label: {
                Image(systemName: currentStep == .name ? "xmark" : "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 38, height: 38)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Step \(currentStep.rawValue + 1) of \(AddMedicationStep.allCases.count)")
                .font(.poppins(.medium, size: 13))
                .foregroundColor(.secondary)

            Spacer()

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Progress Bar

    private var progressBarView: some View {
        HStack(spacing: 5) {
            ForEach(0..<AddMedicationStep.allCases.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(index <= currentStep.rawValue ? accent : Color(.systemGray5))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Step Header

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(currentStep.title)
                .font(.poppins(.bold, size: 28))
                .foregroundColor(.primary)
            Text(currentStep.subtitle)
                .font(.poppins(.regular, size: 15))
                .foregroundColor(.secondary)
        }
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    // MARK: - Step Body

    @ViewBuilder
    private var stepBody: some View {
        switch currentStep {
        case .name:     nameStep
        case .dosage:   dosageStep
        case .type:     typeStep
        case .schedule: scheduleStep
        case .duration: durationStep
        case .review:   reviewStep
        }
    }

    // MARK: - Step 1: Name

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("e.g., Paracetamol, Metformin", text: $name)
                    .autocapitalization(.words)
                    .font(.poppins(.regular, size: 16))
                    .onChange(of: name) { newValue in
                        if suppressSearch { suppressSearch = false; return }
                        viewModel.searchDrug(query: newValue)
                    }
                if viewModel.isSearching {
                    ProgressView().scaleEffect(0.75)
                } else if !name.isEmpty {
                    Button {
                        name = ""
                        viewModel.clearDrugSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(14)

            if !viewModel.drugSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.drugSuggestions.enumerated()), id: \.offset) { idx, drug in
                        Button {
                            suppressSearch = true
                            viewModel.clearDrugSearch()
                            name = drug.displayName
                            dosage = drug.dosage ?? ""
                            dosageUnit = drug.dosageUnit ?? ""
                            viewModel.selectDrug(drug)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(accent.opacity(0.12)).frame(width: 40, height: 40)
                                    Image(systemName: "pills.fill")
                                        .foregroundColor(accent).font(.system(size: 16))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(drug.displayName)
                                        .font(.poppins(.semiBold, size: 15)).foregroundColor(.primary)
                                    if let generic = drug.genericName {
                                        Text(generic)
                                            .font(.poppins(.regular, size: 13))
                                            .foregroundColor(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .foregroundColor(.secondary.opacity(0.5)).font(.system(size: 12))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                        }
                        if idx < viewModel.drugSuggestions.count - 1 {
                            Divider().padding(.leading, 66)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(14)
            }
        }
    }

    // MARK: - Step 2: Dosage

    private var dosageStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.poppins(.semiBold, size: 14)).foregroundColor(.secondary)
                TextField("e.g., 500", text: $dosage)
                    .keyboardType(.decimalPad)
                    .font(.poppins(.regular, size: 16))
                    .padding(.horizontal, 16).padding(.vertical, 16)
                    .background(Color(.systemGray6)).cornerRadius(14)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Unit")
                    .font(.poppins(.semiBold, size: 14)).foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["mg", "ml", "mcg", "IU", "tablet", "capsule", "drops", "puffs"], id: \.self) { unit in
                            Button {
                                dosageUnit = unit
                            } label: {
                                Text(unit)
                                    .font(.poppins(.semiBold, size: 14))
                                    .foregroundColor(dosageUnit == unit ? .white : .primary)
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    .background(dosageUnit == unit ? accent : Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                TextField("Or type unit manually", text: $dosageUnit)
                    .font(.poppins(.regular, size: 16))
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color(.systemGray6)).cornerRadius(14)
            }

            if let details = viewModel.drugDetails {
                if let desc = details.description {
                    ExpandableInfoRow(icon: "info.circle.fill", label: "Indications", text: desc, color: accent)
                }
                if let warnings = details.warnings {
                    ExpandableInfoRow(icon: "exclamationmark.triangle.fill", label: "Warnings", text: warnings, color: .red)
                }
            }
        }
    }

    // MARK: - Step 3: Type

    private var typeStep: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(MedicationType.allCases, id: \.self) { medType in
                typeCard(medType)
            }
        }
    }

    private func typeCard(_ medType: MedicationType) -> some View {
        let isSelected = selectedType == medType
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedType = medType }
        } label: {
            VStack(spacing: 12) {
                Image(systemName: medType.icon)
                    .font(.system(size: 30))
                    .foregroundColor(isSelected ? .white : accent)
                Text(medType.displayName)
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isSelected ? accent : Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 4: Schedule

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(ScheduleOption.allCases, id: \.self) { option in
                frequencyRow(option)
            }

            if !scheduleTimes.isEmpty {
                Divider().padding(.vertical, 4)

                Text("Scheduled Times")
                    .font(.poppins(.semiBold, size: 14)).foregroundColor(.secondary)

                ForEach(scheduleTimes.indices, id: \.self) { idx in
                    timeSlotCard(index: idx)
                }

                if scheduleOption == .custom {
                    Button {
                        let lastHour = Calendar.current.component(.hour, from: scheduleTimes.last?.time ?? Date())
                        let nextHour = min(lastHour + 4, 23)
                        let newTime = Calendar.current.date(bySettingHour: nextHour, minute: 0, second: 0, of: Date()) ?? Date()
                        scheduleTimes.append((label: timeLabelForIndex(scheduleTimes.count), time: newTime))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus").font(.system(size: 14, weight: .semibold))
                            Text("Add Time Slot").font(.poppins(.semiBold, size: 14))
                        }
                        .foregroundColor(accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.3), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func frequencyRow(_ option: ScheduleOption) -> some View {
        let isSelected = scheduleOption == option
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { scheduleOption = option }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label + " daily")
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(option.subtitle)
                        .font(.poppins(.regular, size: 13))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white).font(.system(size: 22))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(isSelected ? accent : Color(.systemGray6))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private func timeSlotCard(index: Int) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "clock").foregroundColor(.secondary).font(.system(size: 14))
                Text(scheduleTimes[index].label)
                    .font(.poppins(.regular, size: 14)).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                Text(formatTime(scheduleTimes[index].time))
                    .font(.poppins(.semiBold, size: 15)).foregroundColor(accent)
                if scheduleOption == .custom && scheduleTimes.count > 1 {
                    Button {
                        scheduleTimes.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red.opacity(0.6)).font(.system(size: 16))
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(accent.opacity(0.06))
        .cornerRadius(12)
        .onTapGesture { showTimePickerForIndex = index }
    }

    // MARK: - Step 5: Duration

    private var durationStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "calendar").foregroundColor(accent)
                    Text("Start Date").font(.poppins(.regular, size: 15)).foregroundColor(.secondary)
                }
                Spacer()
                DatePicker("", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    .labelsHidden().tint(accent)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color(.systemGray6)).cornerRadius(14)

            ForEach(DurationMode.allCases, id: \.self) { mode in
                durationModeCard(mode)
            }

            if durationMode == .preset {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DurationPreset.all) { preset in presetChip(preset) }
                    }
                }
                if let preset = selectedPreset,
                   let end = Calendar.current.date(byAdding: .day, value: preset.days, to: startDate) {
                    calculatedBanner("Ends \(formatDate(end))")
                }
            }

            if durationMode == .manual {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark").foregroundColor(accent)
                        Text("End Date").font(.poppins(.regular, size: 15)).foregroundColor(.secondary)
                    }
                    Spacer()
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .labelsHidden().tint(accent)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color(.systemGray6)).cornerRadius(14)
            }

            if durationMode == .quantity {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Total tablets").font(.poppins(.medium, size: 13)).foregroundColor(.secondary)
                        TextField("e.g., 30", text: $totalQuantity)
                            .keyboardType(.numberPad)
                            .font(.poppins(.regular, size: 16))
                            .padding(.horizontal, 14).padding(.vertical, 14)
                            .background(Color(.systemGray6)).cornerRadius(12)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Per dose").font(.poppins(.medium, size: 13)).foregroundColor(.secondary)
                        TextField("1", text: $dosagePerIntake)
                            .keyboardType(.numberPad)
                            .font(.poppins(.regular, size: 16))
                            .padding(.horizontal, 14).padding(.vertical, 14)
                            .background(Color(.systemGray6)).cornerRadius(12)
                    }
                }
                if let days = calculatedDays, let calcEnd = calculatedEndDate {
                    calculatedBanner("\(days) days — ends \(formatDate(calcEnd))")
                }
            }
        }
    }

    private func durationModeCard(_ mode: DurationMode) -> some View {
        let isSelected = durationMode == mode
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { durationMode = mode }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.white.opacity(0.2) : accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: mode.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.label)
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(mode.description)
                        .font(.poppins(.regular, size: 13))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white).font(.system(size: 22))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(isSelected ? accent : Color(.systemGray6))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private func presetChip(_ preset: DurationPreset) -> some View {
        let isSelected = selectedPreset == preset
        return Button { selectedPreset = preset } label: {
            Text(preset.label)
                .font(.poppins(.semiBold, size: 14))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(isSelected ? accent : Color(.systemGray6))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func calculatedBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").foregroundColor(accent).font(.system(size: 14))
            Text(text).font(.poppins(.semiBold, size: 14)).foregroundColor(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(accent.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Step 6: Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                reviewRow(icon: "pills.fill",      label: "Name",      value: name.isEmpty ? "—" : name)
                Divider().padding(.leading, 52)
                reviewRow(icon: "ruler",           label: "Dosage",    value: fullDosage.isEmpty ? "—" : fullDosage)
                Divider().padding(.leading, 52)
                reviewRow(icon: selectedType.icon, label: "Type",      value: selectedType.displayName)
                Divider().padding(.leading, 52)
                reviewRow(icon: "clock.fill",      label: "Frequency", value: "\(scheduleOption.label) daily")
                Divider().padding(.leading, 52)
                reviewRow(icon: "calendar",        label: "Duration",  value: durationSummary)
            }
            .background(Color(.systemGray6))
            .cornerRadius(16)

            VStack(alignment: .leading, spacing: 8) {
                Text("Scheduled Times")
                    .font(.poppins(.semiBold, size: 14)).foregroundColor(.secondary)
                ForEach(scheduleTimes.indices, id: \.self) { idx in
                    HStack {
                        Text(scheduleTimes[idx].label)
                            .font(.poppins(.regular, size: 14)).foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(scheduleTimes[idx].time))
                            .font(.poppins(.semiBold, size: 14)).foregroundColor(accent)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(accent.opacity(0.06))
                    .cornerRadius(10)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (Optional)")
                    .font(.poppins(.semiBold, size: 14)).foregroundColor(.secondary)
                ZStack(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Add any special instructions...")
                            .font(.poppins(.regular, size: 14))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .scrollContentBackground(.hidden)
                        .font(.poppins(.regular, size: 14))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }
                .background(Color(.systemGray6))
                .cornerRadius(14)
            }
        }
    }

    private func reviewRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(accent)
                .frame(width: 36, height: 36)
                .background(accent.opacity(0.1))
                .clipShape(Circle())
            Text(label)
                .font(.poppins(.regular, size: 14)).foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.poppins(.semiBold, size: 14)).foregroundColor(.primary)
                .multilineTextAlignment(.trailing).lineLimit(2)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if currentStep != .name {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentStep = AddMedicationStep(rawValue: currentStep.rawValue - 1)!
                        }
                    } label: {
                        Text("Back")
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                    }
                    .frame(maxWidth: 110)
                }

                Button {
                    if currentStep == .review {
                        saveMedication()
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentStep = AddMedicationStep(rawValue: currentStep.rawValue + 1)!
                        }
                    }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(currentStep == .review ? "Save Medication" : "Next  →")
                                .font(.poppins(.semiBold, size: 16))
                        }
                    }
                    .foregroundColor(canProceed ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canProceed ? accent : Color(.systemGray5))
                    .cornerRadius(14)
                }
                .disabled(!canProceed || isLoading)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Color.white)
    }

    // MARK: - Helpers

    private func resetScheduleTimes() {
        let cal = Calendar.current
        let today = Date()
        switch scheduleOption {
        case .once:
            scheduleTimes = [("Morning",   cal.date(bySettingHour: 9,  minute: 0, second: 0, of: today) ?? today)]
        case .twice:
            scheduleTimes = [
                ("Morning",   cal.date(bySettingHour: 9,  minute: 0, second: 0, of: today) ?? today),
                ("Evening",   cal.date(bySettingHour: 21, minute: 0, second: 0, of: today) ?? today)
            ]
        case .thrice:
            scheduleTimes = [
                ("Morning",   cal.date(bySettingHour: 9,  minute: 0, second: 0, of: today) ?? today),
                ("Afternoon", cal.date(bySettingHour: 13, minute: 0, second: 0, of: today) ?? today),
                ("Evening",   cal.date(bySettingHour: 21, minute: 0, second: 0, of: today) ?? today)
            ]
        case .custom:
            scheduleTimes = [("Dose 1",    cal.date(bySettingHour: 9,  minute: 0, second: 0, of: today) ?? today)]
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
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f.string(from: date)
    }

    private func saveMedication() {
        isLoading = true
        let times = scheduleTimes.map(\.time)
        let schedule = scheduleOption.toMedicationSchedule(times: times)
        Task {
            do {
                try await viewModel.addMedication(
                    name: name,
                    dosage: fullDosage,
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
                    errorMessage = UserFriendlyError.message(from: error)
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon).foregroundColor(color).font(.system(size: 14))
                    Text(label).font(.poppins(.semiBold, size: 13)).foregroundColor(color)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(color.opacity(0.5)).font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            if isExpanded {
                Text(text)
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(.primary.opacity(0.7))
                    .lineSpacing(4).padding(.top, 8)
            }
        }
        .padding(12)
        .background(color.opacity(0.06))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.1), lineWidth: 1))
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
                DatePicker("Set \(label) Time", selection: $time, displayedComponents: .hourAndMinute)
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

// MARK: - Extensions

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Premium Text Field Style

struct PremiumTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.poppins(.regular, size: 16))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(UIColor.tertiarySystemFill))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .foregroundColor(.primary)
    }
}

#Preview {
    AddMedicationView(viewModel: MedicationViewModel())
}
