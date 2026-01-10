//
//  MedicationDetailView.swift
//  swastricare-mobile-swift
//
//  View for editing existing medications
//

import SwiftUI

struct MedicationDetailView: View {
    @Environment(\.dismiss) var dismiss
    let medication: Medication
    @StateObject private var viewModel: MedicationViewModel
    
    @State private var name: String
    @State private var dosage: String
    @State private var selectedType: MedicationType
    @State private var selectedSchedule: MedicationSchedule
    @State private var scheduledTimes: [Date]
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isOngoing: Bool
    @State private var notes: String
    
    @State private var isEditing = false
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(medication: Medication, viewModel: MedicationViewModel) {
        self.medication = medication
        _viewModel = StateObject(wrappedValue: viewModel)
        
        // Initialize state from medication
        _name = State(initialValue: medication.name)
        _dosage = State(initialValue: medication.dosage)
        _selectedType = State(initialValue: medication.type)
        _selectedSchedule = State(initialValue: medication.scheduleTemplate)
        _scheduledTimes = State(initialValue: medication.scheduledTimes)
        _startDate = State(initialValue: medication.startDate)
        _endDate = State(initialValue: medication.endDate ?? Date())
        _isOngoing = State(initialValue: medication.isOngoing)
        _notes = State(initialValue: medication.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Card
                        medicationHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        
                        // Today's Doses
                        todaysDosesSection
                            .padding(.horizontal, 20)
                        
                        // Edit Form (when editing)
                        if isEditing {
                            editFormSection
                                .padding(.horizontal, 20)
                        } else {
                            detailsSection
                                .padding(.horizontal, 20)
                        }
                        
                        // Adherence History
                        adherenceSection
                            .padding(.horizontal, 20)
                        
                        // Delete Button
                        if isEditing {
                            deleteButton
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(isEditing ? "Edit Medication" : "Medication Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "Cancel" : "Close") {
                        if isEditing {
                            cancelEditing()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(.primary)
                    .font(.body)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(isLoading || !hasChanges)
                        .foregroundColor(hasChanges ? Color(hex: "2E3192") : .secondary)
                        .font(.body)
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                        .foregroundColor(Color(hex: "2E3192"))
                        .font(.body)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Medication", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteMedication()
                }
            } message: {
                Text("Are you sure you want to delete \(medication.name)? This will also cancel all scheduled reminders.")
            }
        }
    }
    
    // MARK: - Medication Header
    
    private var medicationHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "2E3192").opacity(0.12))
                    .frame(width: 64, height: 64)
                
                Image(systemName: medication.type.icon)
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "2E3192"))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(medication.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(medication.dosage)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text(medication.scheduleTemplate.displayName)
                        .font(.system(size: 13))
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .glass(cornerRadius: 18)
    }
    
    // MARK: - Today's Doses Section
    
    private var todaysDosesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Doses")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            let adherence = viewModel.getAdherence(for: medication.id, date: Date())
            
            if adherence.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No doses scheduled for today")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .glass(cornerRadius: 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(adherence) { dose in
                        DoseCard(
                            dose: dose,
                            onMarkTaken: {
                                Task {
                                    try? await viewModel.markAsTaken(medicationId: medication.id, scheduledTime: dose.scheduledTime)
                                }
                            },
                            onMarkSkipped: {
                                Task {
                                    try? await viewModel.markAsSkipped(medicationId: medication.id, scheduledTime: dose.scheduledTime, notes: "Skipped manually")
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 10) {
                DetailRow(label: "Type", value: medication.type.displayName, icon: medication.type.icon)
                DetailRow(label: "Schedule", value: medication.scheduleTemplate.displayName, icon: "calendar")
                
                if medication.isOngoing {
                    DetailRow(label: "Duration", value: "Ongoing", icon: "infinity")
                } else if let endDate = medication.endDate {
                    DetailRow(label: "End Date", value: formatDate(endDate), icon: "calendar.badge.clock")
                }
            }
            
            if let notes = medication.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("Notes")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(notes)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .glass(cornerRadius: 14)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .glass(cornerRadius: 18)
    }
    
    // MARK: - Edit Form Section
    
    private var editFormSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("Medication name", text: $name)
                    .textFieldStyle(PremiumTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Dosage")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("Dosage", text: $dosage)
                    .textFieldStyle(PremiumTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Notes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                TextEditor(text: $notes)
                    .frame(height: 100)
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
            
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .glass(cornerRadius: 18)
    }
    
    // MARK: - Adherence Section
    
    private var adherenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adherence History")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            let adherence = viewModel.getAdherence(for: medication.id, date: Date())
            let stats = AdherenceStatistics(adherenceRecords: adherence)
            
            HStack(spacing: 12) {
                MedicationStatCard(title: "Taken", value: "\(stats.takenDoses)", color: .green)
                MedicationStatCard(title: "Missed", value: "\(stats.missedDoses)", color: .red)
                MedicationStatCard(title: "Skipped", value: "\(stats.skippedDoses)", color: .orange)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .glass(cornerRadius: 18)
        }
    }
    
    // MARK: - Delete Button
    
    private var deleteButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16))
                Text("Delete Medication")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.red.opacity(0.1))
            .cornerRadius(14)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Actions
    
    private var hasChanges: Bool {
        name != medication.name ||
        dosage != medication.dosage ||
        notes != (medication.notes ?? "") ||
        isOngoing != medication.isOngoing
    }
    
    private func cancelEditing() {
        // Reset to original values
        name = medication.name
        dosage = medication.dosage
        notes = medication.notes ?? ""
        isOngoing = medication.isOngoing
        isEditing = false
    }
    
    private func saveChanges() {
        isLoading = true
        
        var updatedMedication = medication
        updatedMedication.name = name
        updatedMedication.dosage = dosage
        updatedMedication.notes = notes.isEmpty ? nil : notes
        updatedMedication.isOngoing = isOngoing
        updatedMedication.endDate = isOngoing ? nil : endDate
        
        Task {
            do {
                try await viewModel.updateMedication(updatedMedication)
                await MainActor.run {
                    isLoading = false
                    isEditing = false
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
    
    private func deleteMedication() {
        isLoading = true
        
        Task {
            do {
                try await viewModel.deleteMedication(id: medication.id)
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
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Dose Card

struct DoseCard: View {
    let dose: MedicationAdherence
    let onMarkTaken: () -> Void
    let onMarkSkipped: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(formatTime(dose.scheduledTime))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Image(systemName: dose.status.icon)
                        .font(.system(size: 12))
                    Text(dose.status.displayName)
                        .font(.system(size: 13))
                }
                .foregroundColor(statusColor(dose.status))
            }
            
            Spacer()
            
            if dose.status == .pending {
                HStack(spacing: 12) {
                    Button(action: onMarkTaken) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: onMarkSkipped) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else if let takenAt = dose.takenAt {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("at \(formatTime(takenAt))")
                        .font(.system(size: 13))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glass(cornerRadius: 14)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func statusColor(_ status: AdherenceStatus) -> Color {
        switch status {
        case .taken: return .green
        case .missed: return .red
        case .skipped: return .orange
        case .pending: return .secondary
        case .late: return .yellow
        case .early: return .blue
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glass(cornerRadius: 14)
    }
}

// MARK: - Medication Stat Card

struct MedicationStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let medication = Medication(
        name: "Aspirin",
        dosage: "500mg",
        type: .pill,
        scheduleTemplate: .twiceDaily,
        scheduledTimes: [Date(), Date()],
        startDate: Date(),
        isOngoing: true
    )
    
    MedicationDetailView(medication: medication, viewModel: MedicationViewModel())
}
