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
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Card
                        medicationHeader
                        
                        // Today's Doses
                        todaysDosesSection
                        
                        // Edit Form (when editing)
                        if isEditing {
                            editFormSection
                        } else {
                            detailsSection
                        }
                        
                        // Adherence History
                        adherenceSection
                        
                        // Delete Button
                        if isEditing {
                            deleteButton
                        }
                    }
                    .padding()
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
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(isLoading || !hasChanges)
                        .foregroundColor(hasChanges ? Color(hex: "2E3192") : .secondary)
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                        .foregroundColor(Color(hex: "2E3192"))
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
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Medication Header
    
    private var medicationHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 70, height: 70)
                
                Image(systemName: medication.type.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(Color.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(medication.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(medication.dosage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(medication.scheduleTemplate.displayName)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .glass(cornerRadius: 16)
    }
    
    // MARK: - Today's Doses Section
    
    private var todaysDosesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Doses")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            let adherence = viewModel.getAdherence(for: medication.id, date: Date())
            
            if adherence.isEmpty {
                Text("No doses scheduled for today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .glass(cornerRadius: 12)
            } else {
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
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
                .foregroundColor(.white)
            
            DetailRow(label: "Type", value: medication.type.displayName, icon: medication.type.icon)
            DetailRow(label: "Schedule", value: medication.scheduleTemplate.displayName, icon: "calendar")
            
            if medication.isOngoing {
                DetailRow(label: "Duration", value: "Ongoing", icon: "infinity")
            } else if let endDate = medication.endDate {
                DetailRow(label: "End Date", value: formatDate(endDate), icon: "calendar.badge.clock")
            }
            
            if let notes = medication.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.secondary)
                        Text("Notes")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding()
                .glass(cornerRadius: 12)
            }
        }
        .padding()
        .glass(cornerRadius: 16)
    }
    
    // MARK: - Edit Form Section
    
    private var editFormSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Details")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Medication name", text: $name)
                    .textFieldStyle(PremiumTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Dosage")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Dosage", text: $dosage)
                    .textFieldStyle(PremiumTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $notes)
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            
            Toggle(isOn: $isOngoing) {
                Text("Ongoing medication")
                    .foregroundColor(.white)
            }
            .tint(PremiumColor.neonGreen)
        }
        .padding()
        .glass(cornerRadius: 16)
    }
    
    // MARK: - Adherence Section
    
    private var adherenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adherence History")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            let adherence = viewModel.getAdherence(for: medication.id, date: Date())
            let stats = AdherenceStatistics(adherenceRecords: adherence)
            
            HStack(spacing: 20) {
                MedicationStatCard(title: "Taken", value: "\(stats.takenDoses)", color: .green)
                MedicationStatCard(title: "Missed", value: "\(stats.missedDoses)", color: .red)
                MedicationStatCard(title: "Skipped", value: "\(stats.skippedDoses)", color: .orange)
            }
            .padding()
            .glass(cornerRadius: 12)
        }
    }
    
    // MARK: - Delete Button
    
    private var deleteButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            HStack {
                Image(systemName: "trash.fill")
                Text("Delete Medication")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.2))
            .cornerRadius(12)
            .foregroundColor(.red)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTime(dose.scheduledTime))
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Image(systemName: dose.status.icon)
                        .font(.caption)
                    Text(dose.status.displayName)
                        .font(.caption)
                }
                .foregroundColor(statusColor(dose.status))
            }
            
            Spacer()
            
            if dose.status == .pending {
                HStack(spacing: 8) {
                    Button(action: onMarkTaken) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button(action: onMarkSkipped) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            } else if let takenAt = dose.takenAt {
                Text("at \(formatTime(takenAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .glass(cornerRadius: 12)
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
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(label)
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding()
        .glass(cornerRadius: 12)
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
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
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
