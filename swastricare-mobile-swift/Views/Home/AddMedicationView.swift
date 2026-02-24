//
//  AddMedicationView.swift
//  swastricare-mobile-swift
//
//  3-step wizard for adding medications with Movements+ Design
//

import SwiftUI

struct AddMedicationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var hasAppeared = false
    
    // MARK: - Theme Colors
    
    private var medicationPurple: Color { Color(hex: "5856D6") }
    private var medicationTeal: Color { Color(hex: "11998e") }
    
    init(viewModel: MedicationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    progressBar
                        .padding(.top, 8)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : -10)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: hasAppeared)
                    
                    ScrollView(showsIndicators: false) {
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
                        .padding(.bottom, 120)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
                    
                    navigationButtons
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            Rectangle()
                                .fill(MovementsColors.card(for: colorScheme))
                                .shadow(color: Color.black.opacity(0.05), radius: 20, y: -10)
                                .ignoresSafeArea(edges: .bottom)
                        )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Medication")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    hasAppeared = true
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
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? medicationPurple : Color.primary.opacity(0.1))
                        .frame(height: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentStep)
                }
            }
            .padding(.horizontal, 20)
            
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(medicationPurple.opacity(0.15))
                            .frame(width: 28, height: 28)
                        
                        Text("\(currentStep)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(medicationPurple)
                    }
                    
                    Text(stepTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Step \(currentStep) of 3")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 1: return "Basic Info"
        case 2: return "Schedule"
        case 3: return "Duration"
        default: return ""
        }
    }
    
    // MARK: - Step 1: Name & Type
    
    private var step1Content: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What medication?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Enter the medication details")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Medication Name")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 18))
                        .foregroundColor(medicationPurple)
                        .frame(width: 24)
                    
                    TextField("e.g., Aspirin, Metformin", text: $name)
                        .font(.system(size: 16))
                        .autocapitalization(.words)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(MovementsColors.card(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(name.isEmpty ? Color.clear : medicationPurple.opacity(0.3), lineWidth: 1)
                )
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Dosage (Optional)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Image(systemName: "number")
                        .font(.system(size: 18))
                        .foregroundColor(medicationPurple)
                        .frame(width: 24)
                    
                    TextField("e.g., 500mg, 1 tablet", text: $dosage)
                        .font(.system(size: 16))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(MovementsColors.card(for: colorScheme))
                )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Type")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(MedicationType.allCases, id: \.self) { type in
                        MedicationTypeCardNew(
                            type: type,
                            isSelected: selectedType == type,
                            colorScheme: colorScheme
                        ) {
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
                Text("How often?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Choose your medication schedule")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                ScheduleTemplateCardNew(
                    template: .onceDaily,
                    isSelected: isScheduleEqual(selectedSchedule, .onceDaily),
                    colorScheme: colorScheme
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSchedule = .onceDaily
                        customTimes = []
                    }
                }
                
                ScheduleTemplateCardNew(
                    template: .twiceDaily,
                    isSelected: isScheduleEqual(selectedSchedule, .twiceDaily),
                    colorScheme: colorScheme
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSchedule = .twiceDaily
                        customTimes = []
                    }
                }
                
                ScheduleTemplateCardNew(
                    template: .thriceDaily,
                    isSelected: isScheduleEqual(selectedSchedule, .thriceDaily),
                    colorScheme: colorScheme
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSchedule = .thriceDaily
                        customTimes = []
                    }
                }
            }
            
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                ForEach(times.indices, id: \.self) { index in
                    HStack {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(medicationPurple.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: timeIcon(for: index))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(medicationPurple)
                            }
                            
                            Text(timeLabel(for: index))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Text(formatTime(times[index]))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(medicationPurple)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(MovementsColors.card(for: colorScheme))
                    )
                }
            }
        }
    }
    
    private func timeIcon(for index: Int) -> String {
        switch index {
        case 0: return "sunrise.fill"
        case 1: return selectedSchedule == .twiceDaily ? "sunset.fill" : "sun.max.fill"
        case 2: return "moon.fill"
        default: return "clock.fill"
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
                Text("How long?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Set the medication duration")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Start Date")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(medicationPurple.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(medicationPurple)
                        }
                        
                        Text("Starting from")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(medicationPurple)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(MovementsColors.card(for: colorScheme))
                )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Duration")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isOngoing.toggle()
                    }
                }) {
                    HStack {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isOngoing ? medicationTeal.opacity(0.15) : Color.primary.opacity(0.08))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: isOngoing ? "infinity" : "calendar.badge.clock")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(isOngoing ? medicationTeal : .secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ongoing medication")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text("No end date")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isOngoing ? medicationTeal : Color.primary.opacity(0.1))
                                .frame(width: 44, height: 26)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 22, height: 22)
                                .offset(x: isOngoing ? 9 : -9)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(MovementsColors.card(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isOngoing ? medicationTeal.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                
                if !isOngoing {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("End Date")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.orange)
                                }
                                
                                Text("Ending on")
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(medicationPurple)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(MovementsColors.card(for: colorScheme))
                        )
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Notes (Optional)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                ZStack(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Add any additional notes...")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                    
                    TextEditor(text: $notes)
                        .font(.system(size: 15))
                        .frame(height: 100)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(MovementsColors.card(for: colorScheme))
                )
            }
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 1 {
                Button(action: previousStep) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.primary.opacity(0.08))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            Button(action: nextStepOrSave) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    } else {
                        Text(currentStep == 3 ? "Save Medication" : "Continue")
                            .font(.system(size: 16, weight: .bold))
                        
                        if currentStep < 3 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(canProceed ? medicationPurple : Color.gray.opacity(0.3))
                )
            }
            .buttonStyle(ScaleButtonStyle())
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
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
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
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

// MARK: - Medication Type Card New

struct MedicationTypeCardNew: View {
    let type: MedicationType
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    private var medicationPurple: Color { Color(hex: "5856D6") }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.2) : medicationPurple.opacity(0.12))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .white : medicationPurple)
                }
                
                Text(type.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? medicationPurple : MovementsColors.card(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Schedule Template Card New

struct ScheduleTemplateCardNew: View {
    let template: MedicationSchedule
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    private var medicationPurple: Color { Color(hex: "5856D6") }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? medicationPurple.opacity(0.15) : Color.primary.opacity(0.08))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: scheduleIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? medicationPurple : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(template.templateDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? medicationPurple : Color.primary.opacity(0.2), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(medicationPurple)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(MovementsColors.card(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? medicationPurple.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var scheduleIcon: String {
        switch template {
        case .onceDaily: return "1.circle.fill"
        case .twiceDaily: return "2.circle.fill"
        case .thriceDaily: return "3.circle.fill"
        case .custom: return "clock.fill"
        }
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
