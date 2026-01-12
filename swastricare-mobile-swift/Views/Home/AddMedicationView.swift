//
//  AddMedicationView.swift
//  swastricare-mobile-swift
//
//  3-step wizard for adding medications
//

import SwiftUI

struct AddMedicationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: MedicationViewModel
    
    // Form state
    @State private var currentStep = 1
    @State private var name = ""
    @State private var dosage = ""
    @State private var selectedType: MedicationType = .pill
    @State private var selectedSchedule: MedicationSchedule = .onceDaily
    @State private var customTimes: [Date] = []
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isOngoing = true
    @State private var notes = ""
    
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(viewModel: MedicationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                
                VStack(spacing: 0) {
                    // Progress indicator
                    progressBar
                        .padding(.top, 8)
                    
                    // Step content
                    ScrollView {
                        VStack(spacing: 24) {
                            switch currentStep {
                            case 1:
                                step1Content
                            case 2:
                                step2Content
                            case 3:
                                step3Content
                            default:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 100)
                    }
                    
                    // Navigation buttons
                    navigationButtons
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            Color(UIColor.systemBackground)
                                .shadow(color: Color.black.opacity(0.05), radius: 10, y: -5)
                        )
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    .font(.body)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step <= currentStep ? Color(hex: "2E3192") : Color.primary.opacity(0.15))
                        .frame(height: 4)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
            .padding(.horizontal, 20)
            
            HStack {
                Text("Step \(currentStep) of 3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Step 1: Name & Type
    
    private var step1Content: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Step 1: Basic Information")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Enter the medication details")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            // Medication name
            VStack(alignment: .leading, spacing: 10) {
                Text("Medication Name")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                TextField("e.g., Aspirin, Metformin", text: $name)
                    .textFieldStyle(PremiumTextFieldStyle())
                    .autocapitalization(.words)
            }
            
            // Dosage
            VStack(alignment: .leading, spacing: 10) {
                Text("Dosage (Optional)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                TextField("e.g., 500mg, 1 tablet", text: $dosage)
                    .textFieldStyle(PremiumTextFieldStyle())
            }
            
            // Type selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Type")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(MedicationType.allCases, id: \.self) { type in
                        TypeCard(type: type, isSelected: selectedType == type) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedType = type
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Step 2: Schedule
    
    private var step2Content: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Step 2: Schedule")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Choose how often you take this medication")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            // Schedule templates
            VStack(spacing: 12) {
                ScheduleTemplateCard(
                    template: .onceDaily,
                    isSelected: isScheduleEqual(selectedSchedule, .onceDaily)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSchedule = .onceDaily
                        customTimes = []
                    }
                }
                
                ScheduleTemplateCard(
                    template: .twiceDaily,
                    isSelected: isScheduleEqual(selectedSchedule, .twiceDaily)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSchedule = .twiceDaily
                        customTimes = []
                    }
                }
                
                ScheduleTemplateCard(
                    template: .thriceDaily,
                    isSelected: isScheduleEqual(selectedSchedule, .thriceDaily)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSchedule = .thriceDaily
                        customTimes = []
                    }
                }
            }
            
            // Time pickers for selected schedule
            if case .onceDaily = selectedSchedule {
                timePickerSection(times: selectedSchedule.defaultTimes)
            } else if case .twiceDaily = selectedSchedule {
                timePickerSection(times: selectedSchedule.defaultTimes)
            } else if case .thriceDaily = selectedSchedule {
                timePickerSection(times: selectedSchedule.defaultTimes)
            }
        }
    }
    
    private func timePickerSection(times: [Date]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scheduled Times")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            
            ForEach(times.indices, id: \.self) { index in
                HStack {
                    Text(timeLabel(for: index))
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatTime(times[index]))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "2E3192"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .glass(cornerRadius: 14)
            }
        }
    }
    
    private func timeLabel(for index: Int) -> String {
        switch index {
        case 0: return "Morning"
        case 1: return selectedSchedule == .twiceDaily ? "Evening" : "Afternoon"
        case 2: return "Evening"
        default: return "Time \(index + 1)"
        }
    }
    
    // MARK: - Step 3: Duration
    
    private var step3Content: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Step 3: Duration")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Set the medication duration")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            // Start date
            VStack(alignment: .leading, spacing: 10) {
                Text("Start Date")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Color(hex: "2E3192"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .glass(cornerRadius: 14)
            }
            
            // Duration type
            VStack(alignment: .leading, spacing: 12) {
                Text("Duration")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Toggle(isOn: $isOngoing) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ongoing medication")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        Text("No end date")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(Color(hex: "2E3192"))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .glass(cornerRadius: 14)
                
                if !isOngoing {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("End Date")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Color(hex: "2E3192"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .glass(cornerRadius: 14)
                    }
                }
            }
            
            // Notes (optional)
            VStack(alignment: .leading, spacing: 10) {
                Text("Notes (Optional)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                TextEditor(text: $notes)
                    .frame(height: 120)
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 1 {
                Button(action: previousStep) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(14)
                }
            }
            
            Button(action: nextStepOrSave) {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    } else {
                        Text(currentStep == 3 ? "Save" : "Next")
                            .font(.system(size: 16, weight: .semibold))
                        if currentStep < 3 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                }
                .foregroundColor(canProceed ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canProceed ? Color(hex: "2E3192") : Color.gray.opacity(0.2))
                .cornerRadius(14)
            }
            .disabled(!canProceed || isLoading)
        }
    }
    
    // MARK: - Helpers
    
    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return !name.isEmpty
        case 2:
            return true
        case 3:
            return true
        default:
            return false
        }
    }
    
    private func previousStep() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentStep -= 1
        }
    }
    
    private func nextStepOrSave() {
        if currentStep < 3 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentStep += 1
            }
        } else {
            saveMedication()
        }
    }
    
    private func saveMedication() {
        isLoading = true
        
        let scheduledTimes = selectedSchedule.defaultTimes
        
        Task {
            do {
                try await viewModel.addMedication(
                    name: name,
                    dosage: dosage,
                    type: selectedType,
                    scheduleTemplate: selectedSchedule,
                    scheduledTimes: scheduledTimes,
                    startDate: startDate,
                    endDate: isOngoing ? nil : endDate,
                    isOngoing: isOngoing,
                    notes: notes.isEmpty ? nil : notes
                )
                
                await MainActor.run {
                    isLoading = false
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
    
    private func isScheduleEqual(_ lhs: MedicationSchedule, _ rhs: MedicationSchedule) -> Bool {
        switch (lhs, rhs) {
        case (.onceDaily, .onceDaily),
             (.twiceDaily, .twiceDaily),
             (.thriceDaily, .thriceDaily):
            return true
        case (.custom(let times1), .custom(let times2)):
            return times1 == times2
        default:
            return false
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Type Card

struct TypeCard: View {
    let type: MedicationType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? .white : Color(hex: "2E3192"))
                
                Text(type.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                isSelected ?
                Color(hex: "2E3192") :
                Color.primary.opacity(0.05)
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Schedule Template Card

struct ScheduleTemplateCard: View {
    let template: MedicationSchedule
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(template.templateDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "2E3192"))
                        .font(.system(size: 24))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .glass(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: "2E3192") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Premium Text Field Style

struct PremiumTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .foregroundColor(.primary)
    }
}

#Preview {
    AddMedicationView(viewModel: MedicationViewModel())
}
