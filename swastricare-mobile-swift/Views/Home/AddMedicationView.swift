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
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    progressBar
                    
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
                        .padding()
                    }
                    
                    // Navigation buttons
                    navigationButtons
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                Rectangle()
                    .fill(step <= currentStep ? PremiumColor.royalBlue : Color.white.opacity(0.2))
                    .frame(height: 4)
                    .animation(.spring(), value: currentStep)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Step 1: Name & Type
    
    private var step1Content: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Step 1: Basic Information")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Medication name
            VStack(alignment: .leading, spacing: 8) {
                Text("Medication Name")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("e.g., Aspirin, Metformin", text: $name)
                    .textFieldStyle(PremiumTextFieldStyle())
                    .autocapitalization(.words)
            }
            
            // Dosage
            VStack(alignment: .leading, spacing: 8) {
                Text("Dosage")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("e.g., 500mg, 1 tablet", text: $dosage)
                    .textFieldStyle(PremiumTextFieldStyle())
            }
            
            // Type selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Type")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(MedicationType.allCases, id: \.self) { type in
                        TypeCard(type: type, isSelected: selectedType == type) {
                            selectedType = type
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Step 2: Schedule
    
    private var step2Content: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Step 2: Schedule")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Choose how often you take this medication")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Schedule templates
            VStack(spacing: 12) {
                ScheduleTemplateCard(
                    template: .onceDaily,
                    isSelected: isScheduleEqual(selectedSchedule, .onceDaily)
                ) {
                    selectedSchedule = .onceDaily
                    customTimes = []
                }
                
                ScheduleTemplateCard(
                    template: .twiceDaily,
                    isSelected: isScheduleEqual(selectedSchedule, .twiceDaily)
                ) {
                    selectedSchedule = .twiceDaily
                    customTimes = []
                }
                
                ScheduleTemplateCard(
                    template: .thriceDaily,
                    isSelected: isScheduleEqual(selectedSchedule, .thriceDaily)
                ) {
                    selectedSchedule = .thriceDaily
                    customTimes = []
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
                .font(.headline)
                .foregroundColor(.secondary)
            
            ForEach(times.indices, id: \.self) { index in
                HStack {
                    Text(timeLabel(for: index))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(formatTime(times[index]))
                        .font(.headline)
                        .foregroundColor(PremiumColor.royalBlue)
                }
                .padding()
                .glass(cornerRadius: 12)
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
            Text("Step 3: Duration")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Start date
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Date")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(PremiumColor.royalBlue)
                    .padding()
                    .glass(cornerRadius: 12)
            }
            
            // Duration type
            VStack(alignment: .leading, spacing: 12) {
                Text("Duration")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Toggle(isOn: $isOngoing) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ongoing medication")
                            .foregroundColor(.white)
                        Text("No end date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(PremiumColor.neonGreen)
                .padding()
                .glass(cornerRadius: 12)
                
                if !isOngoing {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("End Date")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(PremiumColor.royalBlue)
                            .padding()
                            .glass(cornerRadius: 12)
                    }
                }
            }
            
            // Notes (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (Optional)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $notes)
                    .frame(height: 100)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 1 {
                Button(action: previousStep) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                }
            }
            
            Button(action: nextStepOrSave) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(currentStep == 3 ? "Save" : "Next")
                        if currentStep < 3 {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProceed ? PremiumColor.royalBlue : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(12)
                .foregroundColor(.white)
            }
            .disabled(!canProceed || isLoading)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return !name.isEmpty && !dosage.isEmpty
        case 2:
            return true
        case 3:
            return true
        default:
            return false
        }
    }
    
    private func previousStep() {
        withAnimation {
            currentStep -= 1
        }
    }
    
    private func nextStepOrSave() {
        if currentStep < 3 {
            withAnimation {
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
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Text(type.displayName)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isSelected ?
                PremiumColor.royalBlue :
                LinearGradient(colors: [Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Schedule Template Card

struct ScheduleTemplateCard: View {
    let template: MedicationSchedule
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(template.templateDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(PremiumColor.neonGreen)
                        .font(.title3)
                }
            }
            .padding()
            .glass(cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? PremiumColor.royalBlue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Premium Text Field Style

struct PremiumTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .foregroundColor(.white)
    }
}

#Preview {
    AddMedicationView(viewModel: MedicationViewModel())
}
